import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../customer_registration/widgets/phone_field_lk.dart';

class CustomerLoginActiveView extends StatelessWidget {
  const CustomerLoginActiveView({
    super.key,
    required this.formKey,
    required this.phoneController,
    required this.phoneFocusNode,
    required this.isLkUser,
    required this.isLoading,
    required this.onBack,
    required this.onChangeCountry,
    required this.onSendOtp,
    required this.onSignUp,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final FocusNode phoneFocusNode;
  final bool isLkUser;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onChangeCountry;
  final VoidCallback onSendOtp;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFFFFDF8),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const heroHeight = 230.0;
            const cardOverlap = 20.0;
            const customerCardHeight = 365.0;
            final screenHeight = constraints.maxHeight;
            final topGap = (screenHeight * 0.055).clamp(32.0, 58.0);
            final blockHeight = heroHeight + customerCardHeight - cardOverlap;
            
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: screenHeight),
                child: Column(
                  children: [
                    SizedBox(height: topGap),
                    SizedBox(
                      height: blockHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildHero(heroHeight, isDark),
                          Positioned(
                            top: heroHeight - cardOverlap,
                            left: 24,
                            right: 24,
                            child: _buildCard(customerCardHeight, isDark),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: topGap.clamp(24.0, 48.0)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero(double heroHeight, bool isDark) {
    return Container(
      width: double.infinity,
      height: heroHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.customerColor,
            AppColors.customerColor.withValues(alpha: 0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
                    size: 17,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLogoPill(),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back!',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 27,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Sign in as Customer',
                              style: TextStyle(
                                fontSize: 14.5,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: 31,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
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

  Widget _buildCard(double cardHeight, bool isDark) {
    return Container(
      constraints: BoxConstraints(minHeight: cardHeight),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171A21) : Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: isDark ? Border.all(color: const Color(0xFF2D3340), width: 1) : null,
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCountryModeRow(isDark),
            const SizedBox(height: 11),
            Text(
              "We'll send OTP to your mobile number",
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 11),
            PhoneFieldLk(
              controller: phoneController,
              focusNode: phoneFocusNode,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSendOtp(),
              hintText: '7x xxx xxxx',
              floatingLabelBehavior: FloatingLabelBehavior.never,
              labelText: null,
            ),
            const SizedBox(height: 15),
            AppButton(
              label: 'Send OTP',
              onPressed: onSendOtp,
              isLoading: isLoading,
              color: AppColors.customerColor,
              icon: Icons.send_rounded,
              height: 46,
            ),
            const SizedBox(height: 19),
            _buildBenefitsRow(isDark),
            const SizedBox(height: 17),
            Divider(
              color: isDark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB),
              height: 1,
            ),
            const SizedBox(height: 13),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                  GestureDetector(
                    onTap: onSignUp,
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.customerColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryModeRow(bool isDark) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: AppColors.customerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.customerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Text(
            isLkUser ? '🇱🇰' : '🌍',
            style: const TextStyle(fontSize: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isLkUser ? 'Sri Lanka Mode' : 'International Mode',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.customerColor,
              ),
            ),
          ),
          TextButton(
            onPressed: onChangeCountry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Change',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.customerColor,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsRow(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildBenefit(Icons.speed_rounded, 'Fast & Secure\nOTP Login', isDark),
        _buildBenefit(Icons.no_encryption_outlined, 'No Password\nRequired', isDark),
        _buildBenefit(Icons.verified_user_outlined, 'Your Data is\nProtected', isDark),
      ],
    );
  }

  Widget _buildBenefit(IconData icon, String label, bool isDark) {
    return Column(
      children: [
        Container(
          width: 33,
          height: 33,
          decoration: BoxDecoration(
            color: isDark 
              ? AppColors.customerColor.withValues(alpha: 0.1)
              : AppColors.customerColor.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 17,
            color: isDark ? AppColors.customerColorDark : AppColors.customerColor,
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

