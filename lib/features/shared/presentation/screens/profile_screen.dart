import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/theme3/theme3_app_bar.dart';
import '../../../../core/widgets/theme3/theme3_app_button.dart';
import '../../../../core/widgets/theme3/theme3_app_card.dart';
import '../../../../core/widgets/theme3/theme3_app_text_field.dart';
import '../../../../core/widgets/theme3/theme3_status_chip.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../features/orders/models/order_model.dart';
import '../../../../features/orders/providers/order_provider.dart';
import '../../../../features/vendor/request_feed/providers/vendor_request_feed_provider.dart';
import '../../../../features/requests/providers/request_provider.dart';
import '../../../../shared/models/user_role.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/routes/app_router.dart';
import 'package:speedmart_lanka/shared/providers/category_provider.dart';
import '../../../../core/storage/storage_service.dart';
import 'package:flutter/services.dart';
import '../../../../shared/models/sri_lanka_banks.dart';
import '../../../../shared/utils/category_constants.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    super.key,
    this.showBackButton = true,
    this.onVendorRequestsTap,
  });

  /// Set to false when embedded as a tab (e.g. vendor bottom nav) so the
  /// AppBar back arrow is hidden.
  final bool showBackButton;
  final VoidCallback? onVendorRequestsTap;

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
  String? _pickedImagePath;

  // Bank detail controllers (vendor only)
  late TextEditingController _bankNameCtrl;
  late TextEditingController _bankBranchCtrl;
  late TextEditingController _bankAccountNameCtrl;
  late TextEditingController _bankAccountNumberCtrl;
  SriLankaBank? _selectedBank;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _businessNameCtrl = TextEditingController();
    _bankNameCtrl = TextEditingController();
    _bankBranchCtrl = TextEditingController();
    _bankAccountNameCtrl = TextEditingController();
    _bankAccountNumberCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recoverCroppedImage();
    });
  }

  bool _dataInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataInitialized) {
      _dataInitialized = true;
      _initData();
      _loadStatsData();
    }
  }

  void _loadStatsData() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    if (user.role == UserRole.vendor) {
      ref.read(orderProvider.notifier).loadVendorOrders();
      ref.read(vendorRequestFeedProvider.notifier).loadFeed();
    } else {
      ref.read(requestProvider.notifier).loadMyRequests();
      ref.read(orderProvider.notifier).loadCustomerOrders();
    }
  }

  void _initData() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _nameCtrl.text = user.fullName;
      _phoneCtrl.text = user.phone;
      _businessNameCtrl.text = user.businessName ?? '';
      _requestedCategories = List.from(user.requestedCategories ?? []);
      _bankNameCtrl.text = user.bankName ?? '';
      _bankBranchCtrl.text = user.bankBranch ?? '';
      _bankAccountNameCtrl.text = user.bankAccountName ?? '';
      _bankAccountNumberCtrl.text = user.bankAccountNumber ?? '';
      // Restore selected bank from saved name
      if (user.bankName != null && user.bankName!.isNotEmpty) {
        try {
          _selectedBank = sriLankaBanks.firstWhere(
            (b) => b.name == user.bankName,
          );
        } catch (_) {
          _selectedBank = null;
        }
      }
      if (_isLocalPath(user.profileImageUrl)) {
        _pickedImagePath = user.profileImageUrl;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _businessNameCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankBranchCtrl.dispose();
    _bankAccountNameCtrl.dispose();
    _bankAccountNumberCtrl.dispose();
    super.dispose();
  }

  bool _isLocalPath(String? path) =>
      path != null && (path.startsWith('/') || path.contains(':\\') || path.contains(':/'));

  Future<void> _recoverCroppedImage() async {
    final recovered = await ImageCropper().recoverImage();
    if (recovered != null && mounted) {
      setState(() => _pickedImagePath = recovered.path);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Profile Photo',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.primary,
          cropStyle: CropStyle.circle,
          lockAspectRatio: true,
          hideBottomControls: false,
          initAspectRatio: CropAspectRatioPreset.square,
          aspectRatioPresets: [CropAspectRatioPreset.square],
        ),
        IOSUiSettings(
          title: 'Crop Profile Photo',
          cropStyle: CropStyle.circle,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
    );
    if (cropped != null && mounted) {
      if (_pickedImagePath != null) {
        FileImage(File(_pickedImagePath!)).evict();
      }
      setState(() => _pickedImagePath = cropped.path);
    }
  }

  bool get _hasProfileChanges {
    final user = ref.read(currentUserProvider);
    if (user == null) return false;

    final currentRequested = List<String>.from(user.requestedCategories ?? [])
        .map((c) => VendorCategories.normalize(c).toLowerCase())
        .toSet();
    final editedRequested = _requestedCategories
        .map((c) => VendorCategories.normalize(c).toLowerCase())
        .toSet();

    final sameName = _nameCtrl.text.trim() == user.fullName;
    final samePhone = _phoneCtrl.text.trim() == user.phone;
    final sameBusinessName = (user.businessName ?? '') == _businessNameCtrl.text.trim();
    final samePickedImage = (_pickedImagePath ?? user.profileImageUrl) == user.profileImageUrl;
    final sameBankName = (user.bankName ?? '') == _bankNameCtrl.text.trim();
    final sameBankBranch = (user.bankBranch ?? '') == _bankBranchCtrl.text.trim();
    final sameBankAccountName = (user.bankAccountName ?? '') == _bankAccountNameCtrl.text.trim();
    final sameBankAccountNumber = (user.bankAccountNumber ?? '') == _bankAccountNumberCtrl.text.trim();
    final sameRequestedCategories = currentRequested.containsAll(editedRequested) && editedRequested.containsAll(currentRequested);

    if (user.role == UserRole.vendor) {
      return !sameName ||
          !samePhone ||
          !sameBusinessName ||
          !samePickedImage ||
          !sameBankName ||
          !sameBankBranch ||
          !sameBankAccountName ||
          !sameBankAccountNumber ||
          !sameRequestedCategories;
    }

    return !sameName || !samePhone || !samePickedImage;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    if (!_hasProfileChanges) {
      if (mounted) {
        setState(() => _isEditing = false);
      }
      return;
    }

    await ref.read(authProvider.notifier).updateProfile(
      fullName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      businessName: user.role == UserRole.vendor ? _businessNameCtrl.text.trim() : null,
      profileImageUrl: _pickedImagePath ?? user.profileImageUrl,
      requestedCategories: user.role == UserRole.vendor ? _requestedCategories : null,
      bankName: user.role == UserRole.vendor ? _bankNameCtrl.text.trim() : null,
      bankBranch: user.role == UserRole.vendor ? _bankBranchCtrl.text.trim() : null,
      bankAccountName: user.role == UserRole.vendor ? _bankAccountNameCtrl.text.trim() : null,
      bankAccountNumber: user.role == UserRole.vendor ? _bankAccountNumberCtrl.text.trim() : null,
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
    if (!mounted) return;

    // Use root navigator so dialogs survive shell/route teardown
    final rootCtx = rootNavigatorKey.currentContext;
    if (rootCtx == null) return;

    // Step 1: Confirm logout
    final confirmed = await showDialog<bool>(
      context: rootCtx,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(rootCtx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(rootCtx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final role = ref.read(currentUserProvider)?.role;

    // Step 2: Ask about OTP preference for customer/vendor
    if (role == UserRole.customer || role == UserRole.vendor) {
      final keep = await showDialog<bool>(
        context: rootCtx,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Stay signed in?'),
          content: const Text(
            'Would you like to skip OTP verification next time you log in?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(rootCtx).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(rootCtx).pop(true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );
      if (keep == null) return;
      if (role == UserRole.customer) {
        await StorageService.saveCustomerRememberMe(keep);
      } else {
        await StorageService.saveVendorRememberMe(keep);
      }
    }

    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.read(currentUserProvider);  // read, not watch — prevents rebuild killing dialogs
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
                : RouteNames.customerHome,
          );
        }
      },
      child: Scaffold(
        appBar: widget.showBackButton
            ? Theme3AppBar(
                title: 'Profile',
                showBackButton: true,
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
                        setState(() {
                          _isEditing = false;
                          _pickedImagePath = null;
                          _selectedBank = null;
                        });
                      },
                    ),
                ],
              )
            : null,
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              120,
            ),
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
          // Edit toggle row — only shown when there is no AppBar (embedded tab)
          if (!widget.showBackButton)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(isEditing ? Icons.close_rounded : Icons.edit_rounded),
                onPressed: () {
                  if (isEditing) {
                    _initData();
                    setState(() {
                      _isEditing = false;
                      _pickedImagePath = null;
                      _selectedBank = null;
                    });
                  } else {
                    setState(() => _isEditing = true);
                  }
                },
              ),
            ),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 54,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                backgroundImage: _pickedImagePath != null
                    ? FileImage(File(_pickedImagePath!))
                    : _isLocalPath(user.profileImageUrl)
                        ? FileImage(File(user.profileImageUrl!)) as ImageProvider
                        : user.profileImageUrl != null
                            ? NetworkImage(user.profileImageUrl!) as ImageProvider
                            : null,
                child: (_pickedImagePath == null && user.profileImageUrl == null)
                    ? Text(
                        user.initials,
                        style: AppTextStyles.h1(
                          isDark ? AppColors.primaryDark : AppColors.primary,
                        ),
                      )
                    : null,
              ),
              if (isEditing)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
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
              label: 'Verified Shop Owner',
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
    final requestState = ref.watch(requestProvider);
    final orderState = ref.watch(orderProvider);
    final vendorFeedState = ref.watch(vendorRequestFeedProvider);

    final int totalRequests;
    final int activeOrders;
    final int completedOrders;

    if (user.role == UserRole.vendor) {
      totalRequests = vendorFeedState.items.length;
      activeOrders = orderState.orders.where((o) =>
          o.status != OrderStatus.delivered &&
          o.status != OrderStatus.completed &&
          o.status != OrderStatus.cancelled).length;
      completedOrders = orderState.orders.where((o) =>
          o.status == OrderStatus.delivered ||
          o.status == OrderStatus.completed).length;
    } else {
      totalRequests = requestState.requests.length;
      activeOrders = orderState.orders.where((o) =>
          o.status != OrderStatus.delivered &&
          o.status != OrderStatus.completed &&
          o.status != OrderStatus.cancelled).length;
      completedOrders = orderState.orders.where((o) =>
          o.status == OrderStatus.delivered ||
          o.status == OrderStatus.completed).length;
    }
    
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
            child: _buildStatCard(
              'Requests',
              totalRequests.toString(),
              Icons.receipt_long_outlined,
              isDark,
              onTap: user.role == UserRole.vendor
                  ? (widget.onVendorRequestsTap ??
                    () => context.push(RouteNames.vendorNearbyRequests))
                  : null,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: _buildStatCard(
              'Active',
              activeOrders.toString(),
              Icons.shopping_bag_outlined,
              isDark,
              onTap: user.role == UserRole.vendor
                  ? () => context.push(RouteNames.vendorOrders, extra: {'initialTabIndex': 0})
                  : null,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: _buildStatCard(
              'Completed',
              completedOrders.toString(),
              Icons.check_circle_outline_rounded,
              isDark,
              onTap: user.role == UserRole.vendor
                  ? () => context.push(RouteNames.vendorOrders, extra: {'initialTabIndex': 1})
                  : null,
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    final card = Theme3AppCard(
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

    return onTap == null
        ? card
        : InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: card,
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
      ('Personal Information', Icons.person_outline_rounded, true, () {
        setState(() => _isEditing = true);
      }),
      if (user.role == UserRole.customer) ('Delivery Address', Icons.location_on_outlined, true, () {
        context.push(RouteNames.customerDeliveryAddress);
      }),
      ('Notifications', Icons.notifications_outlined, false, () {}),
      ('Payment Methods', Icons.payment_outlined, true, () => _showPaymentMethodsSheet(isDark)),
    ];

    return [
      Theme3AppCard(
        type: Theme3CardType.standard,
        padding: EdgeInsets.zero,
        child: Column(
          children: List.generate(
            items.length,
            (index) {
              final (label, icon, hasAction, onTap) = items[index];
              final isLast = index == items.length - 1;
              return Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: hasAction ? onTap : null,
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
                            if (hasAction)
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
        textCapitalization: TextCapitalization.words,
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
          textCapitalization: TextCapitalization.words,
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
      const SizedBox(height: AppSpacing.md),
      _buildBankDetailsSection(user, isDark, isEditing),
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
                  .map((cat) => VendorCategories.display(
                        VendorCategories.normalize(cat.toString()),
                      ))
                  .toSet()
                  .toList()
                  .map<Widget>((label) => Theme3StatusChip(
                        label: label,
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
            .map((c) => VendorCategories.normalize(c.toString()).toLowerCase())
            .toSet();

        final requestableCategories = activeCategories
            .where((cat) => cat.isActive)
            .where((cat) => !approvedKeys.contains(cat.normalizedKey.toLowerCase()))
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
                      label: Text(VendorCategories.display(cat.normalizedKey)),
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

  Widget _buildBankDetailsSection(dynamic user, bool isDark, bool isEditing) {
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final hasBankDetails = (user.bankName ?? '').isNotEmpty ||
        (user.bankAccountNumber ?? '').isNotEmpty;

    return Theme3AppCard(
      type: Theme3CardType.standard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_rounded, size: 20,
                  color: isDark ? AppColors.primaryDark : AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Bank / Payment Details',
                    style: AppTextStyles.labelMedium(secondaryText)),
              ),
              if (!isEditing && !hasBankDetails)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Not set',
                      style: AppTextStyles.caption(AppColors.warning)
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Used by admin to settle commission charges.',
            style: AppTextStyles.caption(secondaryText),
          ),
          const SizedBox(height: AppSpacing.md),
          if (isEditing) ...[
            // Bank picker
            GestureDetector(
              onTap: () => _showBankPickerSheet(isDark, primaryText, secondaryText),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: secondaryText.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (_selectedBank != null) ...[
                      Image.asset(
                        _selectedBank!.logoAsset,
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.account_balance_outlined, size: 36),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_selectedBank!.name, style: AppTextStyles.bodyMedium(primaryText))),
                    ] else ...[
                      Icon(Icons.account_balance_outlined, color: secondaryText),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Select your bank', style: AppTextStyles.bodyMedium(secondaryText))),
                    ],
                    Icon(Icons.keyboard_arrow_down_rounded, color: secondaryText),
                  ],
                ),
              ),
            ),
            if (_selectedBank != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.primaryDark : AppColors.primary).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14,
                        color: isDark ? AppColors.primaryDark : AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Account number: ${_selectedBank!.digitRule}',
                      style: AppTextStyles.caption(
                          isDark ? AppColors.primaryDark : AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Theme3AppTextField(
              label: 'Branch',
              controller: _bankBranchCtrl,
              prefixIcon: Icons.location_city_outlined,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.sm),
            Theme3AppTextField(
              label: 'Account Holder Name',
              controller: _bankAccountNameCtrl,
              prefixIcon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _bankAccountNumberCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                if (_selectedBank != null)
                  LengthLimitingTextInputFormatter(_selectedBank!.maxDigits),
              ],
              decoration: InputDecoration(
                labelText: 'Account Number',
                hintText: _selectedBank?.hint ?? 'Enter account number',
                prefixIcon: const Icon(Icons.numbers_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return null;
                final digits = val.trim();
                if (_selectedBank != null) {
                  if (digits.length < _selectedBank!.minDigits ||
                      digits.length > _selectedBank!.maxDigits) {
                    return '${_selectedBank!.name} requires ${_selectedBank!.digitRule}';
                  }
                }
                return null;
              },
            ),
          ] else if (hasBankDetails) ...[
            // View mode — show a styled card with bank info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  _bankInfoRow(Icons.account_balance_outlined, 'Bank',
                      user.bankName ?? '—', primaryText, secondaryText),
                  const SizedBox(height: 8),
                  _bankInfoRow(Icons.location_city_outlined, 'Branch',
                      user.bankBranch ?? '—', primaryText, secondaryText),
                  const SizedBox(height: 8),
                  _bankInfoRow(Icons.person_outline_rounded, 'Account Holder',
                      user.bankAccountName ?? '—', primaryText, secondaryText),
                  const SizedBox(height: 8),
                  _bankInfoRow(Icons.numbers_rounded, 'Account No.',
                      user.bankAccountNumber ?? '—', primaryText, secondaryText),
                ],
              ),
            ),
          ] else
            Text('Tap edit to add your bank details.',
                style: AppTextStyles.bodySmall(secondaryText)),
        ],
      ),
    );
  }

  Widget _bankInfoRow(IconData icon, String label, String value,
      Color primaryText, Color secondaryText) {
    return Row(
      children: [
        Icon(icon, size: 16, color: secondaryText),
        const SizedBox(width: 8),
        Text('$label: ', style: AppTextStyles.caption(secondaryText)),
        Expanded(
          child: Text(value,
              style: AppTextStyles.bodySmall(primaryText),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  void _showBankPickerSheet(bool isDark, Color primaryText, Color secondaryText) {
    final bgColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final searchCtrl = TextEditingController();
    List<SriLankaBank> filtered = List.from(sriLankaBanks);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.55,
              minChildSize: 0.4,
              maxChildSize: 0.85,
              builder: (_, scrollCtrl) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: borderColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Select Bank', style: AppTextStyles.h3(primaryText)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchCtrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search bank...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (q) {
                          setSheetState(() {
                            filtered = sriLankaBanks
                                .where((b) => b.name.toLowerCase().contains(q.toLowerCase()))
                                .toList();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollCtrl,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => Divider(height: 0, color: borderColor),
                          itemBuilder: (_, i) {
                            final bank = filtered[i];
                            final isSelected = _selectedBank?.code == bank.code;
                            return ListTile(
                              leading: Image.asset(
                                bank.logoAsset,
                                width: 40,
                                height: 40,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(Icons.account_balance_outlined, size: 36),
                              ),
                              title: Text(bank.name, style: AppTextStyles.bodyMedium(primaryText)),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle_rounded,
                                      color: isDark ? AppColors.primaryDark : AppColors.primary)
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedBank = bank;
                                  _bankNameCtrl.text = bank.name;
                                  _bankAccountNumberCtrl.clear();
                                });
                                Navigator.of(ctx).pop();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showPaymentMethodsSheet(bool isDark) {
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final bgColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Payment Methods', style: AppTextStyles.h2(primaryText)),
            const SizedBox(height: 4),
            Text('Manage how you pay for orders', style: AppTextStyles.bodySmall(secondaryText)),
            const SizedBox(height: 20),
            _paymentMethodTile(
              icon: Icons.money_rounded,
              label: 'Cash on Delivery',
              sublabel: 'Pay when your order arrives',
              color: AppColors.success,
              isDark: isDark,
              primaryText: primaryText,
              secondaryText: secondaryText,
              borderColor: borderColor,
            ),
            const SizedBox(height: 12),
            _paymentMethodTile(
              icon: Icons.credit_card_rounded,
              label: 'Online Payment',
              sublabel: 'Card / bank transfer at checkout',
              color: AppColors.primary,
              isDark: isDark,
              primaryText: primaryText,
              secondaryText: secondaryText,
              borderColor: borderColor,
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Card saving and wallet top-up coming soon.',
                      style: AppTextStyles.caption(secondaryText),
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

  Widget _paymentMethodTile({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required bool isDark,
    required Color primaryText,
    required Color secondaryText,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.subtitle(primaryText)),
                Text(sublabel, style: AppTextStyles.caption(secondaryText)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Available', style: AppTextStyles.caption(color).copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection(bool isDark) {
    final items = [
      ('Help Center', Icons.help_outline_rounded, false, () {}),
      ('Contact Support', Icons.support_agent_rounded, false, () {}),
      ('About App', Icons.info_outlined, false, () {}),
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
                final (label, icon, hasAction, onTap) = items[index];
                final isLast = index == items.length - 1;
                return Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: hasAction ? onTap : null,
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
                              if (hasAction)
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
          onPressed: isLoading ? null : onLogout,
          isLoading: false,
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
        onPressed: _hasProfileChanges ? _handleSave : null,
        isLoading: isLoading,
      ),
    ];
  }
}



