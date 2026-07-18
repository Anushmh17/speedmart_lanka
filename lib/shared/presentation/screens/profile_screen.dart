import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_state_widgets.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/models/user_role.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/storage/storage_service.dart';
import '../../../features/customer/delivery_address/models/customer_delivery_address.dart';
import '../../../features/customer/delivery_address/providers/customer_delivery_address_provider.dart';
import '../../../features/auth/customer_registration/providers/customer_registration_provider.dart';
import '../../../features/location/providers/location_provider.dart';
import '../../../core/navigation/bottom_nav_visibility.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/providers/category_provider.dart';
import '../../../shared/utils/category_sync_helper.dart';

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
  
  List<String> _selectedCategories = [];
  String? _pickedImagePath;  // unsaved pick — never overwritten by _initData
  String? _savedImagePath;   // last persisted local path from user model
  int _imageVersion = 0;

  bool _deliveryAddressLoadScheduled = false;
  bool _dataInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _businessNameCtrl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleDeliveryAddressLoad();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataInitialized) {
      _dataInitialized = true;
      _initData();
    }
  }

  void _scheduleDeliveryAddressLoad() {
    if (_deliveryAddressLoadScheduled) return;
    final user = ref.read(currentUserProvider);
    if (user?.role != UserRole.customer) return;

    _deliveryAddressLoadScheduled = true;
    Future.microtask(() async {
      if (!mounted) return;
      await ref
          .read(customerDeliveryAddressProvider.notifier)
          .loadForCurrentUser();
    });
  }

  bool _isLocalPath(String? path) =>
      path != null && (path.startsWith('/') || path.contains(':\\') || path.contains(':/'));

  void _initData() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _nameCtrl.text = user.fullName;
      _phoneCtrl.text = user.phone;
      _businessNameCtrl.text = user.businessName ?? '';
      _selectedCategories = List.from(user.requestedCategories?.isNotEmpty == true
          ? user.requestedCategories!
          : user.allowedCategories ?? []);
      // Sync saved path from user model (local file paths only)
      _savedImagePath = _isLocalPath(user.profileImageUrl) ? user.profileImageUrl : null;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _businessNameCtrl.dispose();
    Future.microtask(() {
      try {
        ref.read(bottomNavVisibilityProvider.notifier).setManualHidden(false);
      } catch (_) {}
    });
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null || !mounted) return;

    final user = ref.read(currentUserProvider);
    final primaryColor = user?.role == UserRole.vendor ? AppColors.vendorColor : AppColors.customerColor;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: primaryColor,
          toolbarWidgetColor: Colors.white,
          statusBarColor: primaryColor,
          activeControlsWidgetColor: primaryColor,
          backgroundColor: Colors.black,
          cropStyle: CropStyle.circle,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          showCropGrid: false,
        ),
        IOSUiSettings(
          title: 'Crop Photo',
          cropStyle: CropStyle.circle,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
    );
    if (cropped != null && mounted) {
      if (_pickedImagePath != null) FileImage(File(_pickedImagePath!)).evict();
      if (_savedImagePath != null) FileImage(File(_savedImagePath!)).evict();
      setState(() {
        _pickedImagePath = cropped.path;
        _imageVersion++;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final imageToSave = _pickedImagePath ?? _savedImagePath ?? user.profileImageUrl;

    await ref.read(authProvider.notifier).updateProfile(
      fullName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      businessName: user.role == UserRole.vendor ? _businessNameCtrl.text.trim() : null,
      profileImageUrl: imageToSave,
      requestedCategories: user.role == UserRole.vendor ? _selectedCategories : null,
    );

    if (!mounted) return;
    final newSaved = _pickedImagePath ?? _savedImagePath;
    setState(() {
      _isEditing = false;
      _savedImagePath = newSaved;
      _pickedImagePath = null;
      _imageVersion++;
      ref.read(bottomNavVisibilityProvider.notifier).setManualHidden(false);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: user.role == UserRole.vendor
            ? const Text('Category change request sent to admin.')
            : const Text('Profile updated successfully!'),
        backgroundColor: user.role == UserRole.vendor ? AppColors.vendorColor : AppColors.customerColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleLogout() async {
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

    // Step 2: Ask about OTP preference only if they previously opted in to remember me
    if (role == UserRole.customer || role == UserRole.vendor) {
      final alreadyRemembered = role == UserRole.customer
          ? await StorageService.getCustomerRememberMe()
          : await StorageService.getVendorRememberMe();

      if (alreadyRemembered) {
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
    }

    // Step 3: Perform logout and cleanup
    ref.read(bottomNavVisibilityProvider.notifier).setManualHidden(false);
    await ref.read(authProvider.notifier).logout();
    ref.read(customerRegistrationProvider.notifier).reset();
    ref.read(deliveryLocationProvider.notifier).clearLocation();
    ref.read(customerDeliveryAddressProvider.notifier).reset();
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

    final showBottomNav = ref.watch(bottomNavVisibilityProvider);
    final bottomPadding = showBottomNav ? 140.0 : 32.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPadding),
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
                        setState(() {
                          _isEditing = false;
                          _pickedImagePath = null;
                          ref.read(bottomNavVisibilityProvider.notifier).setManualHidden(false);
                        });
                        _initData();
                      } else {
                        setState(() {
                          _isEditing = true;
                          ref.read(bottomNavVisibilityProvider.notifier).setManualHidden(true);
                        });
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
                            key: ValueKey(_imageVersion),
                            radius: 45,
                            backgroundColor: primaryColor.withOpacity(0.1),
                            backgroundImage: _pickedImagePath != null
                                ? FileImage(File(_pickedImagePath!)) as ImageProvider
                                : _savedImagePath != null
                                    ? FileImage(File(_savedImagePath!)) as ImageProvider
                                    : user.profileImageUrl != null && !_isLocalPath(user.profileImageUrl)
                                        ? NetworkImage(user.profileImageUrl!) as ImageProvider
                                        : null,
                            child: (_pickedImagePath == null && _savedImagePath == null && user.profileImageUrl == null)
                                ? Text(user.initials, style: AppTextStyles.h1(primaryColor))
                                : null,
                          ),
                        ),
                        if (_isEditing)
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                              ),
                              child: Icon(Icons.camera_alt_rounded, color: primaryColor, size: 20),
                            ),
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

              if (user.role == UserRole.customer) ...createCustomerSection(context, primaryText, cardColor, borderColor, primaryColor, secondaryText),

              if (user.role == UserRole.vendor) ...createVendorSection(user, primaryText, secondaryText, cardColor, borderColor, primaryColor, isDark),

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

  List<Widget> createCustomerSection(BuildContext context, Color primaryText, Color cardColor, Color borderColor, Color primaryColor, Color secondaryText) {
    return [
      const SizedBox(height: 16),
      Text('Delivery Address', style: AppTextStyles.subtitle(primaryText)),
      const SizedBox(height: 12),
      _buildCustomerDeliveryAddressCard(
        context: context,
        cardColor: cardColor,
        borderColor: borderColor,
        primaryText: primaryText,
        secondaryText: secondaryText,
        primaryColor: primaryColor,
      ),
      const SizedBox(height: 16),
      Text('Payment History', style: AppTextStyles.subtitle(primaryText)),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => context.push(RouteNames.customerPaymentHistory),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Icon(Icons.history_rounded, color: primaryColor),
            title: Text('View Payment History', style: AppTextStyles.bodyMedium(primaryText)),
            subtitle: Text('See your past COD and online payments.', style: AppTextStyles.caption(secondaryText)),
            trailing: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: secondaryText),
          ),
        ),
      ),
    ];
  }

  List<Widget> createVendorSection(UserModel user, Color primaryText, Color secondaryText, Color cardColor, Color borderColor, Color primaryColor, bool isDark) {
    return [
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
              Consumer(
                builder: (context, ref, _) {
                  final allCategories = ref.watch(activeCategoriesProvider);
                  final displayNames = CategorySyncHelper.getDisplayNames(
                    user.allowedCategories ?? [],
                    allCategories,
                  );
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: displayNames
                        .map((displayName) => Chip(
                          label: Text(displayName),
                          backgroundColor: AppColors.success.withValues(alpha: 0.12),
                          labelStyle: AppTextStyles.bodySmall(AppColors.success)
                              .copyWith(fontWeight: FontWeight.w600),
                        ))
                        .toList(),
                  );
                },
              )
            else
              Text(
                'No categories approved yet.',
                style: AppTextStyles.bodySmall(secondaryText),
              ),
            const SizedBox(height: 16),
            
            if (!_isEditing && user.hasPendingCategoryRequest == true && user.requestedCategories != null && user.requestedCategories!.isNotEmpty) ...
              [
                Row(
                  children: [
                    Icon(Icons.pending_outlined, color: AppColors.warning, size: 20),
                    const SizedBox(width: 12),
                    Text('Pending Request', style: AppTextStyles.labelLarge(AppColors.warning)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Waiting for admin approval',
                  style: AppTextStyles.caption(secondaryText),
                ),
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, _) {
                    final allCategories = ref.watch(activeCategoriesProvider);
                    final displayNames = CategorySyncHelper.getDisplayNames(
                      user.requestedCategories ?? [],
                      allCategories,
                    );
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: displayNames
                          .map((displayName) => Chip(
                            label: Text(displayName),
                            backgroundColor: AppColors.warning.withValues(alpha: 0.12),
                            labelStyle: AppTextStyles.bodySmall(AppColors.warning)
                                .copyWith(fontWeight: FontWeight.w600),
                          ))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            
            if (_isEditing)
              ...
              [
                Row(
                  children: [
                    Icon(Icons.category_outlined, color: secondaryText, size: 20),
                    const SizedBox(width: 12),
                    Text('Request Categories', style: AppTextStyles.labelLarge(secondaryText)),
                  ],
                ),
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, _) {
                    final allCategories = ref.watch(activeCategoriesProvider);
                    final approvedSet = (user.allowedCategories ?? []).toSet();
                    final requestable = allCategories
                        .where((cat) => cat.isActive && !approvedSet.contains(cat.normalizedKey))
                        .toList();
                    
                    if (requestable.isEmpty) {
                      return Text(
                        'All active categories are already approved for your account.',
                        style: AppTextStyles.bodySmall(secondaryText),
                      );
                    }
                    
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: requestable.map((cat) {
                        final isSelected = _selectedCategories.contains(cat.normalizedKey);
                        return FilterChip(
                          label: Text(cat.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                if (!_selectedCategories.contains(cat.normalizedKey)) {
                                  _selectedCategories.add(cat.normalizedKey);
                                }
                              } else {
                                _selectedCategories.remove(cat.normalizedKey);
                              }
                            });
                          },
                          selectedColor: primaryColor.withValues(alpha: 0.15),
                          checkmarkColor: primaryColor,
                          labelStyle: AppTextStyles.bodySmall(
                            isSelected ? primaryColor : secondaryText,
                          ).copyWith(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          backgroundColor: isDark
                              ? Colors.grey.withValues(alpha: 0.1)
                              : Colors.grey.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? primaryColor
                                  : (isDark
                                      ? Colors.grey.withValues(alpha: 0.2)
                                      : Colors.grey.shade200),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
          ],
        ),
      ),
    ];
  }

  Widget _buildCustomerDeliveryAddressCard({
    required BuildContext context,
    required Color cardColor,
    required Color borderColor,
    required Color primaryText,
    required Color secondaryText,
    required Color primaryColor,
  }) {
    return GestureDetector(
      onTap: () => context.push(RouteNames.customerDeliveryAddress),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Icon(Icons.location_on_outlined, color: primaryColor),
          title: Text('Delivery Address', style: AppTextStyles.bodyMedium(primaryText)),
          subtitle: Text('Manage your delivery location', style: AppTextStyles.caption(secondaryText)),
          trailing: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: secondaryText),
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
            textCapitalization: (label == 'Full Name' || label == 'Business Name')
                ? TextCapitalization.words
                : TextCapitalization.none,
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


