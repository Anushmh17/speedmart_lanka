import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../shared/models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../providers/customer_registration_provider.dart';
import '../../../customer/delivery_address/models/customer_delivery_address.dart';
import '../../../customer/delivery_address/providers/customer_delivery_address_provider.dart';
import '../widgets/registration_header.dart';
import '../models/registration_step.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState
    extends ConsumerState<OtpVerificationScreen>
    with SingleTickerProviderStateMixin {
  static const int _otpLength = 6;
  static const int _resendSeconds = 30;

  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  late AnimationController _successAnimCtrl;
  late Animation<double> _successScale;
  late Animation<double> _successOpacity;

  Timer? _resendTimer;
  int _secondsLeft = _resendSeconds;
  bool _canResend = false;
  String? _verifyError;

  @override
  void initState() {
    super.initState();
    _successAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = CurvedAnimation(
      parent: _successAnimCtrl,
      curve: Curves.elasticOut,
    );
    _successOpacity = CurvedAnimation(
      parent: _successAnimCtrl,
      curve: Curves.easeIn,
    );
    _startResendTimer();
    // Auto-focus first box
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNodes[0].requestFocus(),
    );
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _successAnimCtrl.stop();
    _successAnimCtrl.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _secondsLeft = _resendSeconds;
      _canResend = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          _canResend = true;
          t.cancel();
        }
      });
    });
  }

  String get _enteredCode =>
      _controllers.map((c) => c.text.trim()).join().trim();

  Future<void> _verify() async {
    final code = _enteredCode.trim();
    if (code.length < _otpLength) {
      if (!mounted) return;
      setState(() => _verifyError = 'Please enter all 6 digits.');
      return;
    }
    if (!mounted) return;
    setState(() => _verifyError = null);

    final regNotifier = ref.read(customerRegistrationProvider.notifier);
    final authNotifier = ref.read(authProvider.notifier);

    final ok = await regNotifier.verifyOtp(code);

    if (!mounted) return;
    if (ok) {
      final regState = ref.read(customerRegistrationProvider);
      try {
        if (regState.isLogin) {
          await authNotifier.loginCustomerOtp(
            contact: regState.data.primaryContact,
          );
        } else {
          await authNotifier.register(
            fullName: regState.data.fullName,
            email: regState.data.email,
            phone: regState.data.phone,
            password: '',
            role: UserRole.customer,
            detectedCountry: regState.data.overrideInfo.detectedCountry,
            selectedCountry: regState.data.overrideInfo.selectedCountry,
            countryOverride: regState.data.overrideInfo.isCountryOverride,
            detectionSource: regState.data.overrideInfo.detectionSource,
            riskFlag: regState.data.overrideInfo.riskFlag,
            verifiedPhone: regState.data.overrideInfo.verifiedPhone,
            verifiedEmail: regState.data.overrideInfo.verifiedEmail,
            nic: regState.data.nic,
            deliveryCountry: regState.data.country,
            deliveryProvince: regState.data.province?.name,
            deliveryDistrict: regState.data.district?.name,
            deliveryApproxArea: regState.data.approxArea,
            deliveryPreciseAddress: regState.data.preciseAddress,
            deliveryNote: regState.data.deliveryNote,
          );
          final user = ref.read(currentUserProvider);
          if (user != null) {
            final defaultAddress = CustomerDeliveryAddress.fromUserFields(
              customerId: user.id,
              deliveryProvince: regState.data.province?.name,
              deliveryDistrict: regState.data.district?.name,
              deliveryApproxArea: regState.data.approxArea,
              deliveryPreciseAddress: regState.data.preciseAddress,
              deliveryNote: regState.data.deliveryNote,
            );
            await ref
                .read(customerDeliveryAddressProvider.notifier)
                .saveDefaultAddress(defaultAddress);
          }
        }
        if (!mounted) return;
        await _successAnimCtrl.forward();
        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) context.go(RouteNames.customerHome);
      } catch (e) {
        if (!mounted) return;
        setState(() => _verifyError = e.toString().replaceAll('Exception: ', ''));
      }
    } else {
      if (!mounted) return;
      setState(() => _verifyError =
          ref.read(customerRegistrationProvider).error ??
              'Incorrect code. Please try again.');
      // Clear boxes
      for (final c in _controllers) {
        c.clear();
      }
      if (mounted && _focusNodes[0].canRequestFocus) {
        _focusNodes[0].requestFocus();
      }
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;
    if (!mounted) return;
    setState(() => _verifyError = null);
    await ref.read(customerRegistrationProvider.notifier).sendOtp();
    if (mounted) _startResendTimer();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    debugPrint('[AuthUITrace] OTP screen active file: lib/features/auth/customer_registration/screens/otp_verification_screen.dart');
    final state = ref.watch(customerRegistrationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVerifying = state.isLoading;

    // Navigate away if somehow step is wrong
    ref.listen(customerRegistrationProvider, (prev, next) {
      if (next.step == RegistrationStep.success && mounted) {
        context.go(RouteNames.customerHome);
      }
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFFFFDF8),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            final topGap = (availableHeight * 0.08).clamp(45.0, 80.0);
            
            return Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(height: topGap),
                    ),
                    SliverToBoxAdapter(
                  child: RegistrationHeader(
                    step: RegistrationStep.verifyOtp,
                    onBack: () {
                      ref
                          .read(customerRegistrationProvider.notifier)
                          .backToDetails();
                      context.pop();
                    },
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red, width: 3),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                      if (state.maskedContact != null)
                        _ContactHint(
                          contact: state.maskedContact!,
                          isLk: state.isLkUser,
                          isDark: isDark,
                        ),
                      const SizedBox(height: 28),

                      _OtpBoxRow(
                        controllers: _controllers,
                        focusNodes: _focusNodes,
                        hasError: _verifyError != null,
                        onCompleted: _verify,
                      ),
                      const SizedBox(height: 12),

                      // ── Error message ───────────────────────────────
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _verifyError != null
                            ? Padding(
                                key: const ValueKey('err'),
                                padding:
                                    const EdgeInsets.only(top: 4, bottom: 8),
                                child: Text(
                                  _verifyError!,
                                  style: AppTextStyles.bodySmall(
                                      AppColors.error),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : const SizedBox(key: ValueKey('no-err')),
                      ),

                      const SizedBox(height: 24),

                      AppButton(
                        label: 'Verify & Create Account',
                        onPressed: _verify,
                        isLoading: isVerifying,
                        color: AppColors.primary,
                        icon: Icons.verified_user_rounded,
                        height: 48,
                      ),
                      const SizedBox(height: 18),

                      _ResendRow(
                        secondsLeft: _secondsLeft,
                        canResend: _canResend,
                        onResend: _resendOtp,
                        isDark: isDark,
                      ),
                          ],
                        ),
                      ),

                      SizedBox(height: topGap * 0.5),
                    ]),
                  ),
                ),
              ],
            ),

            FadeTransition(
              opacity: _successOpacity,
              child: ScaleTransition(
                scale: _successScale,
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 48),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.successContainer,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: AppColors.success, size: 40),
                        ),
                        const SizedBox(height: 16),
                        Text('Account Created!',
                            style: AppTextStyles.display2(isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight)),
                        const SizedBox(height: 8),
                        Text('Welcome to Speedmart Lanka',
                            style: AppTextStyles.bodyMedium(isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'OTP NEW FILE ACTIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
          },
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _OtpBoxRow extends StatelessWidget {
  const _OtpBoxRow({
    required this.controllers,
    required this.focusNodes,
    required this.hasError,
    required this.onCompleted,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool hasError;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(controllers.length, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: _OtpBox(
            controller: controllers[i],
            focusNode: focusNodes[i],
            hasError: hasError,
            isDark: isDark,
            onChanged: (v) {
              if (v.isNotEmpty && i < controllers.length - 1) {
                focusNodes[i + 1].requestFocus();
              }
              if (v.isEmpty && i > 0) {
                focusNodes[i - 1].requestFocus();
              }
              final allFilled = controllers.every((c) => c.text.isNotEmpty);
              if (allFilled) onCompleted();
            },
          ),
        );
      }),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.isDark,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final bool isDark;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? AppColors.error
        : (isDark ? AppColors.borderDark : AppColors.borderLight);
    final fillColor = hasError
        ? AppColors.errorContainer
        : (isDark ? AppColors.cardDark : AppColors.surfaceLight);

    return SizedBox(
      width: 46,
      height: 56,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: hasError
              ? AppColors.error
              : (isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight),
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: fillColor,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error, width: 2),
          ),
        ),
      ),
    );
  }
}

class _ContactHint extends StatelessWidget {
  const _ContactHint({
    required this.contact,
    required this.isLk,
    required this.isDark,
  });

  final String contact;
  final bool isLk;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          isLk ? Icons.sms_rounded : Icons.email_rounded,
          size: 48,
          color: AppColors.primary,
        ),
        const SizedBox(height: 12),
        Text(
          isLk ? 'We sent an OTP via SMS to' : 'We sent an OTP to your email',
          style: AppTextStyles.bodyMedium(isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          contact,
          style: AppTextStyles.labelLarge(isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.secondsLeft,
    required this.canResend,
    required this.onResend,
    required this.isDark,
  });

  final int secondsLeft;
  final bool canResend;
  final VoidCallback onResend;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Didn't receive the code? ",
          style: AppTextStyles.bodyMedium(
            isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        GestureDetector(
          onTap: canResend ? onResend : null,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: AppTextStyles.labelMedium(
              canResend ? AppColors.primary : AppColors.textSecondaryLight,
            ),
            child: Text(
              canResend ? 'Resend OTP' : 'Resend in ${secondsLeft}s',
            ),
          ),
        ),
      ],
    );
  }
}


