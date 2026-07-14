import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../customer_registration/providers/customer_registration_provider.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  UserRole _selectedRole = UserRole.customer;
  DateTime? _lastBackPress;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onRoleSelected(UserRole role) {
    setState(() {
      _selectedRole = role;
    });
  }

  void _handleContinue() {
    ref.read(authProvider.notifier).clearError();
    ref.read(customerRegistrationProvider.notifier).reset();
    if (_selectedRole == UserRole.customer) {
      context.push(RouteNames.customerLogin);
    } else if (_selectedRole == UserRole.vendor) {
      context.push(RouteNames.vendorLogin);
    }
  }

  void _handleAdminLogin() {
    ref.read(authProvider.notifier).clearError();
    ref.read(customerRegistrationProvider.notifier).reset();
    context.push(RouteNames.adminLogin);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[AUTH_UI_V3] role selection active');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bg = isDark ? const Color(0xFF0F1115) : const Color(0xFFFFFDF8);
    final cardBg = isDark ? const Color(0xFF171A21) : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryText = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF6B7280);
    final borderCol = isDark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          if (context.mounted) Navigator.of(context).pop();
        } else {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 20),
                                // Logo pill (dark pill centered)
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      width: 120,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Your Smart Marketplace',
                                  style: AppTextStyles.bodyMedium(secondaryText).copyWith(
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 35),
                                // Title
                                Text(
                                  'How would you like\nto use Speedmart?',
                                  style: AppTextStyles.h1(primaryText).copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.25,
                                    fontSize: 27,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Choose your role and let’s get started',
                                  style: AppTextStyles.bodyMedium(secondaryText),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 32),
                                
                                // Customer Card
                                _buildRoleOptionCard(
                                  role: UserRole.customer,
                                  icon: Icons.shopping_bag_outlined,
                                  title: 'Customer',
                                  subtitle: 'Submit shopping requests & get proposals from nearby shops',
                                  isSelected: _selectedRole == UserRole.customer,
                                  activeColor: const Color(0xFFFF8A00),
                                  cardBg: cardBg,
                                  borderCol: borderCol,
                                  primaryText: primaryText,
                                  secondaryText: secondaryText,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 16),
                                
                                // Vendor Card
                                _buildRoleOptionCard(
                                  role: UserRole.vendor,
                                  icon: Icons.storefront_outlined,
                                  title: 'Shop Owner',
                                  subtitle: 'Receive customer requests & submit product proposals',
                                  isSelected: _selectedRole == UserRole.vendor,
                                  activeColor: const Color(0xFF2563EB),
                                  cardBg: cardBg,
                                  borderCol: borderCol,
                                  primaryText: primaryText,
                                  secondaryText: secondaryText,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 32),
                                
                                // Continue Button
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _handleContinue,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _selectedRole == UserRole.customer
                                          ? const Color(0xFFFF8A00)
                                          : const Color(0xFF2563EB),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: Text(
                                      'Continue',
                                      style: AppTextStyles.button(Colors.white).copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Terms and privacy
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text.rich(
                                      TextSpan(
                                        text: 'By continuing, you agree to our ',
                                        children: [
                                          TextSpan(
                                            text: 'Terms of Service',
                                            style: TextStyle(
                                              color: _selectedRole == UserRole.customer
                                                  ? const Color(0xFFFF8A00)
                                                  : const Color(0xFF2563EB),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const TextSpan(text: ' and '),
                                          TextSpan(
                                            text: 'Privacy Policy',
                                            style: TextStyle(
                                              color: _selectedRole == UserRole.customer
                                                  ? const Color(0xFFFF8A00)
                                                  : const Color(0xFF2563EB),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      style: AppTextStyles.caption(secondaryText).copyWith(
                                        fontSize: 11,
                                        height: 1.4,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            // Bottom Section: Admin Test Login
                            Column(
                              children: [
                                const SizedBox(height: 32),
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: borderCol, thickness: 1)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        'or',
                                        style: AppTextStyles.caption(secondaryText).copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: borderCol, thickness: 1)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                GestureDetector(
                                  onTap: _handleAdminLogin,
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0x12FFFFFF) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(30),
                                          border: Border.all(
                                            color: isDark ? const Color(0x25FFFFFF) : const Color(0xFFCBD5E1),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.admin_panel_settings_rounded,
                                              size: 15,
                                              color: primaryText.withValues(alpha: 0.7),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Admin Test Login',
                                              style: AppTextStyles.labelMedium(
                                                primaryText.withValues(alpha: 0.8),
                                              ).copyWith(
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'For development & testing only',
                                        style: AppTextStyles.caption(secondaryText).copyWith(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRoleOptionCard({
    required UserRole role,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color activeColor,
    required Color cardBg,
    required Color borderCol,
    required Color primaryText,
    required Color secondaryText,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => _onRoleSelected(role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : borderCol,
            width: isSelected ? 2.0 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: isDark ? 0.25 : 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.15)
                    : (isDark ? const Color(0xFF242830) : const Color(0xFFF3F4F6)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? activeColor : secondaryText,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.h3(primaryText).copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption(secondaryText).copyWith(
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Arrow button on right
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isSelected ? activeColor : secondaryText.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
