import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/delivery_location.dart';
import '../models/location_suggestion.dart';
import '../models/sri_lanka_district.dart';
import '../models/sri_lanka_province.dart';
import '../repositories/local_location_repository.dart';
import '../repositories/location_repository.dart';
import '../services/gps_location_service.dart';
import '../services/sri_lanka_location_service.dart';
import '../data/sri_lanka_data.dart';

// ── State ──────────────────────────────────────────────────────────────────

/// Immutable state for the location module.
class LocationState {
  /// The fully resolved delivery location (null until set).
  final DeliveryLocation? currentLocation;

  /// True while a GPS fetch + geocoding is in progress.
  final bool isGpsLoading;

  /// Current device location permission status.
  final LocationPermission? permissionStatus;

  /// Error message to display to the user, null when no error.
  final String? errorMessage;

  /// Error code from [LocationException], null when no error.
  final LocationExceptionCode? errorCode;

  /// Whether the last GPS geocoding attempt failed
  /// (coordinates obtained but area could not be resolved).
  final bool geocodingFailed;

  /// Dropdown: currently selected province.
  final SriLankaProvince? selectedProvince;

  /// Dropdown: currently selected district (filtered by province).
  final SriLankaDistrict? selectedDistrict;

  /// Free text for approximate area (suburb / town / area name).
  final String approximateAreaText;

  /// The precise door / unit / street address typed by the user.
  /// NEVER replaced automatically by GPS detection.
  final String preciseAddress;

  /// Search suggestions shown in the searchable field.
  final List<LocationSuggestion> suggestions;

  /// Recent searches loaded from SharedPreferences.
  final List<LocationSuggestion> recentSearches;

  /// True while recent searches are being loaded.
  final bool isLoadingRecents;

  const LocationState({
    this.currentLocation,
    this.isGpsLoading = false,
    this.permissionStatus,
    this.errorMessage,
    this.errorCode,
    this.geocodingFailed = false,
    this.selectedProvince,
    this.selectedDistrict,
    this.approximateAreaText = '',
    this.preciseAddress = '',
    this.suggestions = const [],
    this.recentSearches = const [],
    this.isLoadingRecents = false,
  });

  LocationState copyWith({
    DeliveryLocation? currentLocation,
    bool? isGpsLoading,
    LocationPermission? permissionStatus,
    String? errorMessage,
    LocationExceptionCode? errorCode,
    bool? geocodingFailed,
    SriLankaProvince? selectedProvince,
    SriLankaDistrict? selectedDistrict,
    String? approximateAreaText,
    String? preciseAddress,
    List<LocationSuggestion>? suggestions,
    List<LocationSuggestion>? recentSearches,
    bool? isLoadingRecents,
    // Explicit null-clearers
    bool clearCurrentLocation = false,
    bool clearError = false,
    bool clearProvince = false,
    bool clearDistrict = false,
    bool clearSuggestions = false,
  }) {
    return LocationState(
      currentLocation:
          clearCurrentLocation ? null : (currentLocation ?? this.currentLocation),
      isGpsLoading: isGpsLoading ?? this.isGpsLoading,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      geocodingFailed: geocodingFailed ?? this.geocodingFailed,
      selectedProvince:
          clearProvince ? null : (selectedProvince ?? this.selectedProvince),
      selectedDistrict:
          clearDistrict ? null : (selectedDistrict ?? this.selectedDistrict),
      approximateAreaText: approximateAreaText ?? this.approximateAreaText,
      preciseAddress: preciseAddress ?? this.preciseAddress,
      suggestions:
          clearSuggestions ? const [] : (suggestions ?? this.suggestions),
      recentSearches: recentSearches ?? this.recentSearches,
      isLoadingRecents: isLoadingRecents ?? this.isLoadingRecents,
    );
  }

  /// Districts available for the currently selected province.
  List<SriLankaDistrict> get availableDistricts {
    if (selectedProvince == null) return [];
    return SriLankaData.districtsForProvince(selectedProvince!.id);
  }

  /// True when we have enough data to consider the location usable.
  bool get isLocationReady {
    final loc = currentLocation;
    if (loc == null) return false;
    return loc.hasAreaData || loc.hasCoordinates;
  }

  // ── Backward Compatibility Getters ─────────────────────────────────────────

  String get suburb => currentLocation?.suburb ?? '';
  String get city => currentLocation?.city ?? '';
  String get streetAddress => currentLocation?.streetAddress ?? '';
  double? get latitude => currentLocation?.latitude;
  double? get longitude => currentLocation?.longitude;
  String get displayArea => currentLocation?.displayArea ?? '';
  bool get isGpsDetected => currentLocation?.source == 'gps';
  bool get isManualOverride => currentLocation?.isManualOverride ?? false;

  Map<String, dynamic> toJson() => currentLocation?.toJson() ?? {};
}

// ── Notifier ───────────────────────────────────────────────────────────────

class LocationNotifier extends StateNotifier<LocationState> {
  final LocationRepository _repository;
  final SriLankaLocationService _locationService;

  LocationNotifier({
    required LocationRepository repository,
    required SriLankaLocationService locationService,
  })  : _repository = repository,
        _locationService = locationService,
        super(const LocationState()) {
    _init();
  }

  Future<void> _init() async {
    // 1. Restore previously saved delivery location (fixes vendor count = 0 on restart)
    final saved = await _repository.loadDeliveryLocation();
    if (saved != null) {
      SriLankaProvince? province;
      SriLankaDistrict? district;
      if (saved.province.isNotEmpty) {
        province = SriLankaData.provinceByName(saved.province);
      }
      if (province != null && saved.district.isNotEmpty) {
        district = SriLankaData.districtByName(saved.district);
      }
      state = state.copyWith(
        currentLocation: saved,
        selectedProvince: province,
        selectedDistrict: district,
        approximateAreaText: saved.approximateAreaText,
        preciseAddress: saved.preciseAddress,
      );
      debugPrint('[Location] Restored saved delivery location: ${saved.displayArea}');
    }

    // 2. Load permission status and recent searches
    final permission = await GpsLocationService().checkPermission();
    state = state.copyWith(
      permissionStatus: permission,
      isLoadingRecents: true,
    );
    final recents = await _repository.loadRecentSearches();
    state = state.copyWith(
      recentSearches: recents,
      isLoadingRecents: false,
    );
  }

  /// Persists the current delivery location to local storage.
  Future<void> _persistLocation() async {
    final loc = state.currentLocation;
    if (loc != null) {
      await _repository.saveDeliveryLocation(loc);
    }
  }

  // ── GPS ──────────────────────────────────────────────────────────────────

  /// Fetches the current GPS position, reverse geocodes it, and updates state.
  ///
  /// IMPORTANT: If [state.preciseAddress] is non-empty (user has typed it),
  /// it is preserved — GPS data never overwrites it.
  Future<void> fetchCurrentLocation() async {
    if (state.isGpsLoading) return;

    state = state.copyWith(isGpsLoading: true, clearError: true);

    try {
      final result = await _locationService.detectCurrentLocation();

      // Preserve user-typed precise address
      final preservedPrecise = state.preciseAddress;

      final location = result.location.copyWith(
        preciseAddress: preservedPrecise.isNotEmpty ? preservedPrecise : null,
        streetAddress: preservedPrecise.isNotEmpty ? preservedPrecise : null,
      );

      // Sync province / district dropdowns from GPS result
      SriLankaProvince? province;
      SriLankaDistrict? district;

      if (location.province.isNotEmpty) {
        province = SriLankaData.provinceByName(location.province);
      }
      if (province != null && location.district.isNotEmpty) {
        district = SriLankaData.districtByName(location.district);
      }

      state = state.copyWith(
        currentLocation: location,
        isGpsLoading: false,
        geocodingFailed: !result.geocodingSucceeded,
        selectedProvince: province,
        selectedDistrict: district,
        approximateAreaText: location.approximateAreaText,
        permissionStatus: LocationPermission.always,
      );

      await _persistLocation();

      if (location.accuracy != null) {
        debugPrint('[Location] Accuracy saved to delivery address: ${location.accuracy}m');
      }
    } on LocationException catch (e) {
      final permission = await GpsLocationService().checkPermission();
      state = state.copyWith(
        isGpsLoading: false,
        errorMessage: e.message,
        errorCode: e.code,
        permissionStatus: permission,
      );
    } catch (_) {
      state = state.copyWith(
        isGpsLoading: false,
        errorMessage:
            'Could not detect GPS. Please type your delivery area manually.',
      );
    }
  }

  // ── Province / District ───────────────────────────────────────────────────

  /// Set the selected province. Clears district selection automatically.
  void setProvince(SriLankaProvince? province) {
    state = state.copyWith(
      selectedProvince: province,
      clearDistrict: true,
    );
    _updateLocationFromDropdowns();
  }

  /// Set the selected district (must belong to [state.selectedProvince]).
  void setDistrict(SriLankaDistrict? district) {
    state = state.copyWith(selectedDistrict: district);
    _updateLocationFromDropdowns();
  }

  void _updateLocationFromDropdowns() {
    final province = state.selectedProvince;
    final district = state.selectedDistrict;

    final location = _locationService.buildFromManualSelection(
      provinceName: province?.name ?? '',
      districtName: district?.name ?? '',
      approximateAreaText: state.approximateAreaText,
      preciseAddress: state.preciseAddress,
    );

    state = state.copyWith(currentLocation: location);
  }

  // ── Manual Area Text ──────────────────────────────────────────────────────

  /// Update the approximate area free-text field.
  /// Does NOT clear province/district if already selected.
  void setApproximateAreaText(String text) {
    state = state.copyWith(approximateAreaText: text);

    final loc = state.currentLocation;
    if (loc != null) {
      state = state.copyWith(
        currentLocation: loc.copyWith(
          approximateAreaText: text,
          suburb: text,
          source: 'manual',
          isManualOverride: true,
        ),
      );
    } else {
      _updateLocationFromDropdowns();
    }
  }

  // ── Precise Address ───────────────────────────────────────────────────────

  /// Update the user-typed precise address.
  /// This field is NEVER overwritten by GPS data.
  void setPreciseAddress(String address) {
    state = state.copyWith(preciseAddress: address);

    final loc = state.currentLocation;
    if (loc != null) {
      state = state.copyWith(
        currentLocation: loc.copyWith(
          preciseAddress: address,
          streetAddress: address,
          isManualOverride: true,
        ),
      );
    }
  }

  // ── Backward Compatibility Methods ────────────────────────────────────────

  /// Legacy compatibility: alias for setApproximateAreaText
  void setManualArea(String areaText) => setApproximateAreaText(areaText);

  /// Legacy compatibility: alias for setPreciseAddress
  void updateStreetAddress(String streetAddress) => setPreciseAddress(streetAddress);

  // ── Full Manual Override ──────────────────────────────────────────────────

  /// Replace the entire delivery location (e.g. from address book).
  void setLocation(DeliveryLocation location) {
    debugPrint('[ApproxAreaAudit] ===== LOCATION PROVIDER setLocation =====');
    debugPrint('[ApproxAreaAudit] Input location.approximateAreaText: "${location.approximateAreaText}"');
    debugPrint('[ApproxAreaAudit] Input location.suburb: "${location.suburb}"');
    
    // Sync province/district dropdowns
    SriLankaProvince? province;
    SriLankaDistrict? district;

    if (location.province.isNotEmpty) {
      province = SriLankaData.provinceByName(location.province);
    }
    if (province != null && location.district.isNotEmpty) {
      district = SriLankaData.districtByName(location.district);
    }

    state = state.copyWith(
      currentLocation: location,
      selectedProvince: province,
      selectedDistrict: district,
      approximateAreaText: location.approximateAreaText,
      preciseAddress: location.preciseAddress,
    );

    unawaited(_persistLocation());

    debugPrint('[ApproxAreaAudit] State updated: state.approximateAreaText: "${state.approximateAreaText}"');
    debugPrint('[ApproxAreaAudit] State updated: state.currentLocation.approximateAreaText: "${state.currentLocation?.approximateAreaText}"');
  }

  Future<void> updateDeliveryPin({
    required double latitude,
    required double longitude,
  }) async {
    if (latitude == 0.0 || longitude == 0.0) {
      state = state.copyWith(
        errorMessage: 'Please select a valid delivery location.',
      );
      return;
    }

    final existing = state.currentLocation;
    final precise = state.preciseAddress.isNotEmpty
        ? state.preciseAddress
        : (existing?.preciseAddress ?? existing?.streetAddress ?? '');
    final note = existing?.deliveryNote ?? '';

    final resolved = await _locationService.resolvePinLocation(
      latitude: latitude,
      longitude: longitude,
      existingPreciseAddress: precise,
      existingDeliveryNote: note,
    );

    final areaText = resolved.approximateAreaText.isNotEmpty
        ? resolved.approximateAreaText
        : (existing?.approximateAreaText ?? '');
    final location = resolved.copyWith(
      province: resolved.province.isNotEmpty ? resolved.province : existing?.province,
      district: resolved.district.isNotEmpty ? resolved.district : existing?.district,
      suburb: areaText.isNotEmpty ? areaText : null,
      approximateAreaText: areaText,
      formattedAddress: resolved.formattedAddress.isNotEmpty
          ? resolved.formattedAddress
          : existing?.formattedAddress,
    );

    setLocation(location);
    state = state.copyWith(clearError: true);
  }

  // ── Suggestions ───────────────────────────────────────────────────────────

  /// Run a search query and update [state.suggestions].
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(clearSuggestions: true);
      return;
    }
    final results = await _repository.searchLocations(query);
    state = state.copyWith(suggestions: results);
  }

  /// Apply a suggestion (user tapped an autocomplete item).
  Future<void> applySuggestion(LocationSuggestion suggestion) async {
    final location = _locationService.buildFromSuggestion(
      suggestion,
      preciseAddress: state.preciseAddress,
    );

    SriLankaProvince? province;
    SriLankaDistrict? district;

    if (suggestion.provinceId != null) {
      province = SriLankaData.provinceById(suggestion.provinceId!);
    }
    if (suggestion.districtId != null) {
      district = SriLankaData.districtById(suggestion.districtId!);
    }

    state = state.copyWith(
      currentLocation: location,
      selectedProvince: province,
      selectedDistrict: district,
      approximateAreaText: suggestion.display,
      clearSuggestions: true,
    );

    // Persist to recent searches
    await _repository.saveRecentSearch(
      LocationSuggestion(
        display: suggestion.display,
        provinceId: suggestion.provinceId,
        districtId: suggestion.districtId,
        provinceName: suggestion.provinceName,
        districtName: suggestion.districtName,
        latitude: suggestion.latitude,
        longitude: suggestion.longitude,
        source: 'recent',
      ),
    );

    final recents = await _repository.loadRecentSearches();
    state = state.copyWith(recentSearches: recents);
  }

  // ── Delivery Note ─────────────────────────────────────────────────────────

  void setDeliveryNote(String note) {
    final loc = state.currentLocation;
    if (loc != null) {
      state = state.copyWith(
        currentLocation: loc.copyWith(deliveryNote: note),
      );
    }
  }

  // ── Recent Searches ───────────────────────────────────────────────────────

  Future<void> clearRecentSearches() async {
    await _repository.clearRecentSearches();
    state = state.copyWith(recentSearches: const []);
  }

  // ── Error / Reset ─────────────────────────────────────────────────────────

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void clearLocation() {
    state = const LocationState();
    _init();
  }
}

// ── Providers ──────────────────────────────────────────────────────────────

/// The [SriLankaLocationService] provider (singleton).
final sriLankaLocationServiceProvider = Provider<SriLankaLocationService>((ref) {
  return SriLankaLocationService();
});

/// The [LocationRepository] provider (local implementation).
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  final service = ref.watch(sriLankaLocationServiceProvider);
  return LocalLocationRepository(locationService: service);
});

/// The main location [StateNotifierProvider].
///
/// Usage:
/// ```dart
/// // Read state
/// final locationState = ref.watch(locationProvider);
///
/// // Call actions
/// ref.read(locationProvider.notifier).fetchCurrentLocation();
/// ```
final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier(
    repository: ref.watch(locationRepositoryProvider),
    locationService: ref.watch(sriLankaLocationServiceProvider),
  );
});

/// Convenience provider: current [DeliveryLocation] (nullable).
final currentDeliveryLocationProvider = Provider<DeliveryLocation?>((ref) {
  return ref.watch(locationProvider).currentLocation;
});

/// Convenience provider: GPS loading state.
final isGpsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(locationProvider).isGpsLoading;
});

/// Convenience provider: geocoding failed flag.
final geocodingFailedProvider = Provider<bool>((ref) {
  return ref.watch(locationProvider).geocodingFailed;
});

/// Convenience provider: location error message.
final locationErrorProvider = Provider<String?>((ref) {
  return ref.watch(locationProvider).errorMessage;
});

/// Legacy alias kept for backward compatibility with existing screens
/// that imported [deliveryLocationProvider].
final deliveryLocationProvider = locationProvider;

