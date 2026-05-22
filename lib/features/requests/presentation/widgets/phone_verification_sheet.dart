import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import 'package:speedmart_lanka/features/auth/customer_registration/services/otp_service.dart';
import 'package:speedmart_lanka/features/auth/customer_registration/widgets/phone_field_lk.dart';
import 'package:speedmart_lanka/features/auth/providers/auth_provider.dart';

/// Bottom sheet that collects & verifies a Sri Lankan phone number via OTP.
///
/// After successful verification it calls [onVerified] with the normalised
/// phone number so the caller can proceed (e.g. submit a shopping request).
///
/// Uses the existing [MockOtpService] with code `123456` during development.
class PhoneVerificationSheet extends ConsumerStatefulWidget {
  const PhoneVerificationSheet({
    super.key,
    required this.onVerified,
  });

  /// Called with the verified, normalised phone number on success.
  final ValueChanged<String> onVerified;

  @override
  ConsumerState<PhoneVerificationSheet> createState() =>
      _PhoneVerificationSheetState();
}

class _PhoneVerificationSheetState
    extends ConsumerState<PhoneVerificationSheet> {
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  final _otp = MockOtpService(mockValidCode: '123456');

  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _otpSent = false;
  String? _maskedContact;
  String? _error;

  // Resend cooldown
  int _resendCooldown = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendCooldown = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final normalised = PhoneFieldLk.normalise(_phoneCtrl.text.trim());
    if (normalised == null) {
      setState(() => _error = 'Invalid phone number');
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _error = null;
    });

    try {
      final result = await _otp.sendOtp(
        channel: OtpChannel.phone,
        destination: normalised,
      );

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _otpSent = true;
          _maskedContact = result.maskedContact;
          _isSendingOtp = false;
        });
        _startResendCooldown();
        // Focus the first OTP box
        _otpFocusNodes[0].requestFocus();
      } else {
        setState(() {
          _error = result.message ?? 'Failed to send OTP';
          _isSendingOtp = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not send OTP. Please try again.';
          _isSendingOtp = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length < 6) {
      setState(() => _error = 'Please enter all 6 digits');
      return;
    }

    final normalised = PhoneFieldLk.normalise(_phoneCtrl.text.trim());
    if (normalised == null) return;

    setState(() {
      _isVerifyingOtp = true;
      _error = null;
    });

    try {
      final ok = await _otp.verifyOtp(
        channel: OtpChannel.phone,
        destination: normalised,
        code: code,
      );

      if (!mounted) return;

      if (ok) {
        // Update the user model with verifiedPhone = true
        await ref.read(authProvider.notifier).markPhoneVerified(
              phone: normalised,
            );
        if (mounted) {
          widget.onVerified(normalised);
          Navigator.of(context).pop();
        }
      } else {
        setState(() {
          _error = 'Incorrect OTP code. Please try again.';
          _isVerifyingOtp = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Verification failed. Please try again.';
          _isVerifyingOtp = false;
        });
      }
    }
  }

  void _resendOtp() {
    if (_resendCooldown > 0) return;
    // Clear existing OTP fields
    for (final c in _otpControllers) {
      c.clear();
    }
    _sendOtp();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: secondaryText.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Shield icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.customerColor,
                      AppColors.customerColor.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                _otpSent
                    ? 'Verify your phone'
                    : 'Phone verification required',
                style: AppTextStyles.h3(primaryText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                _otpSent
                    ? 'Enter the 6-digit code sent to $_maskedContact'
                    : 'To submit shopping requests for delivery in Sri Lanka, please verify a mobile phone number.',
                style: AppTextStyles.bodyMedium(secondaryText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Error banner
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppTextStyles.bodySmall(AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (!_otpSent) ...[
                // Phone input
                Form(
                  key: _formKey,
                  child: PhoneFieldLk(
                    controller: _phoneCtrl,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _sendOtp(),
                  ),
                ),
                const SizedBox(height: 20),

                // Send OTP button
                AppButton(
                  label: 'Send OTP',
                  onPressed: _sendOtp,
                  isLoading: _isSendingOtp,
                  color: AppColors.customerColor,
                  icon: Icons.send_rounded,
                ),
              ] else ...[
                // OTP input boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    return Container(
                      width: 44,
                      height: 52,
                      margin: EdgeInsets.only(
                        right: i < 5 ? 8 : 0,
                        left: i == 3 ? 8 : 0, // extra gap after 3rd digit
                      ),
                      child: TextFormField(
                        controller: _otpControllers[i],
                        focusNode: _otpFocusNodes[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: AppTextStyles.h3(primaryText),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.customerColor,
                              width: 2,
                            ),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (val) {
                          if (val.isNotEmpty && i < 5) {
                            _otpFocusNodes[i + 1].requestFocus();
                          } else if (val.isEmpty && i > 0) {
                            _otpFocusNodes[i - 1].requestFocus();
                          }
                          // Auto-verify when all 6 filled
                          if (i == 5 && val.isNotEmpty) {
                            final code =
                                _otpControllers.map((c) => c.text).join();
                            if (code.length == 6) {
                              _verifyOtp();
                            }
                          }
                        },
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Verify button
                AppButton(
                  label: 'Verify Phone',
                  onPressed: _verifyOtp,
                  isLoading: _isVerifyingOtp,
                  color: AppColors.customerColor,
                  icon: Icons.check_circle_rounded,
                ),
                const SizedBox(height: 12),

                // Resend
                Center(
                  child: _resendCooldown > 0
                      ? Text(
                          'Resend OTP in ${_resendCooldown}s',
                          style: AppTextStyles.bodySmall(secondaryText),
                        )
                      : TextButton(
                          onPressed: _resendOtp,
                          child: Text(
                            'Resend OTP',
                            style: AppTextStyles.labelMedium(
                                AppColors.customerColor),
                          ),
                        ),
                ),
              ],

              const SizedBox(height: 8),

              // Dev hint
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.developer_mode_rounded,
                        size: 12, color: Colors.purple[400]),
                    const SizedBox(width: 6),
                    Text(
                      'Dev OTP: 123456',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.purple[400],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
