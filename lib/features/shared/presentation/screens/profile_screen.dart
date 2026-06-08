import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_state_widgets.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/models/user_role.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../features/admin/providers/category_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _businessNameCtrl;
  
  List<String> _requestedCategories = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _businessNameCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initData();
  }

  void _initData() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _nameCtrl.text = user.fullName;
      _phoneCtrl.text = user.phone;
      _businessNameCtrl.text = user.businessName ?? '';
      _requestedCategories = List.from(user.requestedCategories ?? []);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _businessNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    debugPrint('[ProfileCategoryFix] Profile save requestedCategories: $_requestedCategories');
    
    await ref.read(authProvider.notifier).updateProfile(
      fullName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      businessName: user.role == UserRole.vendor ? _businessNameCtrl.text.trim() : null,
      requestedCategories: user.role == UserRole.vendor ? _requestedCategories : null,
    );
    
    if (mounted && !ref.read(authLoadingProvider)) {
      setState(() => _isEditing = false);
      debugPrint('[ProfileCategoryFix] Profile save complete');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: user.role == UserRole.vendor
              ? const Text('Category request sent to admin for approval.')
              : const Text('Profile updated successfully!'),
          backgroundColor: user.role == UserRole.vendor ? AppColors.vendorColor : AppColors.customerColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      context.go(RouteNames.roleSelection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final isLoading = ref.watch(authLoadingProvider);
    
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final primaryColor = user.role == UserRole.vendor ? AppColors.vendorColor : AppColors.customerColor;
    final primaryColorDark = user.role == UserRole.vendor ? AppColors.vendorColorDark : AppColors.customerColorDark;
    
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Profile Settings', style: AppTextStyles.h2(primaryText)),
                  TextButton.icon(
                    onPressed: () {
                      if (_isEditing) {
                        _initData();
                        setState(() => _isEditing = false);
                      } else {
                        setState(() => _isEditing = true);
                      }
                    },
                    icon: Icon(
                      _isEditing ? Icons.close_rounded : Icons.edit_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                    label: Text(
                      _isEditing ? 'Cancel' : 'Edit',
                      style: AppTextStyles.button(primaryColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor.withOpacity(isDark ? 0.2 : 0.8), primaryColorDark.withOpacity(isDark ? 0.3 : 1.0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 45,
                            backgroundColor: primaryColor.withOpacity(0.1),
                            backgroundImage: user.profileImageUrl != null 
                              ? NetworkImage(user.profileImageUrl!) 
                              : null,
                            child: user.profileImageUrl == null
                                ? Text(user.initials, style: AppTextStyles.h1(primaryColor))
                                : null,
                          ),
                        ),
                        if (_isEditing)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                            ),
                            child: Icon(Icons.camera_alt_rounded, color: primaryColor, size: 20),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.role.label,
                      style: AppTextStyles.labelSmall(isDark ? Colors.white70 : Colors.white70).copyWith(
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.fullName,
                      style: AppTextStyles.h2(Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: AppTextStyles.bodyMedium(Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Text('Personal Information', style: AppTextStyles.subtitle(primaryText)),
              const SizedBox(height: 16),

              _buildFieldCard(
                cardColor: cardColor,
                borderColor: borderColor,
                label: 'Full Name',
                icon: Icons.person_outline_rounded,
                isEditing: _isEditing,
                controller: _nameCtrl,
                primaryText: primaryText,
                secondaryText: secondaryText,
                primaryColor: primaryColor,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              
              _buildFieldCard(
                cardColor: cardColor,
                borderColor: borderColor,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                isEditing: _isEditing,
                controller: _phoneCtrl,
                primaryText: primaryText,
                secondaryText: secondaryText,
                primaryColor: primaryColor,
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),

              if (user.role == UserRole.vendor) ...[
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Business Information', style: AppTextStyles.subtitle(primaryText)),
                    if (user.isVerified)
                      StatusBadge(label: 'Verified', color: AppColors.success)
                    else
                      StatusBadge(label: 'Pending Approval', color: AppColors.warning),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFieldCard(
                  cardColor: cardColor,
                  borderColor: borderColor,
                  label: 'Business Name',
                  icon: Icons.storefront_rounded,
                  isEditing: _isEditing,
                  controller: _businessNameCtrl,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                  primaryColor: primaryColor,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
                          const SizedBox(width: 12),
                          Text('Approved Categories', style: AppTextStyles.labelLarge(secondaryText)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (user.allowedCategories != null && user.allowedCategories!.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (user.allowedCategories!)
                              .map((category) => Chip(
                                label: Text(category),
                                backgroundColor: AppColors.success.withValues(alpha: 0.12),
                                labelStyle: AppTextStyles.bodySmall(AppColors.success)
                                    .copyWith(fontWeight: FontWeight.w600),
                              ))
                              .toList(),
                        )
                      else
                        Text(
                          'No categories approved yet.',
                          style: AppTextStyles.bodySmall(secondaryText),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                if (_isEditing)
                  Consumer(
                    builder: (context, ref, _) {
                      final activeCategories = ref.watch(activeCategoriesProvider);
                      debugPrint('[ProfileCategoryFix] ACTUAL SCREEN FILE: lib/features/shared/presentation/screens/profile_screen.dart');
                      debugPrint('[ProfileCategoryFix] active category count: ${activeCategories.length}');
                      debugPrint('[ProfileCategoryFix] active category names: ${activeCategories.map((c) => c.displayName).toList()}');
                      
                      final approvedKeys = (user.allowedCategories ?? [])
                          .map((c) => c.trim().toLowerCase().replaceAll(' ', '_'))
                          .toSet();
                      debugPrint('[ProfileCategoryFix] approved keys: $approvedKeys');
                      
                      final requestableCategories = activeCategories
                          .where((cat) => cat.isActive)
                          .where((cat) => !approvedKeys.contains(cat.normalizedKey))
                          .toList();
                      debugPrint('[ProfileCategoryFix] requestable names: ${requestableCategories.map((c) => c.displayName).toList()}');
                      debugPrint('[ProfileCategoryFix] chip rendered: ${requestableCategories.length}');
                      
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.category_outlined, color: primaryColor, size: 20),
                                const SizedBox(width: 12),
                                Text('Request Categories', style: AppTextStyles.labelLarge(secondaryText)),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (requestableCategories.isEmpty)
                              Text(
                                'All categories are already approved.',
                                style: AppTextStyles.bodySmall(secondaryText),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: requestableCategories.map((cat) {
                                  final isSelected = _requestedCategories.contains(cat.normalizedKey);
                                  return FilterChip(
                                    label: Text(cat.displayName),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _requestedCategories.add(cat.normalizedKey);
                                          debugPrint('[ProfileCategoryFix] CHIP SELECTED: ${cat.displayName}(${cat.normalizedKey}), requested now: $_requestedCategories');
                                        } else {
                                          _requestedCategories.remove(cat.normalizedKey);
                                          debugPrint('[ProfileCategoryFix] CHIP DESELECTED: ${cat.displayName}(${cat.normalizedKey}), requested now: $_requestedCategories');
                                        }
                                      });
                                    },
                                    selectedColor: primaryColor.withOpacity(0.2),
                                    checkmarkColor: primaryColor,
                                    labelStyle: AppTextStyles.bodySmall(
                                      isSelected ? primaryColor : secondaryText,
                                    ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
                                    backgroundColor: isDark ? Colors.black12 : Colors.grey.shade100,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color: isSelected ? primaryColor : Colors.transparent,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  if (user.hasPendingCategoryRequest == true && user.requestedCategories != null && user.requestedCategories!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.pending_actions, color: Colors.orange, size: 20),
                              const SizedBox(width: 12),
                              Text('Pending Request', style: AppTextStyles.labelLarge(Colors.orange)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (user.requestedCategories ?? [])
                                .map((normalizedKey) => Chip(
                                  label: Text(normalizedKey),
                                  backgroundColor: Colors.orange.withOpacity(0.15),
                                  labelStyle: AppTextStyles.bodySmall(Colors.orange)
                                      .copyWith(fontWeight: FontWeight.w600),
                                ))
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Waiting for admin approval',
                            style: AppTextStyles.caption(Colors.orange),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        'No pending category request',
                        style: AppTextStyles.bodySmall(secondaryText),
                      ),
                    ),
              ],

              const SizedBox(height: 32),
              
              if (_isEditing)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: primaryColor.withOpacity(0.5),
                    ),
                    child: isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Save Changes', style: AppTextStyles.button(Colors.white).copyWith(fontSize: 16)),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _handleLogout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: Text('Logout from Account', style: AppTextStyles.button(AppColors.error).copyWith(fontSize: 16)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldCard({
    required Color cardColor,
    required Color borderColor,
    required String label,
    required IconData icon,
    required bool isEditing,
    required TextEditingController controller,
    required Color primaryText,
    required Color secondaryText,
    required Color primaryColor,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: EdgeInsets.all(isEditing ? 8 : 16),
      decoration: BoxDecoration(
        color: isEditing ? Colors.transparent : cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isEditing ? Colors.transparent : borderColor),
      ),
      child: isEditing
        ? TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: AppTextStyles.bodyLarge(primaryText),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: AppTextStyles.bodyMedium(secondaryText),
              prefixIcon: Icon(icon, color: primaryColor),
              filled: true,
              fillColor: cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
          )
        : Row(
            children: [
              Icon(icon, color: secondaryText, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.labelSmall(secondaryText)),
                    const SizedBox(height: 2),
                    Text(controller.text, style: AppTextStyles.bodyLarge(primaryText)),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}
