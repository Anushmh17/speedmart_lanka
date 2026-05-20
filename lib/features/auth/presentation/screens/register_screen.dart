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

/// Registration screen for all roles.
/// Shows extra vendor fields (business name, categories) when role == vendor.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, required this.role});
  final UserRole role;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _businessCtrl = TextEditingController();
  final List<String> _selectedCategories = [];

  static const List<String> _allCategories = [
    'Groceries', 'Electronics', 'Vehicle Parts', 'Furniture',
    'Home Appliances', 'Clothing', 'Hardware', 'Stationery', 'Other',
  ];

  Color get _roleColor {
    switch (widget.role) {
      case UserRole.customer: return AppColors.customerColor;
      case UserRole.vendor:   return AppColors.vendorColor;
      case UserRole.admin:    return AppColors.adminColor;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _businessCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.role == UserRole.vendor && _selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
      );
      return;
    }
    await ref.read(authProvider.notifier).register(
          fullName: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          password: _passwordCtrl.text,
          role: widget.role,
          businessName: widget.role == UserRole.vendor
              ? _businessCtrl.text.trim()
              : null,
          categories:
              widget.role == UserRole.vendor ? _selectedCategories : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (prev, next) {
      if (next.isAuthenticated && !next.isLoading) {
        switch (next.user!.role) {
          case UserRole.customer: context.go(RouteNames.customerHome);
          case UserRole.vendor:   context.go(RouteNames.vendorHome);
          case UserRole.admin:    context.go(RouteNames.adminDashboard);
        }
      }
    });

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 36),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_roleColor, _roleColor.withOpacity(0.75)],
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
                    GestureDetector(
                      onTap: () => context.go(
                        RouteNames.login,
                        extra: widget.role,
                      ),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const AppLogo(size: LogoSize.small, light: true),
                    const SizedBox(height: 20),
                    Text('Create Account',
                        style: AppTextStyles.display2(Colors.white)),
                    const SizedBox(height: 4),
                    Text('Register as ${widget.role.label}',
                        style: AppTextStyles.bodyLarge(Colors.white70)),
                  ],
                ),
              ),

              // ── Form ──────────────────────────────────────────────
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
                        _ErrorBanner(message: authState.error!),
                        const SizedBox(height: 20),
                      ],

                      // Vendor pending notice
                      if (widget.role == UserRole.vendor) ...[
                        _InfoBanner(
                          icon: Icons.verified_user_outlined,
                          message:
                              'Vendor accounts require admin approval before you can start selling.',
                          color: AppColors.warning,
                        ),
                        const SizedBox(height: 20),
                      ],

                      AppTextField(
                        label: 'Full Name',
                        hint: 'Enter your full name',
                        controller: _nameCtrl,
                        prefixIcon: Icons.person_outline_rounded,
                        textInputAction: TextInputAction.next,
                        validator: Validators.fullName,
                      ),
                      const SizedBox(height: 16),

                      AppTextField(
                        label: 'Email Address',
                        hint: 'Enter your email',
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        prefixIcon: Icons.email_outlined,
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 16),

                      AppTextField(
                        label: 'Phone Number',
                        hint: '07X XXXXXXX',
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        prefixIcon: Icons.phone_outlined,
                        validator: Validators.phone,
                      ),
                      const SizedBox(height: 16),

                      // Vendor-only fields
                      if (widget.role == UserRole.vendor) ...[
                        AppTextField(
                          label: 'Business / Shop Name',
                          hint: 'Enter your shop name',
                          controller: _businessCtrl,
                          prefixIcon: Icons.storefront_outlined,
                          textInputAction: TextInputAction.next,
                          validator: Validators.businessName,
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'Product Categories',
                          style: AppTextStyles.labelLarge(
                            isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _allCategories.map((cat) {
                            final selected = _selectedCategories.contains(cat);
                            return FilterChip(
                              label: Text(cat),
                              selected: selected,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedCategories.add(cat);
                                  } else {
                                    _selectedCategories.remove(cat);
                                  }
                                });
                              },
                              selectedColor: _roleColor.withOpacity(0.15),
                              checkmarkColor: _roleColor,
                              labelStyle: AppTextStyles.labelMedium(
                                selected
                                    ? _roleColor
                                    : (isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight),
                              ),
                              side: BorderSide(
                                color: selected
                                    ? _roleColor
                                    : (isDark
                                        ? AppColors.borderDark
                                        : AppColors.borderLight),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      AppTextField(
                        label: 'Password',
                        hint: 'Min 8 characters',
                        controller: _passwordCtrl,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        prefixIcon: Icons.lock_outline_rounded,
                        validator: Validators.password,
                      ),
                      const SizedBox(height: 16),

                      AppTextField(
                        label: 'Confirm Password',
                        hint: 'Re-enter your password',
                        controller: _confirmCtrl,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        prefixIcon: Icons.lock_outline_rounded,
                        validator: (v) =>
                            Validators.confirmPassword(v, _passwordCtrl.text),
                        onFieldSubmitted: (_) => _register(),
                      ),
                      const SizedBox(height: 28),

                      AppButton(
                        label: 'Create Account',
                        onPressed: _register,
                        isLoading: authState.isLoading,
                        color: _roleColor,
                        icon: Icons.person_add_rounded,
                      ),
                      const SizedBox(height: 24),

                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: AppTextStyles.bodyMedium(
                                isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.go(
                                RouteNames.login,
                                extra: widget.role,
                              ),
                              child: Text(
                                'Sign In',
                                style: AppTextStyles.labelLarge(_roleColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
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
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: AppTextStyles.bodySmall(AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.message,
    required this.color,
  });
  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: AppTextStyles.bodySmall(color)),
          ),
        ],
      ),
    );
  }
}
