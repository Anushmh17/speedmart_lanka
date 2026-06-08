import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/sri_lanka_phone_formatter.dart';
import '../../../../core/utils/sri_lanka_phone_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../shared/models/user_role.dart';
import '../../../location/services/sri_lanka_location_service.dart';
import '../../../location/services/gps_location_service.dart';
import '../../../auth/customer_registration/services/country_detection_service.dart';
import '../../../vendor/registration/widgets/vendor_location_map_picker.dart';
import '../../../admin/providers/category_provider.dart';
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
  final _inviteCtrl = TextEditingController();
  final List<String> _selectedCategories = [];

  // Vendor country detection
  bool _isDetectingCountry = false;
  String? _detectedCountry;
  String? _selectedCountry;
  String? _detectionSource;
  bool _isSriLanka = false;
  bool _usePhoneVerification = false;

  // Shop detail controllers (vendor-only)
  final _shopAddressCtrl = TextEditingController();
  final _shopProvinceCtrl = TextEditingController();
  final _shopDistrictCtrl = TextEditingController();
  final _shopAreaCtrl = TextEditingController();
  final _shopLatitudeCtrl = TextEditingController();
  final _shopLongitudeCtrl = TextEditingController();
  final _brNumberCtrl = TextEditingController();

  double? _detectedLatitude;
  double? _detectedLongitude;
  double? _gpsAccuracy;
  String? _shopLocationSource;
  bool _isDetectingGps = false;
  bool _locationConfirmed = false;

  Color get _roleColor {
    switch (widget.role) {
      case UserRole.customer: return AppColors.customerColor;
      case UserRole.vendor:   return AppColors.vendorColor;
      case UserRole.admin:    return AppColors.adminColor;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.role == UserRole.vendor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _detectVendorCountry();
      });
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
    _inviteCtrl.dispose();
    _shopAddressCtrl.dispose();
    _shopProvinceCtrl.dispose();
    _shopDistrictCtrl.dispose();
    _shopAreaCtrl.dispose();
    _shopLatitudeCtrl.dispose();
    _shopLongitudeCtrl.dispose();
    _brNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectVendorCountry() async {
    if (widget.role != UserRole.vendor) return;
    
    setState(() => _isDetectingCountry = true);
    
    debugPrint('[VendorCountry] Starting country detection');
    
    try {
      final service = CountryDetectionService();
      final result = await service.detect();
      
      setState(() {
        _detectedCountry = result.countryCode ?? (result.isLkUser ? 'LK' : 'OTHER');
        _selectedCountry = _detectedCountry;
        _detectionSource = result.method.name;
        _isSriLanka = result.isLkUser;
        _usePhoneVerification = result.isLkUser;
        _isDetectingCountry = false;
      });
      
      debugPrint('[VendorCountry] detected country: $_detectedCountry');
      debugPrint('[VendorCountry] detection source: $_detectionSource');
      debugPrint('[VendorCountry] isSriLanka: $_isSriLanka');
      debugPrint('[VendorCountry] verification method: ${_usePhoneVerification ? "phone" : "email"}');
    } catch (e) {
      debugPrint('[VendorCountry] Detection failed: $e');
      setState(() => _isDetectingCountry = false);
      if (mounted) {
        _showCountrySelectionDialog();
      }
    }
  }

  void _showCountrySelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Select your country'),
        content: const Text('We could not detect your country. Please select it manually.'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedCountry = 'LK';
                _detectedCountry = 'LK';
                _detectionSource = 'manual';
                _isSriLanka = true;
                _usePhoneVerification = true;
              });
              debugPrint('[VendorCountry] selected country: LK (manual)');
              Navigator.of(ctx).pop();
            },
            child: const Text('Sri Lanka'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedCountry = 'OTHER';
                _detectedCountry = 'OTHER';
                _detectionSource = 'manual';
                _isSriLanka = false;
                _usePhoneVerification = false;
              });
              debugPrint('[VendorCountry] selected country: OTHER (manual)');
              Navigator.of(ctx).pop();
            },
            child: const Text('Other Country'),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    debugPrint('[AuthUI] Submit pressed, staying on register screen');
    if (!_formKey.currentState!.validate()) return;
    if (widget.role == UserRole.vendor && _selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
      );
      return;
    }
    if (widget.role == UserRole.vendor) {
      if (_businessCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter business name')),
        );
        return;
      }
      if (_shopAddressCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter shop address')),
        );
        return;
      }
      if (_detectedLatitude == null || _detectedLongitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please confirm shop location on map')),
        );
        return;
      }
      if (!_locationConfirmed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please confirm your shop location')),
        );
        return;
      }
      if (_isSriLanka) {
        final phoneValidation = SriLankaPhoneHelper.validateSriLankaMobile(_phoneCtrl.text);
        if (phoneValidation != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(phoneValidation)),
          );
          return;
        }
      } else {
        final emailValidation = Validators.email(_emailCtrl.text.trim());
        if (emailValidation != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(emailValidation)),
          );
          return;
        }
      }
    }
    if (widget.role == UserRole.admin && _inviteCtrl.text.trim() != 'SPEEDMART_ADMIN') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid admin invite code')),
      );
      return;
    }
    debugPrint('[AuthUI] Calling register, will NOT navigate from _register() method');
    
    // Normalize phone for storage
    String phoneForStorage = _phoneCtrl.text.trim();
    if (widget.role == UserRole.vendor && _isSriLanka) {
      phoneForStorage = SriLankaPhoneHelper.normalizeSriLankaPhoneForStorage(_phoneCtrl.text);
      debugPrint('[VendorCountry] normalized phone for storage: $phoneForStorage');
    } else if (widget.role == UserRole.customer) {
      // Customer registration also uses Sri Lankan phone format
      phoneForStorage = SriLankaPhoneHelper.normalizeSriLankaPhoneForStorage(_phoneCtrl.text);
      debugPrint('[CustomerReg] normalized phone for storage: $phoneForStorage');
    }
    
    // Vendor-specific country/phone audit logs
    if (widget.role == UserRole.vendor) {
      debugPrint('[VendorCountry] phone validation result: ${_isSriLanka ? "Sri Lanka phone validated" : "skipped"}');
      debugPrint('[VendorCountry] email validation result: ${!_isSriLanka ? "email validated" : "skipped"}');
    }
    
    await ref.read(authProvider.notifier).register(
          fullName: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: phoneForStorage,
          password: _passwordCtrl.text,
          role: widget.role,
          businessName: widget.role == UserRole.vendor
              ? _businessCtrl.text.trim()
              : null,
          categories:
              widget.role == UserRole.vendor ? _selectedCategories : null,
          // Shop details for vendors - use same business name for shop name
          shopName: widget.role == UserRole.vendor
              ? _businessCtrl.text.trim()
              : null,
          shopAddress: widget.role == UserRole.vendor
              ? _shopAddressCtrl.text.trim()
              : null,
          shopProvince: widget.role == UserRole.vendor
              ? _shopProvinceCtrl.text.trim().isEmpty
                  ? null
                  : _shopProvinceCtrl.text.trim()
              : null,
          shopDistrict: widget.role == UserRole.vendor
              ? _shopDistrictCtrl.text.trim().isEmpty
                  ? null
                  : _shopDistrictCtrl.text.trim()
              : null,
          shopArea: widget.role == UserRole.vendor
              ? _shopAreaCtrl.text.trim().isEmpty
                  ? null
                  : _shopAreaCtrl.text.trim()
              : null,
          shopLatitude: widget.role == UserRole.vendor
              ? _detectedLatitude
              : null,
          shopLongitude: widget.role == UserRole.vendor
              ? _detectedLongitude
              : null,
          shopLocationAccuracyMeters: widget.role == UserRole.vendor
              ? _gpsAccuracy
              : null,
          shopLocationDetectedAt: widget.role == UserRole.vendor && _detectedLatitude != null
              ? DateTime.now()
              : null,
          shopLocationSource: widget.role == UserRole.vendor
              ? _shopLocationSource
              : null,
          detectedCountry: widget.role == UserRole.vendor
              ? _detectedCountry
              : null,
          selectedCountry: widget.role == UserRole.vendor
              ? _selectedCountry
              : null,
          detectionSource: widget.role == UserRole.vendor
              ? _detectionSource
              : null,
          businessRegistrationNumber: widget.role == UserRole.vendor
              ? _brNumberCtrl.text.trim().isEmpty
                  ? null
                  : _brNumberCtrl.text.trim()
              : null,
        );
    debugPrint('[AuthUI] Register returned, listener will handle navigation');
  }

  Future<void> _detectLocation() async {
    if (!mounted) return;

    setState(() => _isDetectingGps = true);

    try {
      final position = await _getGpsPosition();

      debugPrint('[VendorLocation] gps lat/lng: ${position.latitude}, ${position.longitude}');

      setState(() {
        _detectedLatitude = position.latitude;
        _detectedLongitude = position.longitude;
        _gpsAccuracy = position.accuracy;
        _shopLocationSource = 'gps';
        _shopLatitudeCtrl.text = _detectedLatitude!.toStringAsFixed(6);
        _shopLongitudeCtrl.text = _detectedLongitude!.toStringAsFixed(6);
      });

      debugPrint('[VendorLocation] address: ${_shopAddressCtrl.text}');
      debugPrint('[VendorLocation] is valid: true');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'GPS detected (${_gpsAccuracy!.toStringAsFixed(0)}m accuracy). Drag pin to adjust if needed.',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on LocationException catch (e) {
      debugPrint('[VendorLocation] GPS detection failed: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('[VendorLocation] GPS detection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not detect location: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDetectingGps = false);
      }
    }
  }

  /// Get GPS position using real device location service.
  /// Uses the same location service as customer delivery addresses.
  Future<dynamic> _getGpsPosition() async {
    try {
      final locationService = SriLankaLocationService();
      final result = await locationService.detectCurrentLocation();

      return _VendorPosition(
        latitude: result.gpsResult.latitude,
        longitude: result.gpsResult.longitude,
        accuracy: result.gpsResult.accuracy ?? 50.0,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (prev, next) {
      debugPrint('[AuthUI] Listener triggered: isAuth=${next.isAuthenticated}, isLoading=${next.isLoading}, hasError=${next.hasError}');

      // GUARD 1: If loading, stay on form and show button loading state
      if (next.isLoading) {
        debugPrint('[AuthUI] Register loading, no navigation, button shows loading');
        return; // Don't navigate while loading
      }

      // GUARD 2: If error occurred, ALWAYS stay on form
      if (next.hasError) {
        debugPrint('[AuthUI] *** ERROR STATE DETECTED ***: ${next.error}');
        debugPrint('[AuthUI] Preventing any navigation, error banner will display');

        // Only show snackbar for NEW errors
        if (prev == null || !prev.hasError) {
          debugPrint('[AuthUI] New error, showing snackbar');
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.error!),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return; // *** CRITICAL: BLOCK ALL NAVIGATION WHEN ERROR ***
      }

      // GUARD 3: Only navigate on successful, completed authentication
      if (next.isAuthenticated && !next.isLoading && next.user != null) {
        debugPrint('[AuthUI] Auth success, user: ${next.user!.email}, role: ${next.user!.role}');
        debugPrint('[AuthUI] Navigating to role home');
        switch (next.user!.role) {
          case UserRole.customer:
            context.go(RouteNames.customerHome);
          case UserRole.vendor:
            context.go(RouteNames.vendorHome);
          case UserRole.admin:
            context.go(RouteNames.adminDashboard);
        }
        return;
      }

      debugPrint('[AuthUI] No action: auth=${next.isAuthenticated}, loading=${next.isLoading}, user=${next.user?.email}');
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(RouteNames.roleSelection);
        }
      },
      child: Scaffold(
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
                      onTap: () => context.pop(),
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
                          color: AppColors.vendorColor,
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Admin registration notice
                      if (widget.role == UserRole.admin) ...[
                        _InfoBanner(
                          icon: Icons.warning_amber_rounded,
                          message: 'Admin registration is for development/testing only.',
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

                      if (widget.role == UserRole.vendor && _isDetectingCountry)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.infoContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.info,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Detecting your country...',
                                style: AppTextStyles.bodySmall(AppColors.info),
                              ),
                            ],
                          ),
                        ),
                      if (widget.role == UserRole.vendor && _isDetectingCountry)
                        const SizedBox(height: 16),

                      if (widget.role == UserRole.vendor && !_isDetectingCountry) ...[
                        if (_isSriLanka)
                          AppTextField(
                            label: 'Phone Number',
                            hint: '72 499 9660',
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.phone_outlined,
                            prefixText: '+94 ',
                            validator: SriLankaPhoneHelper.validateSriLankaMobile,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              SriLankaPhoneInputFormatter(),
                            ],
                          )
                        else ...[
                          AppTextField(
                            label: 'Email Address',
                            hint: 'your.email@example.com',
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.email_outlined,
                            validator: Validators.email,
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'Phone Number (Optional)',
                            hint: '+1 234 567 8901',
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.phone_outlined,
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],

                      if (widget.role != UserRole.vendor) ...[
                        AppTextField(
                          label: 'Phone Number',
                          hint: '72 499 9660',
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          prefixIcon: Icons.phone_outlined,
                          prefixText: '+94 ',
                          validator: SriLankaPhoneHelper.validateSriLankaMobile,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            SriLankaPhoneInputFormatter(),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

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
                        Consumer(
                          builder: (context, ref, _) {
                            final activeCategories = ref.watch(activeCategoriesProvider);
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: activeCategories.map((cat) {
                                final selected = _selectedCategories.contains(cat.displayName);
                                return FilterChip(
                                  label: Text(cat.displayName),
                                  selected: selected,
                                  onSelected: (val) {
                                    setState(() {
                                      if (val) {
                                        _selectedCategories.add(cat.displayName);
                                      } else {
                                        _selectedCategories.remove(cat.displayName);
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
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // ── Shop Details Section ──────────────────────
                        Divider(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          height: 32,
                        ),
                        Text(
                          'Shop Details',
                          style: AppTextStyles.h3(
                            isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 16),

                        AppTextField(
                          label: 'Shop Address',
                          hint: 'e.g., 123 Main Street, Colombo',
                          controller: _shopAddressCtrl,
                          prefixIcon: Icons.location_on_outlined,
                          textInputAction: TextInputAction.next,
                          minLines: 2,
                          maxLines: 3,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Shop address is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Province, District, Area
                        AppTextField(
                          label: 'Province (Optional)',
                          hint: 'e.g., Western Province',
                          controller: _shopProvinceCtrl,
                          prefixIcon: Icons.map_outlined,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        AppTextField(
                          label: 'District (Optional)',
                          hint: 'e.g., Colombo',
                          controller: _shopDistrictCtrl,
                          prefixIcon: Icons.domain_outlined,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        AppTextField(
                          label: 'Area / Suburb (Optional)',
                          hint: 'e.g., Fort, Colombo 01',
                          controller: _shopAreaCtrl,
                          prefixIcon: Icons.location_city_outlined,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 20),

                        // ── Location Section ──────────────────────────
                        Text(
                          'Shop Location',
                          style: AppTextStyles.subtitle(
                            isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isDetectingGps ? null : _detectLocation,
                                icon: Icon(_isDetectingGps
                                    ? Icons.hourglass_empty
                                    : Icons.my_location_rounded),
                                label: Text(_isDetectingGps
                                    ? 'Detecting...'
                                    : 'Detect GPS Location'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.vendorColor,
                                  minimumSize: const Size(0, 44),
                                  disabledBackgroundColor:
                                      AppColors.vendorColor.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (_detectedLatitude != null && _detectedLongitude != null) ...[
                          VendorLocationMapPicker(
                            initialLatitude: _detectedLatitude,
                            initialLongitude: _detectedLongitude,
                            onLocationSelected: (lat, lng, source) {
                              debugPrint('[VendorLocation] map pin selected: $lat, $lng');
                              setState(() {
                                _detectedLatitude = lat;
                                _detectedLongitude = lng;
                                _shopLocationSource = source;
                                _shopLatitudeCtrl.text = lat.toStringAsFixed(6);
                                _shopLongitudeCtrl.text = lng.toStringAsFixed(6);
                              });
                              debugPrint('[VendorLocation] saved lat/lng: $lat, $lng');
                            },
                          ),
                          const SizedBox(height: 16),
                          CheckboxListTile(
                            value: _locationConfirmed,
                            onChanged: (val) {
                              setState(() => _locationConfirmed = val ?? false);
                              if (_locationConfirmed) {
                                debugPrint('[VendorLocation] validation result: confirmed');
                              }
                            },
                            title: Text(
                              'I confirm this is my shop location',
                              style: AppTextStyles.bodyMedium(
                                isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 16),
                        ],

                        AppTextField(
                          label: 'Business Registration Number (Optional)',
                          hint: 'e.g., BR123456',
                          controller: _brNumberCtrl,
                          prefixIcon: Icons.receipt_long_outlined,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 28),
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
                        textInputAction: widget.role == UserRole.admin
                            ? TextInputAction.next
                            : TextInputAction.done,
                        prefixIcon: Icons.lock_outline_rounded,
                        validator: (v) =>
                            Validators.confirmPassword(v, _passwordCtrl.text),
                        onFieldSubmitted: widget.role == UserRole.admin
                            ? null
                            : (_) => _register(),
                      ),

                      if (widget.role == UserRole.admin) ...[
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Admin Invite Code',
                          hint: 'Enter admin invite code',
                          controller: _inviteCtrl,
                          obscureText: true,
                          prefixIcon: Icons.vpn_key_outlined,
                          textInputAction: TextInputAction.done,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Invite code is required';
                            }
                            if (v.trim() != 'SPEEDMART_ADMIN') {
                              return 'Invalid invite code';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _register(),
                        ),
                      ],
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
                              onTap: () => context.pop(),
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

/// Position data structure for vendor shop location detection.
class _VendorPosition {
  final double latitude;
  final double longitude;
  final double accuracy;

  _VendorPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });
}
