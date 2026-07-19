import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/utils/validators.dart';
import 'package:speedmart_lanka/features/location/data/sri_lanka_data.dart';
import 'package:speedmart_lanka/features/location/models/sri_lanka_district.dart';
import 'package:speedmart_lanka/features/location/models/sri_lanka_province.dart';
import 'package:speedmart_lanka/features/location/services/gps_location_service.dart';
import 'package:speedmart_lanka/features/location/services/reverse_geocoding_service.dart';
import 'package:speedmart_lanka/features/location/widgets/province_dropdown.dart';
import 'package:speedmart_lanka/features/location/widgets/district_dropdown.dart';
import '../models/registration_step.dart';
import '../providers/customer_registration_provider.dart';
import '../widgets/registration_header.dart';
import '../widgets/registration_section_card.dart';
import '../widgets/nic_input_field.dart';
import '../widgets/phone_field_lk.dart';

class CustomerRegistrationScreen extends ConsumerStatefulWidget {
  const CustomerRegistrationScreen({super.key});

  @override
  ConsumerState<CustomerRegistrationScreen> createState() =>
      _CustomerRegistrationScreenState();
}

class _CustomerRegistrationScreenState
    extends ConsumerState<CustomerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _nicCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _countryCtrl = TextEditingController(text: 'Sri Lanka');
  final _approxAreaCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  // Focus nodes
  final _nameFocus = FocusNode();
  final _nicFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _countryFocus = FocusNode();
  final _approxFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _noteFocus = FocusNode();

  // GPS auto-detect state
  bool _isDetectingGps = false;
  String? _gpsError;

  // Local province/district selections (independent of locationProvider)
  SriLankaProvince? _selectedProvince;
  SriLankaDistrict? _selectedDistrict;

  @override
  void initState() {
    super.initState();
    // Trigger country detection after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerRegistrationProvider.notifier).setMode(isLogin: false);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nicCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _countryCtrl.dispose();
    _approxAreaCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    _nameFocus.dispose();
    _nicFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _countryFocus.dispose();
    _approxFocus.dispose();
    _addressFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  // ── GPS auto-detect ───────────────────────────────────────────────────────

  Future<void> _autoDetectLocation() async {
    setState(() {
      _isDetectingGps = true;
      _gpsError = null;
    });
    try {
      final gps = GpsLocationService();
      final position = await gps.getCurrentPosition();
      final geocoder = ReverseGeocodingService();
      final result = await geocoder.reverseGeocode(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      if (result.geocodingSucceeded &&
          result.province != null &&
          result.district != null) {
        final province = SriLankaData.provinceByName(result.province!);
        final district = SriLankaData.districtByName(result.district!);
        if (province != null && district != null) {
          setState(() {
            _selectedProvince = province;
            _selectedDistrict = district;
            if (result.city != null && _approxAreaCtrl.text.isEmpty) {
              _approxAreaCtrl.text = result.city!;
            }
          });
          ref.read(customerRegistrationProvider.notifier).applyGpsLocation(
                province: province,
                district: district,
                approxArea: result.city ?? '',
              );
        }
      } else {
        setState(() => _gpsError =
            'Could not determine location. Please select manually.');
      }
    } on LocationException catch (e) {
      if (mounted) setState(() => _gpsError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _gpsError = 'GPS unavailable. Please select manually.');
      }
    } finally {
      if (mounted) setState(() => _isDetectingGps = false);
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final reg = ref.read(customerRegistrationProvider.notifier);
    reg.updateFullName(_nameCtrl.text.trim());
    reg.updateNic(_nicCtrl.text.trim());
    reg.updatePhone(_phoneCtrl.text.trim());
    reg.updateEmail(_emailCtrl.text.trim());
    reg.updateCountry(_countryCtrl.text.trim());
    reg.updateApproxArea(_approxAreaCtrl.text.trim());
    reg.updatePreciseAddress(_addressCtrl.text.trim());
    reg.updateDeliveryNote(_noteCtrl.text.trim());
    if (_selectedProvince != null) reg.updateProvince(_selectedProvince);
    if (_selectedDistrict != null) reg.updateDistrict(_selectedDistrict);

    await reg.sendOtp();

    if (!mounted) return;
    final state = ref.read(customerRegistrationProvider);
    if (state.step == RegistrationStep.verifyOtp) {
      context.push(RouteNames.customerOtp);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<CustomerRegistrationState>(customerRegistrationProvider, (prev, next) {
      // Sync controllers and state on change
      if (next.data.isLkUser != prev?.data.isLkUser) {
        if (next.data.isLkUser) {
          _countryCtrl.text = 'Sri Lanka';
        } else {
          _countryCtrl.clear();
        }
        _phoneCtrl.clear();
        _emailCtrl.clear();
        _nicCtrl.clear();
        setState(() {
          _selectedProvince = null;
          _selectedDistrict = null;
        });
      }
    });

    final state = ref.watch(customerRegistrationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLk = state.isLkUser;
    final isLoading = state.isLoading;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              // ── Header ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: RegistrationHeader(
                  step: state.step,
                  onBack: () => context.go(RouteNames.customerLogin),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Error banner ────────────────────────────────
                    if (state.hasError) ...[
                      _ErrorBanner(
                        message: state.error!,
                        onDismiss: () => ref
                            .read(customerRegistrationProvider.notifier)
                            .clearError(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 16),

                    // ── SECTION 1: Personal Info ────────────────────
                    RegistrationSectionCard(
                      icon: Icons.person_rounded,
                      title: 'Personal Information',
                      children: [
                        AppTextField(
                          label: 'Full Name',
                          hint: 'Enter your full name',
                          controller: _nameCtrl,
                          focusNode: _nameFocus,
                          prefixIcon: Icons.badge_rounded,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          validator: Validators.fullName,
                          onFieldSubmitted: (_) =>
                              FocusScope.of(context).requestFocus(
                            isLk ? _phoneFocus : _emailFocus,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Country-aware: phone vs email
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          transitionBuilder: (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                          child: isLk
                              ? Column(
                                  key: const ValueKey('lk-fields'),
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    PhoneFieldLk(
                                      controller: _phoneCtrl,
                                      focusNode: _phoneFocus,
                                      textInputAction: TextInputAction.next,
                                    ),
                                    const SizedBox(height: 16),
                                    NicInputField(
                                      controller: _nicCtrl,
                                      focusNode: _nicFocus,
                                      textInputAction: TextInputAction.next,
                                    ),
                                  ],
                                )
                              : Column(
                                  key: const ValueKey('intl-fields'),
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    AppTextField(
                                      label: 'Email Address',
                                      hint: 'Enter your email',
                                      controller: _emailCtrl,
                                      focusNode: _emailFocus,
                                      prefixIcon: Icons.email_outlined,
                                      keyboardType:
                                          TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      validator: Validators.email,
                                    ),
                                    const SizedBox(height: 16),
                                    AppTextField(
                                      label: 'Phone Number (optional)',
                                      hint: '+1 234 567 8901',
                                      controller: _phoneCtrl,
                                      focusNode: _phoneFocus,
                                      prefixIcon: Icons.phone_outlined,
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.next,
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── SECTION 2: Delivery Location ────────────────
                    RegistrationSectionCard(
                      icon: Icons.location_on_rounded,
                      title: 'Delivery Location',
                      accentColor: AppColors.secondary,
                      trailing: isLk
                          ? _GpsDetectButton(
                              isLoading: _isDetectingGps,
                              onTap: _autoDetectLocation,
                            )
                          : null,
                      children: [
                        if (isLk && _gpsError != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.warningContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 16,
                                    color: AppColors.warning),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _gpsError!,
                                    style: AppTextStyles.caption(
                                        AppColors.warning),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (isLk) ...[
                          // Province dropdown
                          ProvinceDropdown(
                            value: _selectedProvince,
                            onChanged: (p) => setState(() {
                              _selectedProvince = p;
                              _selectedDistrict = null;
                            }),
                          ),
                          const SizedBox(height: 12),

                          // Province validation error
                          if (_selectedProvince == null)
                            Builder(builder: (_) => const SizedBox.shrink()),

                          // District dropdown
                          DistrictDropdown(
                            selectedProvince: _selectedProvince,
                            value: _selectedDistrict,
                            onChanged: (d) =>
                                setState(() => _selectedDistrict = d),
                          ),
                          const SizedBox(height: 16),
                        ] else ...[
                          AppTextField(
                            label: 'Country',
                            hint: 'Enter your country',
                            controller: _countryCtrl,
                            focusNode: _countryFocus,
                            prefixIcon: Icons.public_rounded,
                            textInputAction: TextInputAction.next,
                            validator: (v) => Validators.required(v,
                                fieldName: 'Country'),
                            onFieldSubmitted: (_) => FocusScope.of(context)
                                .requestFocus(_approxFocus),
                          ),
                          const SizedBox(height: 16),
                        ],

                        AppTextField(
                          label: 'Approximate Area',
                          hint: 'e.g. Nugegoda, Kandy Town',
                          controller: _approxAreaCtrl,
                          focusNode: _approxFocus,
                          prefixIcon: Icons.near_me_rounded,
                          textInputAction: TextInputAction.next,
                          validator: (v) => Validators.required(v,
                              fieldName: 'Approximate area'),
                          onFieldSubmitted: (_) => FocusScope.of(context)
                              .requestFocus(_addressFocus),
                        ),
                        const SizedBox(height: 16),

                        AppTextField(
                          label: 'Precise Delivery Address',
                          hint: 'House no., street, town…',
                          controller: _addressCtrl,
                          focusNode: _addressFocus,
                          prefixIcon: Icons.home_rounded,
                          maxLines: 2,
                          textInputAction: TextInputAction.next,
                          validator: (v) => Validators.required(v,
                              fieldName: 'Delivery address'),
                          onFieldSubmitted: (_) => FocusScope.of(context)
                              .requestFocus(_noteFocus),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── SECTION 3: Additional (optional) ───────────
                    RegistrationSectionCard(
                      icon: Icons.sticky_note_2_rounded,
                      title: 'Additional Info',
                      accentColor: AppColors.accent,
                      bottomPadding: 16,
                      trailing: Chip(
                        label: Text(
                          'Optional',
                          style: AppTextStyles.caption(AppColors.accent)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        backgroundColor:
                            AppColors.accent.withValues(alpha: 0.1),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      children: [
                        AppTextField(
                          label: 'Delivery Note',
                          hint: 'e.g. Ring bell, leave at gate…',
                          controller: _noteCtrl,
                          focusNode: _noteFocus,
                          prefixIcon: Icons.note_alt_rounded,
                          maxLines: 2,
                          textInputAction: TextInputAction.done,
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Province/District validation error ──────────
                    if (isLk && (_selectedProvince == null || _selectedDistrict == null))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '* Please select your Province and District',
                          style: AppTextStyles.bodySmall(AppColors.error),
                        ),
                      ),

                    // ── Submit CTA ──────────────────────────────────
                    AppButton(
                      label: 'Continue — Verify OTP',
                      onPressed: () {
                        if (isLk && (_selectedProvince == null || _selectedDistrict == null)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select your Province and District'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        _submit();
                      },
                      isLoading: isLoading,
                      color: AppColors.primary,
                      icon: Icons.send_rounded,
                    ),

                    const SizedBox(height: 16),

                    // ── Sign in link ────────────────────────────────
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
                            onTap: () => context.go(RouteNames.customerLogin),
                            child: Text(
                              'Sign In',
                              style: AppTextStyles.labelLarge(AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Supporting widgets ─────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
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
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded,
                color: AppColors.error, size: 18),
          ),
        ],
      ),
    );
  }
}

class _GpsDetectButton extends StatelessWidget {
  const _GpsDetectButton({required this.isLoading, required this.onTap});
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.secondary),
              )
            else
              const Icon(Icons.my_location_rounded,
                  size: 14, color: AppColors.secondary),
            const SizedBox(width: 5),
            Text(
              isLoading ? 'Detecting…' : 'Auto Detect',
              style: AppTextStyles.caption(AppColors.secondary)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}


