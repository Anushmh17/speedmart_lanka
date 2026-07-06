import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/theme3/theme3_app_bar.dart';
import '../../../../core/widgets/theme3/theme3_app_button.dart';
import '../../../../core/widgets/theme3/theme3_app_card.dart';
import '../../../../core/widgets/theme3/theme3_app_text_field.dart';
import '../../../../core/widgets/theme3/theme3_status_chip.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/models/user_role.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../features/admin/providers/category_provider.dart';
import '../../../../core/storage/storage_service.dart';

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

    await ref.read(authProvider.notifier).updateProfile(
      fullName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      businessName: user.role == UserRole.vendor ? _businessNameCtrl.text.trim() : null,
      requestedCategories: user.role == UserRole.vendor ? _requestedCategories : null,
    );
    
    if (mounted && !ref.read(authLoadingProvider)) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: user.role == UserRole.vendor
              ? const Text('Category request sent to admin for approval.')
              : const Text('Profile updated successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final user = ref.read(currentUserProvider);
    if (user?.role == UserRole.vendor) {
      final rememberMe = await StorageService.getVendorRememberMe();
      if (rememberMe) {
        // Vendor had Remember Me checked — ask if they want to keep it
        final keep = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Remember Me?'),
            content: const Text(
              'Would you like to skip OTP next time you log in?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        );
        if (keep == null) return;
        await StorageService.saveVendorRememberMe(keep);
      }
      // If rememberMe was false, just log out — no popup
    }
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
      return Scaffold(
        appBar: Theme3AppBar(title: 'Profile'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          final role = ref.read(currentUserProvider)?.role;
          context.go(
            role == UserRole.vendor
                ? RouteNames.vendorHome
                : role == UserRole.admin
                    ? RouteNames.adminDashboard
                    : RouteNames.customerHome,
          );
        }
      },
      child: Scaffold(
        appBar: Theme3AppBar(
          title: 'Profile',
          actions: [
            if (!_isEditing)
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => setState(() => _isEditing = true),
              )
            else
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _initData();
                  setState(() => _isEditing = false);
                },
              ),
          ],
        ),
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(user, isDark, _isEditing),
                  const SizedBox(height: AppSpacing.xl),

                  if (!_isEditing) ..._buildQuickStats(user, isDark),
                  if (!_isEditing) const SizedBox(height: AppSpacing.xl),

                  ..._buildAccountSection(user, isDark, _isEditing),
                  const SizedBox(height: AppSpacing.xl),

                  if (user.role == UserRole.vendor) ..._buildVendorSection(user, isDark, _isEditing),
                  if (user.role == UserRole.vendor) const SizedBox(height: AppSpacing.xl),

                  if (!_isEditing) _buildSupportSection(isDark),
                  if (!_isEditing) const SizedBox(height: AppSpacing.xl),

                  if (!_isEditing) _buildDangerZone(isDark, _handleLogout, isLoading),

                  if (_isEditing) ..._buildSaveButton(isLoading),

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(dynamic user, bool isDark, bool isEditing) {
    return Theme3AppCard(
      type: Theme3CardType.elevated,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 54,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                backgroundImage: user.profileImageUrl != null 
                  ? NetworkImage(user.profileImageUrl!) 
                  : null,
                child: user.profileImageUrl == null
                    ? Text(
                        user.initials,
                        style: AppTextStyles.h1(
                          isDark ? AppColors.primaryDark : AppColors.primary,
                        ),
                      )
                    : null,
              ),
              if (isEditing)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceElevatedDark : AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: isDark ? AppColors.primary : Colors.white,
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            user.fullName,
            style: AppTextStyles.h2(
              isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: AppTextStyles.bodyMedium(
              isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          if (user.selectedCountry != null) ...[  
            const SizedBox(height: 4),
            Text(
              user.selectedCountry == 'LK' ? '🇱🇰 Sri Lanka' : '🌐 International',
              style: AppTextStyles.caption(
                isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (user.role == UserRole.vendor && user.isVerified)
            Theme3StatusChip(
              label: 'Verified Vendor',
              status: Theme3StatusType.completed,
            )
          else if (user.role == UserRole.vendor)
            Theme3StatusChip(
              label: 'Pending Approval',
              status: Theme3StatusType.pending,
            ),
        ],
      ),
    );
  }

  List<Widget> _buildQuickStats(dynamic user, bool isDark) {
    final totalRequests = 0;
    final activeOrders = 0;
    final completedOrders = 0;
    
    return [
      Text(
        'Quick Stats',
        style: AppTextStyles.subtitle(
          isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Expanded(
            child: _buildStatCard('Requests', totalRequests.toString(), Icons.receipt_long_outlined, isDark),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: _buildStatCard('Active', activeOrders.toString(), Icons.shopping_bag_outlined, isDark),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: _buildStatCard('Completed', completedOrders.toString(), Icons.check_circle_outline_rounded, isDark),
          ),
        ],
      ),
    ];
  }

  Widget _buildStatCard(String label, String value, IconData icon, bool isDark) {
    return Theme3AppCard(
      type: Theme3CardType.standard,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 24,
            color: isDark ? AppColors.primaryDark : AppColors.primary,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.h3(
              isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption(
              isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAccountSection(dynamic user, bool isDark, bool isEditing) {
    return [
      Text(
        'Account',
        style: AppTextStyles.subtitle(
          isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      if (isEditing) ..._buildEditablePersonalFields(isDark) else ..._buildAccountMenuItems(user, isDark),
    ];
  }

  List<Widget> _buildAccountMenuItems(dynamic user, bool isDark) {
    final items = [
      ('Personal Information', Icons.person_outline_rounded, () {
        setState(() => _isEditing = true);
      }),
      if (user.role == UserRole.customer) ('Delivery Address', Icons.location_on_outlined, () {
        context.push(RouteNames.customerDeliveryAddress);
      }),
      ('Notifications', Icons.notifications_outlined, () {}),
      ('Payment Methods', Icons.payment_outlined, () {}),
    ];

    return [
      Theme3AppCard(
        type: Theme3CardType.standard,
        padding: EdgeInsets.zero,
        child: Column(
          children: List.generate(
            items.length,
            (index) {
              final (label, icon, onTap) = items[index];
              final isLast = index == items.length - 1;
              return Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              size: 20,
                              color: isDark ? AppColors.primaryDark : AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                label,
                                style: AppTextStyles.bodyMedium(
                                  isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 0,
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      indent: 56,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildEditablePersonalFields(bool isDark) {
    return [
      Theme3AppTextField(
        label: 'Full Name',
        controller: _nameCtrl,
        prefixIcon: Icons.person_outline_rounded,
      ),
      const SizedBox(height: AppSpacing.md),
      Theme3AppTextField(
        label: 'Phone Number',
        controller: _phoneCtrl,
        prefixIcon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
      ),
    ];
  }

  List<Widget> _buildVendorSection(dynamic user, bool isDark, bool isEditing) {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Business Information',
            style: AppTextStyles.subtitle(
              isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          if (user.isVerified)
            Theme3StatusChip(
              label: 'Verified',
              status: Theme3StatusType.completed,
            )
          else
            Theme3StatusChip(
              label: 'Pending',
              status: Theme3StatusType.pending,
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      if (isEditing)
        Theme3AppTextField(
          label: 'Business Name',
          controller: _businessNameCtrl,
          prefixIcon: Icons.storefront_rounded,
        )
      else
        Theme3AppCard(
          type: Theme3CardType.standard,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.storefront_rounded,
                size: 20,
                color: isDark ? AppColors.primaryDark : AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Business Name',
                      style: AppTextStyles.labelSmall(
                        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.businessName ?? 'N/A',
                      style: AppTextStyles.bodyMedium(
                        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: AppSpacing.md),
      _buildApprovedCategories(user, isDark),
      const SizedBox(height: AppSpacing.md),
      if (isEditing) _buildRequestableCategories(isDark),
    ];
  }

  Widget _buildApprovedCategories(dynamic user, bool isDark) {
    return Theme3AppCard(
      type: Theme3CardType.standard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_rounded,
                size: 20,
                color: AppColors.success,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Approved Categories',
                style: AppTextStyles.labelMedium(
                  isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (user.allowedCategories != null && user.allowedCategories!.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: user.allowedCategories!
                  .map<Widget>((cat) => Theme3StatusChip(
                    label: cat.toString(),
                    status: Theme3StatusType.completed,
                  ))
                  .toList(),
            )
          else
            Text(
              'No categories approved yet.',
              style: AppTextStyles.bodySmall(
                isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestableCategories(bool isDark) {
    return Consumer(
      builder: (context, ref, _) {
        final user = ref.watch(currentUserProvider);
        if (user == null) return const SizedBox.shrink();

        final activeCategories = ref.watch(activeCategoriesProvider);
        final approvedKeys = (user.allowedCategories ?? [])
            .map((c) => c.trim().toLowerCase().replaceAll(' ', '_'))
            .toSet();
        
        final requestableCategories = activeCategories
            .where((cat) => cat.isActive)
            .where((cat) => !approvedKeys.contains(cat.normalizedKey))
            .toList();

        return Theme3AppCard(
          type: Theme3CardType.standard,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 20,
                    color: isDark ? AppColors.primaryDark : AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Request Categories',
                    style: AppTextStyles.labelMedium(
                      isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (requestableCategories.isEmpty)
                Text(
                  'All categories are already approved.',
                  style: AppTextStyles.bodySmall(
                    isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: requestableCategories.map<Widget>((cat) {
                    final isSelected = _requestedCategories.contains(cat.normalizedKey);
                    return FilterChip(
                      label: Text(cat.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _requestedCategories.add(cat.normalizedKey);
                          } else {
                            _requestedCategories.remove(cat.normalizedKey);
                          }
                        });
                      },
                      selectedColor: (isDark ? AppColors.primaryDark : AppColors.primary).withValues(alpha: 0.2),
                      checkmarkColor: isDark ? AppColors.primaryDark : AppColors.primary,
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSupportSection(bool isDark) {
    final items = [
      ('Help Center', Icons.help_outline_rounded, () {}),
      ('Contact Support', Icons.support_agent_rounded, () {}),
      ('About App', Icons.info_outlined, () {}),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Support',
          style: AppTextStyles.subtitle(
            isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Theme3AppCard(
          type: Theme3CardType.standard,
          padding: EdgeInsets.zero,
          child: Column(
            children: List.generate(
              items.length,
              (index) {
                final (label, icon, onTap) = items[index];
                final isLast = index == items.length - 1;
                return Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onTap,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                icon,
                                size: 20,
                                color: isDark ? AppColors.primaryDark : AppColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Text(
                                label,
                                style: AppTextStyles.bodyMedium(
                                  isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!isLast)
                      Divider(
                        height: 0,
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        indent: 56,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDangerZone(bool isDark, VoidCallback onLogout, bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Theme3AppButton(
          label: 'Logout',
          type: Theme3ButtonType.danger,
          onPressed: onLogout,
          isLoading: isLoading,
          icon: Icons.logout_rounded,
        ),
      ],
    );
  }

  List<Widget> _buildSaveButton(bool isLoading) {
    return [
      const SizedBox(height: AppSpacing.xl),
      Theme3AppButton(
        label: 'Save Changes',
        onPressed: _handleSave,
        isLoading: isLoading,
      ),
    ];
  }
}
