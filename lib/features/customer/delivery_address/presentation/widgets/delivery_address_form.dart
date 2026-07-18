import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../location/data/sri_lanka_data.dart';
import '../../../../location/models/delivery_location.dart';
import '../../../../location/models/sri_lanka_district.dart';
import '../../../../location/models/sri_lanka_province.dart';
import '../../../../location/providers/location_provider.dart';
import '../../../../location/widgets/district_dropdown.dart';
import '../../../../location/widgets/province_dropdown.dart';
import '../../../../location/widgets/searchable_location_field.dart';

class DeliveryAddressForm extends ConsumerStatefulWidget {
  const DeliveryAddressForm({
    super.key,
    required this.formKey,
    this.showDeliveryNote = true,
  });

  final GlobalKey<FormState> formKey;
  final bool showDeliveryNote;

  @override
  ConsumerState<DeliveryAddressForm> createState() => DeliveryAddressFormState();
}

class DeliveryAddressFormState extends ConsumerState<DeliveryAddressForm> {
  SriLankaProvince? _province;
  SriLankaDistrict? _district;
  final _areaCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _isDetectingGps = false;
  bool _userEditedApproxArea = false;

  @override
  void initState() {
    super.initState();
    // DO NOT sync from provider here - let the parent screen control the timing
    // The parent screen will call syncFromProvider() explicitly after loading address
  }

  /// Syncs local dropdown/controllers from [deliveryLocationProvider].
  void syncFromProvider() {
    _applyFromLocationState(ref.read(deliveryLocationProvider));
  }

  void _applyFromLocationState(LocationState locationState) {
    final loc = locationState.currentLocation;

    debugPrint('[CustomerLocation] _applyFromLocationState called');
    debugPrint('[CustomerLocation] locationState.approximateAreaText: ${locationState.approximateAreaText}');
    debugPrint('[CustomerLocation] currentLocation: ${loc != null ? 'exists' : 'null'}');
    if (loc != null) {
      debugPrint('[CustomerLocation] loc.approximateAreaText: ${loc.approximateAreaText}');
      debugPrint('[CustomerLocation] loc.displayArea: ${loc.displayArea}');
    }

    if (_userEditedApproxArea) {
      debugPrint('[ApproxAreaAudit] Skipping controller overwrite because user edited approximate area');
      debugPrint('[ApproxAreaAudit] Preserving manual value: "${_areaCtrl.text}"');
    }

    if (loc != null) {
      if (!_userEditedApproxArea) {
        final areaText = locationState.approximateAreaText.isNotEmpty
            ? locationState.approximateAreaText
            : (loc.approximateAreaText.isNotEmpty
                ? loc.approximateAreaText
                : loc.displayArea);
        _areaCtrl.text = areaText;
        debugPrint('[CustomerLocation] Restored controller value: $areaText');
      }

      _streetCtrl.text = locationState.preciseAddress.isNotEmpty
          ? locationState.preciseAddress
          : loc.streetAddress;
      _noteCtrl.text = loc.deliveryNote;
    }

    var province = locationState.selectedProvince;
    var district = locationState.selectedDistrict;

    if (province == null && loc != null && loc.province.isNotEmpty) {
      province = SriLankaData.provinceByName(loc.province);
    }
    if (district == null && loc != null && loc.district.isNotEmpty) {
      district = _resolveDistrict(loc.district, province);
    }

    if (province != null) {
      debugPrint('[DeliveryAddress] GPS province detected: ${province.name}');
    }
    if (district != null) {
      debugPrint('[DeliveryAddress] GPS district detected: ${district.name}');
    }

    if (!mounted) return;
    setState(() {
      _province = province;
      _district = district;
      if (province != null && district == null) {
        _district = null;
      }
    });
  }

  SriLankaDistrict? _resolveDistrict(
    String districtName,
    SriLankaProvince? province,
  ) {
    if (province != null) {
      final match = SriLankaData.districtsForProvince(province.id)
          .where((d) => d.name.toLowerCase() == districtName.toLowerCase().trim())
          .toList();
      if (match.isNotEmpty) return match.first;
    }
    return SriLankaData.districtByName(districtName);
  }

  @override
  void dispose() {
    _areaCtrl.dispose();
    _streetCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> detectGps() async {
    if (!mounted) return;
    setState(() {
      _isDetectingGps = true;
      _userEditedApproxArea = false;
    });
    debugPrint('[ApproxAreaAudit] GPS detection triggered - manual edit flag reset');

    try {
      await ref.read(deliveryLocationProvider.notifier).fetchCurrentLocation();
      if (!mounted) return;

      final locationState = ref.read(deliveryLocationProvider);
      if (locationState.errorMessage == null) {
        _applyFromLocationState(locationState);
      }
    } catch (_) {
      // GPS error silently ignored — user can still fill in manually
    } finally {
      if (mounted) setState(() => _isDetectingGps = false);
    }
  }

  Widget _buildAccuracyCard(WidgetRef ref) {
    final locationState = ref.watch(deliveryLocationProvider);
    final loc = locationState.currentLocation;

    if (loc == null || loc.accuracy == null) {
      if (loc?.source == 'manual' || (loc?.isManualOverride == true && loc?.accuracy == null)) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Manual address entry • GPS accuracy not available',
            style: AppTextStyles.caption(
              Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final accuracy = loc.accuracy!;
    final detectedAt = loc.detectedAt;
    final timeStr = detectedAt != null
        ? '${detectedAt.hour.toString().padLeft(2, '0')}:${detectedAt.minute.toString().padLeft(2, '0')}'
        : 'Unknown time';

    IconData icon;
    Color bgColor;
    Color textColor;
    String label;
    bool showImproveButton;

    if (accuracy <= 50) {
      icon = Icons.gps_fixed_rounded;
      bgColor = AppColors.success.withOpacity(0.1);
      textColor = AppColors.success;
      label = loc.accuracyLabel;
      showImproveButton = false;
    } else if (accuracy <= 150) {
      icon = Icons.location_on_rounded;
      bgColor = AppColors.warning.withOpacity(0.1);
      textColor = AppColors.warning;
      label = loc.accuracyLabel;
      showImproveButton = false;
    } else {
      icon = Icons.location_searching_rounded;
      bgColor = AppColors.error.withOpacity(0.1);
      textColor = AppColors.error;
      label = loc.accuracyLabel;
      showImproveButton = true;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: textColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyMedium(textColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Detected at $timeStr',
                    style: AppTextStyles.caption(textColor.withOpacity(0.7)),
                  ),
                  if (showImproveButton) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      child: OutlinedButton.icon(
                        onPressed: _isDetectingGps ? null : detectGps,
                        icon: _isDetectingGps
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(
                          _isDetectingGps ? 'Re-detecting...' : 'Improve Accuracy',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool validateAndSync() {
    if (!(widget.formKey.currentState?.validate() ?? false)) return false;

    final locationState = ref.read(deliveryLocationProvider);
    final province = _province ?? locationState.selectedProvince;
    final district = _district ?? locationState.selectedDistrict;

    if (province == null || district == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select province and district.')),
      );
      return false;
    }

    final area = _areaCtrl.text.trim();
    final street = _streetCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    debugPrint('[ApproxAreaAudit] ===== FORM validateAndSync =====');
    debugPrint('[ApproxAreaAudit] _areaCtrl.text: "$area"');
    debugPrint('[CustomerLocation] Manual approximate typed: $area');
    debugPrint('[CustomerLocation] Manual street typed: $street');
    debugPrint('[CustomerLocation] Manual province: ${province.name}, district: ${district.name}');

    final loc = (locationState.currentLocation ??
            const DeliveryLocation(
              province: '',
              district: '',
              city: '',
              suburb: '',
              formattedAddress: '',
            ))
        .copyWith(
      province: province.name,
      district: district.name,
      suburb: area,
      approximateAreaText: area,
      formattedAddress: '$area, ${district.name}, ${province.name}',
      streetAddress: street,
      preciseAddress: street,
      deliveryNote: note,
      isGpsDetected: locationState.isGpsDetected,
      isManualOverride: !locationState.isGpsDetected,
    );

    ref.read(deliveryLocationProvider.notifier).setLocation(loc);
    ref.read(deliveryLocationProvider.notifier).setDeliveryNote(note);

    debugPrint('[ApproxAreaAudit] Created loc.approximateAreaText: "${loc.approximateAreaText}"');
    debugPrint('[ApproxAreaAudit] Created loc.suburb: "${loc.suburb}"');
    debugPrint('[ApproxAreaAudit] Final approximate area before save: "$area"');
    debugPrint('[CustomerLocation] Saving approximateArea: ${loc.approximateAreaText}');
    debugPrint('[CustomerLocation] Saving province/district: ${loc.province}/${loc.district}');
    debugPrint('[CustomerLocation] Saving with GPS: ${locationState.isGpsDetected}');

    // Keep form state aligned with what we saved.
    if (mounted) {
      setState(() {
        _province = province;
        _district = district;
        _userEditedApproxArea = false;
      });
      debugPrint('[ApproxAreaAudit] Save success, manual edit flag reset');
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    ref.listen<LocationState>(deliveryLocationProvider, (previous, next) {
      if (previous?.isGpsLoading == true &&
          !next.isGpsLoading &&
          next.currentLocation != null) {
        _applyFromLocationState(next);
        return;
      }

      final previousLocation = previous?.currentLocation;
      final nextLocation = next.currentLocation;
      final pinMoved = nextLocation?.source == 'map_pin' &&
          nextLocation != null &&
          (previousLocation?.latitude != nextLocation.latitude ||
              previousLocation?.longitude != nextLocation.longitude);

      if (pinMoved) {
        setState(() => _userEditedApproxArea = false);
        debugPrint('[ApproxAreaAudit] Map pin moved - manual edit flag reset');
        _applyFromLocationState(next);
      }
    });

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProvinceDropdown(
            value: _province,
            onChanged: (p) {
              setState(() {
                _province = p;
                _district = null;
              });
              ref.read(deliveryLocationProvider.notifier).setProvince(p);
            },
          ),
          const SizedBox(height: 12),
          DistrictDropdown(
            selectedProvince: _province,
            value: _district,
            onChanged: (d) {
              setState(() => _district = d);
              ref.read(deliveryLocationProvider.notifier).setDistrict(d);
            },
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              debugPrint('[ApproxAreaUI] ===== BUILD SearchableLocationField =====');
              debugPrint('[ApproxAreaUI] _areaCtrl.text = "${_areaCtrl.text}"');
              debugPrint('[ApproxAreaUI] locationState.approximateAreaText = "${ref.watch(deliveryLocationProvider).approximateAreaText}"');
              debugPrint('[ApproxAreaUI] _userEditedApproxArea = $_userEditedApproxArea');
              return SearchableLocationField(
                key: const ValueKey('area-field'),
                initialValue: _areaCtrl.text,
                showGpsButton: false,
                labelText: 'City / Suburb / Approximate Area',
                hintText: 'e.g. Nugegoda, Kandy Town',
                onChanged: (text) {
                  setState(() => _userEditedApproxArea = true);
                  _areaCtrl.text = text;
                  debugPrint('[ApproxAreaAudit] User typed manual area: "$text"');
                  ref.read(deliveryLocationProvider.notifier).setApproximateAreaText(text);
                },
                onManualTextSubmitted: (text) {
                  setState(() => _userEditedApproxArea = true);
                  _areaCtrl.text = text;
                  debugPrint('[ApproxAreaAudit] User submitted manual area: "$text"');
                  ref.read(deliveryLocationProvider.notifier).setApproximateAreaText(text);
                },
                onSuggestionSelected: (s) {
                  setState(() => _userEditedApproxArea = false);
                  _areaCtrl.text = s.display;
                  debugPrint('[ApproxAreaAudit] Suggestion selected - manual edit flag reset');
                  ref.read(deliveryLocationProvider.notifier).applySuggestion(s);
                  if (mounted) syncFromProvider();
                },
              );
            },
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Precise Street Address',
            hint: 'House no., street, lane…',
            controller: _streetCtrl,
            prefixIcon: Icons.home_rounded,
            maxLines: 2,
            validator: (v) => Validators.required(v, fieldName: 'Street address'),
            onChanged: (v) =>
                ref.read(deliveryLocationProvider.notifier).updateStreetAddress(v),
          ),
          if (widget.showDeliveryNote) ...[
            const SizedBox(height: 12),
            AppTextField(
              label: 'Delivery Note (optional)',
              hint: 'Landmark, gate code, etc.',
              controller: _noteCtrl,
              prefixIcon: Icons.sticky_note_2_outlined,
              maxLines: 2,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Your exact address is shared with vendors only after order confirmation.',
            style: AppTextStyles.caption(secondary),
          ),
        ],
      ),
    );
  }
}

