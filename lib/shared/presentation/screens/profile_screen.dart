import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_state_widgets.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/auth/data/auth_repository.dart';
import '../../../shared/models/user_role.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/storage/storage_service.dart';
import '../../../features/customer/delivery_address/providers/customer_delivery_address_provider.dart';
import '../../../features/auth/customer_registration/providers/customer_registration_provider.dart';
import '../../../features/auth/customer_registration/services/otp_service.dart';
import '../../../features/location/providers/location_provider.dart';
import '../../../core/navigation/bottom_nav_visibility.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/providers/category_provider.dart';
import '../../../shared/utils/category_sync_helper.dart';
import '../../../core/utils/permission_utils.dart';

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

  bool _isSaving = false;

  bool get _hasChanges {
    final user = ref.read(currentUserProvider);
    if (user == null) return false;
    return _nameCtrl.text.trim() != user.fullName ||
        _phoneCtrl.text.trim() != user.phone ||
        _businessNameCtrl.text.trim() != (user.businessName ?? '') ||
        _pickedImagePath != null;
  }

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

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _pickedImagePath = null;
    });
    ref.read(bottomNavVisibilityProvider.notifier).setManualHidden(false);
    profileEditingNotifier.value = null;
    _initData();
  }

  @override
  void dispose() {
    profileEditingNotifier.value = null;
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
    if (!await AppPermissionUtils.ensureGalleryPermission(context)) {
      return;
    }

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

    final newPhone = _phoneCtrl.text.trim();

    // Customer changing phone → OTP verification required
    if (user.role == UserRole.customer && newPhone != user.phone) {
      await _verifyPhoneChangeOtp(newPhone: newPhone, user: user);
      return;
    }

    await _saveProfile(user: user, phone: newPhone);
  }

  Future<void> _saveProfile({required UserModel user, required String phone, bool silent = false}) async {
    setState(() => _isSaving = true);
    try {
      final imageToSave = _pickedImagePath ?? _savedImagePath ?? user.profileImageUrl;
      await ref.read(authProvider.notifier).updateProfile(
        fullName: _nameCtrl.text.trim(),
        phone: phone,
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
      profileEditingNotifier.value = null;
      if (!silent) {
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save profile. Please try again.'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _verifyPhoneChangeOtp({required String newPhone, required UserModel user}) async {
    setState(() => _isSaving = true);

    // Check if the new phone is already registered by another customer
    final alreadyExists = await AuthRepository.instance.checkCustomerExists(newPhone);
    if (!mounted) return;
    if (alreadyExists) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This phone number is already registered.'), backgroundColor: AppColors.error),
      );
      return;
    }

    final otpService = ref.read(otpServiceProvider);
    final result = await otpService.sendOtp(channel: OtpChannel.phone, destination: newPhone);
    setState(() => _isSaving = false);

    if (!mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Failed to send OTP.'), backgroundColor: AppColors.error),
      );
      return;
    }

    await _showPhoneOtpSheet(newPhone: newPhone, user: user, otpService: otpService);
  }

  Future<void> _showPhoneOtpSheet({
    required String newPhone,
    required UserModel user,
    required OtpService otpService,
  }) async {
    final controllers = List.generate(6, (_) => TextEditingController());
    final focusNodes = List.generate(6, (_) => FocusNode());
    bool sheetSaving = false;
    String? sheetError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final bg = isDark ? AppColors.cardDark : Colors.white;
          final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
          final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

          final screenHeight = MediaQuery.of(ctx).size.height;
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(minHeight: screenHeight * 0.55),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Text('Verify New Number', style: AppTextStyles.h3(primaryText)),
                  const SizedBox(height: 8),
                  Text('Enter the OTP sent to $newPhone', style: AppTextStyles.bodyMedium(secondaryText), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) => Container(
                      width: 44,
                      height: 52,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.customerColor, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                        color: isDark ? AppColors.cardDark : Colors.grey.shade100,
                      ),
                      child: Center(
                        child: TextField(
                          controller: controllers[i],
                          focusNode: focusNodes[i],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: AppTextStyles.h3(primaryText).copyWith(fontSize: 20),
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: true,
                            fillColor: Colors.transparent,
                            contentPadding: EdgeInsets.zero,
                            isCollapsed: true,
                          ),
                          onChanged: (v) {
                            if (v.isNotEmpty && i < 5) focusNodes[i + 1].requestFocus();
                            if (v.isEmpty && i > 0) focusNodes[i - 1].requestFocus();
                          },
                        ),
                      ),
                    )),
                  ),
                  if (sheetError != null) ...[const SizedBox(height: 12), Text(sheetError!, style: AppTextStyles.bodySmall(AppColors.error))],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: sheetSaving ? null : () async {
                        final code = controllers.map((c) => c.text).join();
                        if (code.length < 6) {
                          setSheet(() => sheetError = 'Please enter all 6 digits.');
                          return;
                        }
                        setSheet(() { sheetSaving = true; sheetError = null; });
                        final ok = await otpService.verifyOtp(channel: OtpChannel.phone, destination: newPhone, code: code);
                        if (!ok) {
                          setSheet(() { sheetSaving = false; sheetError = 'Incorrect OTP. Please try again.'; });
                          return;
                        }
                        if (!mounted) return;
                        // ignore: use_build_context_synchronously
                        Navigator.of(ctx).pop();
                        await _saveProfile(user: user, phone: newPhone, silent: true);
                        if (!mounted) return;
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Phone number updated successfully!'),
                            backgroundColor: AppColors.customerColor,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.customerColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: sheetSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text('Verify & Save', style: AppTextStyles.button(Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in controllers) c.dispose();
      for (final f in focusNodes) f.dispose();
    });
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
                        _cancelEdit();
                      } else {
                        setState(() {
                          _isEditing = true;
                          ref.read(bottomNavVisibilityProvider.notifier).setManualHidden(true);
                        });
                        profileEditingNotifier.value = _cancelEdit;
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
                onChanged: (_) => setState(() {}),
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
                maxLength: 10,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                onChanged: (_) => setState(() {}),
              ),

              if (user.role == UserRole.customer) ...createCustomerSection(context, primaryText, cardColor, borderColor, primaryColor, secondaryText),

              if (user.role == UserRole.vendor) ...createVendorSection(user, primaryText, secondaryText, cardColor, borderColor, primaryColor, isDark),

              const SizedBox(height: 32),
              
              if (_isEditing)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_isSaving || isLoading || !_hasChanges) ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: primaryColor.withOpacity(0.5),
                    ),
                    child: (_isSaving || isLoading)
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text('Save Changes', style: AppTextStyles.button(!_hasChanges ? Colors.white54 : Colors.white).copyWith(fontSize: 16)),
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
    final user = ref.read(currentUserProvider);
    return [
      const SizedBox(height: 16),
      Text('Account Details', style: AppTextStyles.subtitle(primaryText)),
      const SizedBox(height: 12),
      // Email — read-only
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.email_outlined, color: secondaryText, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email', style: AppTextStyles.labelSmall(secondaryText)),
                  const SizedBox(height: 2),
                  Text(user?.email ?? '', style: AppTextStyles.bodyLarge(primaryText)),
                ],
              ),
            ),
            Icon(Icons.lock_outline_rounded, color: secondaryText, size: 16),
          ],
        ),
      ),
      const SizedBox(height: 12),
      // NIC — read-only
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.badge_outlined, color: secondaryText, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NIC Number', style: AppTextStyles.labelSmall(secondaryText)),
                  const SizedBox(height: 2),
                  Text(user?.nic ?? 'Not provided', style: AppTextStyles.bodyLarge(primaryText)),
                ],
              ),
            ),
            Icon(Icons.lock_outline_rounded, color: secondaryText, size: 16),
          ],
        ),
      ),
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
        onChanged: (_) => setState(() {}),
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
    int? maxLength,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
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
            maxLength: maxLength,
            validator: validator,
            textCapitalization: (label == 'Full Name' || label == 'Business Name')
                ? TextCapitalization.words
                : TextCapitalization.none,
            style: AppTextStyles.bodyLarge(primaryText),
            onChanged: onChanged,
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



