import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../shared/models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../customer_registration/providers/customer_registration_provider.dart';
import '../../customer_registration/widgets/country_mismatch_dialog.dart';
import '../../customer_registration/widgets/phone_field_lk.dart';
import '../../customer_registration/models/registration_step.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.role});
  final UserRole role;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();

  bool _isSubmittingCustomerOtp = false;

  Color get _roleColor {
    switch (widget.role) {
      case UserRole.customer: return AppColors.customerColor;
      case UserRole.vendor:   return AppColors.vendorColor;
      case UserRole.admin:    return AppColors.adminColor;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.role == UserRole.customer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(customerRegistrationProvider.notifier).setMode(isLogin: true);
        ref.read(customerRegistrationProvider.notifier).detectCountry();
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _showCountrySelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Force selection
      builder: (ctx) => AlertDialog(
        title: const Text('Select your country'),
        content: const Text('We could not confidently determine your country. Please select it manually.'),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(customerRegistrationProvider.notifier).setLkUser(true);
              Navigator.of(ctx).pop();
            },
            child: const Text('Sri Lanka 🇱🇰'),
          ),
          TextButton(
            onPressed: () {
              ref.read(customerRegistrationProvider.notifier).setLkUser(false);
              Navigator.of(ctx).pop();
            },
            child: const Text('Other Country 🌍'),
          ),
        ],
      ),
    );
  }

  void _showCountryOverrideDialog() {
    final notifier = ref.read(customerRegistrationProvider.notifier);
    CountryMismatchDialog.show(
      context,
      onContinueInternational: notifier.confirmCountryOverride,
      onUseSriLankaOtp: notifier.cancelCountryOverride,
    );
  }

  Future<void> _loginCustomerOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(customerRegistrationProvider.notifier);
    final authNotifier = ref.read(authProvider.notifier);

    final isLk = ref.read(customerRegistrationProvider).isLkUser;
    final contact = isLk ? _phoneCtrl.text.trim() : _emailCtrl.text.trim();

    setState(() => _isSubmittingCustomerOtp = true);

    try {
      final exists = await authNotifier.checkCustomerExists(contact);
      if (!exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No account found for $contact. Please register.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isSubmittingCustomerOtp = false);
        return;
      }

      if (isLk) {
        notifier.updatePhone(contact);
      } else {
        notifier.updateEmail(contact);
      }

      await notifier.sendOtp();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingCustomerOtp = false);
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).login(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          role: widget.role,
        );
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final custState = ref.watch(customerRegistrationProvider);

    // Navigate on successful login
    ref.listen(authProvider, (prev, next) {
      if (next.isAuthenticated && !next.isLoading) {
        switch (next.user!.role) {
          case UserRole.customer: context.go(RouteNames.customerHome);
          case UserRole.vendor:   context.go(RouteNames.vendorHome);
          case UserRole.admin:    context.go(RouteNames.adminDashboard);
        }
      }
    });

    if (widget.role == UserRole.customer) {
      ref.listen<CustomerRegistrationState>(customerRegistrationProvider, (prev, next) {
        if (next.step == RegistrationStep.verifyOtp && prev?.step != RegistrationStep.verifyOtp) {
          context.push(RouteNames.customerOtp);
        }
        if (next.shouldShowCountryDialog && !(prev?.shouldShowCountryDialog ?? false)) {
          _showCountrySelectionDialog();
        }
        if (next.pendingOverrideConfirmation && !(prev?.pendingOverrideConfirmation ?? false)) {
          _showCountryOverrideDialog();
        }
        if (next.data.isLkUser != prev?.data.isLkUser) {
          _phoneCtrl.clear();
          _emailCtrl.clear();
        }
      });
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 36),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _roleColor,
                      _roleColor.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => context.go(RouteNames.roleSelection),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const AppLogo(size: LogoSize.small, light: true),
                    const SizedBox(height: 20),
                    Text(
                      'Welcome back!',
                      style: AppTextStyles.display2(Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in as ${widget.role.label}',
                      style: AppTextStyles.bodyLarge(Colors.white70),
                    ),
                  ],
                ),
              ),

              // ── Form ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // Error banner
                      if (authState.hasError) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: AppColors.error, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  authState.error!,
                                  style: AppTextStyles.bodySmall(AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      if (widget.role == UserRole.customer) ...[
                        if (custState.isDetectingCountry) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.infoContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.info,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Detecting your region…',
                                  style: AppTextStyles.bodySmall(AppColors.info),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (custState.countryDetected) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: _roleColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _roleColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  custState.isLkUser ? Icons.phone_android_rounded : Icons.email_outlined,
                                  size: 16,
                                  color: _roleColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    custState.isLkUser ? '🇱🇰 Sri Lanka Mode' : '🌍 International Mode',
                                    style: AppTextStyles.bodySmall(_roleColor)
                                        .copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    ref.read(customerRegistrationProvider.notifier).toggleCountry();
                                    _phoneCtrl.clear();
                                    _emailCtrl.clear();
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Change',
                                    style: AppTextStyles.labelSmall(_roleColor)
                                        .copyWith(decoration: TextDecoration.underline),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        if (custState.isLkUser) ...[
                          PhoneFieldLk(
                            controller: _phoneCtrl,
                            focusNode: _phoneFocus,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _loginCustomerOtp(),
                          ),
                        ] else ...[
                          AppTextField(
                            label: 'Email Address',
                            hint: 'Enter your email',
                            controller: _emailCtrl,
                            focusNode: _emailFocus,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            prefixIcon: Icons.email_outlined,
                            validator: Validators.email,
                            onFieldSubmitted: (_) => _loginCustomerOtp(),
                          ),
                        ],
                        const SizedBox(height: 24),

                        AppButton(
                          label: 'Send OTP',
                          onPressed: _loginCustomerOtp,
                          isLoading: _isSubmittingCustomerOtp || custState.isLoading,
                          color: _roleColor,
                          icon: Icons.send_rounded,
                        ),
                      ] else ...[
                        AppTextField(
                          label: 'Email Address',
                          hint: 'Enter your email',
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          prefixIcon: Icons.email_outlined,
                          validator: Validators.email,
                          onChanged: (_) {
                            if (authState.hasError) {
                              ref.read(authProvider.notifier).clearError();
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        AppTextField(
                          label: 'Password',
                          hint: 'Enter your password',
                          controller: _passwordCtrl,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          prefixIcon: Icons.lock_outline_rounded,
                          validator: Validators.password,
                          onFieldSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 10),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            child: Text(
                              'Forgot Password?',
                              style: AppTextStyles.labelMedium(_roleColor),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Login button
                        AppButton(
                          label: 'Sign In',
                          onPressed: _login,
                          isLoading: authState.isLoading,
                          color: _roleColor,
                          icon: Icons.login_rounded,
                        ),
                        const SizedBox(height: 24),

                        // Mock credentials hint
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.cardDark
                                : AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      size: 14, color: _roleColor),
                                  const SizedBox(width: 6),
                                  Text('Demo Credentials',
                                      style: AppTextStyles.labelSmall(_roleColor)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _demoCredential(),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),

                      // Register link
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: AppTextStyles.bodyMedium(
                                isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                if (widget.role == UserRole.customer) {
                                  // Customer gets the dedicated registration flow
                                  context.go(RouteNames.customerRegister);
                                } else {
                                  // Vendor / Admin use the generic register screen
                                  context.go(
                                    widget.role == UserRole.vendor
                                        ? RouteNames.vendorRegister
                                        : RouteNames.adminRegister,
                                  );
                                }
                              },
                              child: Text(
                                'Sign Up',
                                style: AppTextStyles.labelLarge(_roleColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _demoCredential() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String email;
    switch (widget.role) {
      case UserRole.customer: email = 'customer@test.com';
      case UserRole.vendor:   email = 'vendor@test.com';
      case UserRole.admin:    email = 'admin@speedmart.lk';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _credRow('Email', email, isDark),
        const SizedBox(height: 4),
        _credRow('Password', 'any password', isDark),
      ],
    );
  }

  Widget _credRow(String label, String value, bool isDark) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            '$label:',
            style: AppTextStyles.caption(
              isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.caption(
            isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

