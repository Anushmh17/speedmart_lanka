import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../models/registration_step.dart';

/// Animated gradient header for the customer registration screen.
///
/// Shows the Speedmart logo, the current step title (with crossfade), and
/// a step progress indicator (dots).
class RegistrationHeader extends StatelessWidget {
  const RegistrationHeader({
    super.key,
    required this.step,
    this.onBack,
  });

  final RegistrationStep step;

  /// Called when the user taps the back button. Pass null to hide the button.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Back button ────────────────────────────────────────────
          if (onBack != null)
            GestureDetector(
              onTap: onBack,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            )
          else
            const SizedBox(height: 38),

          const SizedBox(height: 20),
          // Logo with dark pill for readability
          _buildLogoPill(),
          const SizedBox(height: 16),

          // ── Title with crossfade transition ────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey(step),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(step),
                  style: AppTextStyles.display2(Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle(step),
                  style: AppTextStyles.bodyMedium(Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Step indicator ─────────────────────────────────────────
          _StepDots(step: step),
        ],
      ),
    );
  }

  Widget _buildLogoPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/logo.png',
        width: 105,
        fit: BoxFit.contain,
      ),
    );
  }

  String _title(RegistrationStep s) {
    switch (s) {
      case RegistrationStep.details:
        return 'Create Account';
      case RegistrationStep.sendingOtp:
        return 'Sending OTP…';
      case RegistrationStep.verifyOtp:
        return 'Verify Identity';
      case RegistrationStep.success:
        return 'Welcome Aboard!';
    }
  }

  String _subtitle(RegistrationStep s) {
    switch (s) {
      case RegistrationStep.details:
        return 'Register as a Speedmart Lanka customer';
      case RegistrationStep.sendingOtp:
        return 'Please wait while we send your verification code';
      case RegistrationStep.verifyOtp:
        return 'Enter the OTP sent to your contact';
      case RegistrationStep.success:
        return 'Your account has been created successfully';
    }
  }
}

// ── Step dots indicator ────────────────────────────────────────────────────

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step});
  final RegistrationStep step;

  int get _currentIndex {
    switch (step) {
      case RegistrationStep.details:
      case RegistrationStep.sendingOtp:
        return 0;
      case RegistrationStep.verifyOtp:
        return 1;
      case RegistrationStep.success:
        return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['Details', 'Verify', 'Done'];
    return Row(
      children: List.generate(3, (i) {
        final isActive = i == _currentIndex;
        final isDone = i < _currentIndex;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isActive ? 28 : 10,
              height: 10,
              decoration: BoxDecoration(
                color: (isActive || isDone)
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 4),
            if (isActive)
              Text(
                labels[i],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            const SizedBox(width: 6),
          ],
        );
      }),
    );
  }
}

