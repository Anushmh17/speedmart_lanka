import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../shared/models/user_role.dart';
import '../../domain/auth_state.dart';
import '../../providers/auth_provider.dart';
import '../../customer_registration/providers/customer_registration_provider.dart';
import '../../customer_registration/widgets/phone_field_lk.dart';
import '../../customer_registration/models/registration_step.dart';

class AuthWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 55);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height + 35,
      size.width,
      size.height - 55,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.role});
  final UserRole role;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
  with WidgetsBindingObserver {
  static const _hPad = 24.0;
  bool _rememberMe = false;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();

  bool _isSubmittingCustomerOtp = false;

  Color get _roleColor {
    switch (widget.role) {
      case UserRole.customer:
        return const Color(0xFFFF8A00);
      case UserRole.vendor:
        return const Color(0xFF2563EB);
      case UserRole.admin:
        return AppColors.adminColor;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.role == UserRole.customer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(customerRegistrationProvider.notifier).setMode(isLogin: true);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    _handleBack();
    return true;
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Exit App?'),
          content: const Text('Are you sure you want to exit?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Exit'),
            ),
          ],
        ),
      ).then((shouldExit) {
        if (shouldExit == true && mounted) {
          SystemNavigator.pop();
        }
      });
    });
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
    final screenHeight = MediaQuery.sizeOf(context).height;

    if (widget.role == UserRole.customer) {
      debugPrint('[AUTH_UI_V3] customer login active');
    } else {
      debugPrint('[AUTH_UI_V3] vendor login active');
    }

    ref.listen(authProvider, (prev, next) {
      if (next.isAuthenticated && !next.isLoading) {
        final role = next.user!.role;
        switch (role) {
          case UserRole.customer:
            debugPrint('[Auth] Customer login success → Navigating to customer home');
            context.go(RouteNames.customerHome);
          case UserRole.vendor:
            debugPrint('[Auth] Vendor login success → Navigating to vendor home');
            context.go(RouteNames.vendorHome);
          case UserRole.admin:
            debugPrint('[Auth] Admin login success → Navigating to admin dashboard');
            context.go(RouteNames.adminHome);
        }
      }
    });

    if (widget.role == UserRole.customer) {
      ref.listen<CustomerRegistrationState>(customerRegistrationProvider, (prev, next) {
        if (next.step == RegistrationStep.verifyOtp && prev?.step != RegistrationStep.verifyOtp) {
          context.push(RouteNames.customerOtp);
        }
        if (next.data.isLkUser != prev?.data.isLkUser) {
          _phoneCtrl.clear();
          _emailCtrl.clear();
        }
      });
    }

    final curvedHero = ClipPath(
      clipper: AuthWaveClipper(),
      child: Container(
        height: 320,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.role == UserRole.customer
                ? const [Color(0xFFFF8A00), Color(0xFFFFB84D)]
                : (widget.role == UserRole.admin
                    ? const [Color(0xFF6C3483), Color(0xFF4A235A)]
                    : const [Color(0xFF2563EB), Color(0xFF0F4DB8)]),
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Back Button
              Positioned(
                top: 12,
                left: 16,
                child: GestureDetector(
                  onTap: _handleBack,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                ),
              ),
              // Speedmart Logo Pill Centered near top
              Positioned(
                top: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
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
                      width: 110,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              // Circle Container with Icon
              Positioned(
                bottom: 55,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.role == UserRole.customer
                          ? Icons.shopping_bag_rounded
                          : (widget.role == UserRole.admin
                              ? Icons.admin_panel_settings_rounded
                              : Icons.storefront_rounded),
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final centeredTitle = Column(
      children: [
        Text(
          'Welcome back',
          style: AppTextStyles.display2(isDark ? Colors.white : const Color(0xFF1F2937)).copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.role == UserRole.customer
              ? 'Sign in as Customer'
              : (widget.role == UserRole.admin ? 'Sign in as Admin' : 'Sign in as Vendor'),
          style: AppTextStyles.bodyLarge(_roleColor).copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );

    final formFields = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
      child: widget.role == UserRole.customer
          ? _buildCustomerForm(isDark: isDark, authState: authState, custState: custState)
          : _buildVendorForm(isDark: isDark, authState: authState),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFFFFDF8),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: screenHeight),
            child: Column(
              children: [
                curvedHero,
                const SizedBox(height: 22),
                centeredTitle,
                const SizedBox(height: 26),
                formFields,
                const SizedBox(height: 40), // spacer bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Customer Form ──────────────────────────────────────────────────────────
  Widget _buildCustomerForm({
    required bool isDark,
    required AuthState authState,
    required CustomerRegistrationState custState,
  }) {
    final secondaryText = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF6B7280);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (authState.hasError) ...[
          _buildErrorBanner(authState.error!),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            Icon(Icons.phone_android_rounded, color: secondaryText, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                custState.isLkUser
                    ? "Enter your mobile number and we'll send you an OTP"
                    : "Enter your email and we'll send you an OTP",
                style: AppTextStyles.bodySmall(secondaryText).copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (custState.isLkUser)
                SizedBox(
                  height: 52,
                  child: PhoneFieldLk(
                    controller: _phoneCtrl,
                    focusNode: _phoneFocus,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _loginCustomerOtp(),
                    hintText: '70 123 4567',
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    labelText: 'Mobile Number',
                  ),
                )
              else
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
              const SizedBox(height: 20),
              AppButton(
                label: 'Send OTP',
                onPressed: _loginCustomerOtp,
                isLoading: _isSubmittingCustomerOtp || custState.isLoading,
                color: _roleColor,
                height: 54,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 14, color: secondaryText),
              const SizedBox(width: 4),
              Text(
                'Secure and encrypted login',
                style: AppTextStyles.bodySmall(secondaryText).copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _buildBenefitsRow(isDark),
        const SizedBox(height: 24),
        Divider(color: isDark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB)),
        const SizedBox(height: 16),
        _buildSignUpRow(isDark),
      ],
    );
  }

  // ── Vendor / Admin Form ────────────────────────────────────────────────────
  Widget _buildVendorForm({
    required bool isDark,
    required AuthState authState,
  }) {
    final secondaryText = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF6B7280);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (authState.hasError) ...[
          _buildErrorBanner(authState.error!),
          const SizedBox(height: 14),
        ],
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Email Address',
                hint: 'you@example.com',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.email_outlined,
                validator: Validators.email,
                onChanged: (_) {
                  if (authState.hasError) ref.read(authProvider.notifier).clearError();
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
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _rememberMe,
                      activeColor: _roleColor,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) => setState(() => _rememberMe = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Remember me',
                    style: AppTextStyles.bodySmall(secondaryText).copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Forgot Password?',
                      style: AppTextStyles.labelSmall(_roleColor).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Sign In',
                onPressed: _login,
                isLoading: authState.isLoading,
                color: _roleColor,
                height: 54,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildCompactDemoCredentials(isDark),
        const SizedBox(height: 24),
        Divider(color: isDark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB)),
        const SizedBox(height: 16),
        _buildSignUpRow(isDark),
      ],
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────

  Widget _buildErrorBanner(String error) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: AppTextStyles.bodySmall(AppColors.error),
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
        _buildBenefit(Icons.flash_on_rounded, 'Fast & Secure\nOTP Login', isDark),
        _buildBenefit(Icons.lock_open_rounded, 'No Password\nRequired', isDark),
        _buildBenefit(Icons.shield_outlined, 'Your Data is\nProtected', isDark),
      ],
    );
  }

  Widget _buildBenefit(IconData icon, String label, bool isDark) {
    final secondaryText = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF6B7280);

    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _roleColor.withValues(alpha: isDark ? 0.12 : 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: _roleColor,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: AppTextStyles.caption(secondaryText).copyWith(
              fontSize: 10,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactDemoCredentials(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171A21) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: _roleColor),
              const SizedBox(width: 6),
              Text(
                'Demo Credentials',
                style: AppTextStyles.labelSmall(_roleColor).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _demoCredential(),
        ],
      ),
    );
  }

  Widget _buildSignUpRow(bool isDark) {
    final secondaryText = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF6B7280);

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Don't have an account? ",
            style: AppTextStyles.bodyMedium(secondaryText).copyWith(fontSize: 13),
          ),
          GestureDetector(
            onTap: () {
              if (widget.role == UserRole.customer) {
                context.push(RouteNames.customerRegister);
              } else {
                context.push(
                  widget.role == UserRole.vendor
                      ? RouteNames.vendorRegister
                      : RouteNames.vendorRegister,
                );
              }
            },
            child: Text(
              'Sign Up',
              style: AppTextStyles.labelLarge(_roleColor).copyWith(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _demoCredential() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String email;
    switch (widget.role) {
      case UserRole.customer:
        email = 'customer@test.com';
      case UserRole.vendor:
        email = 'vendor@test.com';
      case UserRole.admin:
        email = 'admin@speedmart.lk';
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
    final secondaryText = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF6B7280);
    final primaryText = isDark ? Colors.white : const Color(0xFF1F2937);

    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            '$label:',
            style: AppTextStyles.caption(secondaryText).copyWith(fontSize: 11),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.caption(primaryText).copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}


