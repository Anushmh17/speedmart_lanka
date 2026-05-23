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
  String? _gpsError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) syncFromProvider();
    });
  }

  /// Syncs local dropdown/controllers from [deliveryLocationProvider].
  void syncFromProvider() {
    _applyFromLocationState(ref.read(deliveryLocationProvider));
  }

  void _applyFromLocationState(LocationState locationState) {
    final loc = locationState.currentLocation;

    if (loc != null) {
      _areaCtrl.text = locationState.approximateAreaText.isNotEmpty
          ? locationState.approximateAreaText
          : (loc.approximateAreaText.isNotEmpty
              ? loc.approximateAreaText
              : loc.displayArea);
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
      _gpsError = null;
    });

    try {
      await ref.read(deliveryLocationProvider.notifier).fetchCurrentLocation();
      if (!mounted) return;

      final locationState = ref.read(deliveryLocationProvider);
      if (locationState.errorMessage != null) {
        setState(() => _gpsError = locationState.errorMessage);
      } else {
        _applyFromLocationState(locationState);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _gpsError = 'Could not detect location. Enter manually.');
      }
    } finally {
      if (mounted) setState(() => _isDetectingGps = false);
    }
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

    // Keep form state aligned with what we saved.
    if (mounted) {
      setState(() {
        _province = province;
        _district = district;
      });
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
      }
    });

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isDetectingGps ? null : detectGps,
              icon: _isDetectingGps
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
              label: Text(
                _isDetectingGps ? 'Detecting...' : 'Use Current GPS Location',
              ),
            ),
          ),
          if (_gpsError != null) ...[
            const SizedBox(height: 8),
            Text(_gpsError!, style: AppTextStyles.caption(AppColors.warning)),
          ],
          const SizedBox(height: 16),
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
          SearchableLocationField(
            key: ValueKey('area-${_areaCtrl.text}'),
            initialValue: _areaCtrl.text,
            showGpsButton: false,
            labelText: 'City / Suburb / Approximate Area',
            hintText: 'e.g. Nugegoda, Kandy Town',
            onChanged: (text) {
              _areaCtrl.text = text;
              ref.read(deliveryLocationProvider.notifier).setManualArea(text);
            },
            onManualTextSubmitted: (text) {
              _areaCtrl.text = text;
              ref.read(deliveryLocationProvider.notifier).setManualArea(text);
            },
            onSuggestionSelected: (s) {
              _areaCtrl.text = s.display;
              ref.read(deliveryLocationProvider.notifier).applySuggestion(s);
              if (mounted) syncFromProvider();
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
