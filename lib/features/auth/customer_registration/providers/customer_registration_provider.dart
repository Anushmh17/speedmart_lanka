import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer_registration_data.dart';
import '../models/registration_step.dart';
import '../models/country_override_info.dart';
import '../services/country_detection_service.dart';
import '../services/otp_service.dart';
import 'package:speedmart_lanka/features/location/models/sri_lanka_district.dart';
import 'package:speedmart_lanka/features/location/models/sri_lanka_province.dart';

// ── State ──────────────────────────────────────────────────────────────────

class CustomerRegistrationState {
  const CustomerRegistrationState({
    this.step = RegistrationStep.details,
    this.data = const CustomerRegistrationData(),
    this.isDetectingCountry = false,
    this.countryDetected = false,
    this.isCountryAmbiguous = false,
    this.isLogin = false,
    this.isLoading = false,
    this.error,
    this.maskedContact,
    this.pendingOverrideConfirmation = false,
    this.hasSavedCountryPreference = false,
    this.shouldShowCountryDialog = false,
  });

  final RegistrationStep step;
  final CustomerRegistrationData data;

  /// True while the initial country detection is running.
  final bool isDetectingCountry;

  /// True once country detection has completed (success or fallback).
  final bool countryDetected;

  /// (Legacy) True if country detection could not confidently determine country.
  final bool isCountryAmbiguous;

  /// True if we are in the login flow instead of registration.
  final bool isLogin;

  /// True while OTP is being sent or verified.
  final bool isLoading;

  /// Non-null when an actionable error should be shown to the user.
  final String? error;

  /// Masked phone/email shown on the OTP screen ("OTP sent to ****1234").
  final String? maskedContact;

  /// True if the user selected non-LK but was detected as LK, needing confirmation.
  final bool pendingOverrideConfirmation;

  /// True if a user preference was found and loaded from SharedPreferences.
  final bool hasSavedCountryPreference;

  /// True if the UI should force the user to pick a country because all detection failed.
  final bool shouldShowCountryDialog;

  bool get hasError => error != null;
  bool get isLkUser => data.isLkUser;

  CustomerRegistrationState copyWith({
    RegistrationStep? step,
    CustomerRegistrationData? data,
    bool? isDetectingCountry,
    bool? countryDetected,
    bool? isCountryAmbiguous,
    bool? isLogin,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? maskedContact,
    bool? pendingOverrideConfirmation,
    bool? hasSavedCountryPreference,
    bool? shouldShowCountryDialog,
  }) {
    return CustomerRegistrationState(
      step: step ?? this.step,
      data: data ?? this.data,
      isDetectingCountry: isDetectingCountry ?? this.isDetectingCountry,
      countryDetected: countryDetected ?? this.countryDetected,
      isCountryAmbiguous: isCountryAmbiguous ?? this.isCountryAmbiguous,
      isLogin: isLogin ?? this.isLogin,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      maskedContact: maskedContact ?? this.maskedContact,
      pendingOverrideConfirmation:
          pendingOverrideConfirmation ?? this.pendingOverrideConfirmation,
      hasSavedCountryPreference: hasSavedCountryPreference ?? this.hasSavedCountryPreference,
      shouldShowCountryDialog: shouldShowCountryDialog ?? this.shouldShowCountryDialog,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────

class CustomerRegistrationNotifier
    extends StateNotifier<CustomerRegistrationState> {
  CustomerRegistrationNotifier(this._countryDetection, this._otp)
      : super(const CustomerRegistrationState());

  final CountryDetectionService _countryDetection;
  final OtpService _otp;
  static const _prefKey = 'speedmart_country_preference';

  // ── Country detection ────────────────────────────────────────────────────

  /// Should be called once when the registration/login screen mounts.
  Future<void> detectCountry() async {
    if (state.countryDetected) return; // idempotent
    state = state.copyWith(isDetectingCountry: true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCountry = prefs.getString(_prefKey);

      if (savedCountry != null) {
        debugPrint('[CountryDetection] Saved preference: $savedCountry');
        debugPrint('[CountryDetection] Final country: $savedCountry');
        debugPrint('[CountryDetection] Source: saved');
        debugPrint('[CountryDetection] Confident: true');

        final isLk = savedCountry == 'LK';
        state = state.copyWith(
          isDetectingCountry: false,
          countryDetected: true,
          isCountryAmbiguous: false,
          hasSavedCountryPreference: true,
          shouldShowCountryDialog: false,
          data: state.data.copyWith(
            isLkUser: isLk,
            country: isLk ? 'Sri Lanka' : '',
            overrideInfo: state.data.overrideInfo.copyWith(
              detectedCountry: savedCountry,
              detectionSource: DetectionMethod.preference.name,
              selectedCountry: savedCountry,
            ),
          ),
        );
        return;
      }

      debugPrint('[CountryDetection] Saved preference: none');

      final result = await _countryDetection.detect();

      // Development mode fallback
      bool finalIsLk = result.isLkUser;
      bool showDialog = !result.isConfident;

      if (kDebugMode && !result.isConfident) {
        finalIsLk = true; // Default to LK in dev mode
        showDialog = false; // Do not show popup
        debugPrint('[CountryDetection] Debug mode fallback applied');
        debugPrint('[CountryDetection] Final country: LK');
        debugPrint('[CountryDetection] Source: debug');
        debugPrint('[CountryDetection] Confident: true (forced)');
      }

      final detectedCode = finalIsLk ? 'LK' : result.countryCode;

      state = state.copyWith(
        isDetectingCountry: false,
        countryDetected: true,
        isCountryAmbiguous: !result.isConfident,
        hasSavedCountryPreference: false,
        shouldShowCountryDialog: showDialog,
        data: state.data.copyWith(
          isLkUser: finalIsLk,
          country: finalIsLk ? 'Sri Lanka' : '',
          overrideInfo: state.data.overrideInfo.copyWith(
            detectedCountry: detectedCode,
            detectionSource: result.method.name,
            selectedCountry: finalIsLk ? 'LK' : 'OTHER',
          ),
        ),
      );
    } catch (e) {
      // Complete failure fallback
      debugPrint('[CountryDetection] Exception during detection: $e');
      debugPrint('[CountryDetection] Final country: LK');
      debugPrint('[CountryDetection] Source: fallback');
      debugPrint('[CountryDetection] Confident: false');

      state = state.copyWith(
        isDetectingCountry: false,
        countryDetected: true,
        isCountryAmbiguous: true,
        shouldShowCountryDialog: !kDebugMode,
        data: state.data.copyWith(
          isLkUser: true,
          country: 'Sri Lanka',
          overrideInfo: state.data.overrideInfo.copyWith(
            detectedCountry: 'LK',
            detectionSource: 'fallback',
            selectedCountry: 'LK',
          ),
        ),
      );
    }
  }

  // ── Manual Country Overrides ─────────────────────────────────────────────

  void setLkUser(bool isLk) {
    // If selecting "Other" and detected country is Sri Lanka, trigger override dialog
    if (!isLk && state.data.overrideInfo.detectedCountry == 'LK' && !state.hasSavedCountryPreference) {
      state = state.copyWith(pendingOverrideConfirmation: true);
      return;
    }
    _applyLkChange(isLk);
  }

  void toggleCountry() {
    final nextIsLk = !state.data.isLkUser;
    setLkUser(nextIsLk);
  }

  void confirmCountryOverride() {
    state = state.copyWith(pendingOverrideConfirmation: false);
    _applyLkChange(false, isOverride: true);
  }

  void cancelCountryOverride() {
    state = state.copyWith(pendingOverrideConfirmation: false);
    _applyLkChange(true);
  }

  void dismissOverrideConfirmation() {
    state = state.copyWith(pendingOverrideConfirmation: false);
  }

  Future<void> _applyLkChange(bool isLk, {bool isOverride = false}) async {
    state = state.copyWith(
      isCountryAmbiguous: false,
      shouldShowCountryDialog: false, // dismiss dialog
      hasSavedCountryPreference: true,
      data: state.data.copyWith(
        isLkUser: isLk,
        country: isLk ? 'Sri Lanka' : '',
        overrideInfo: state.data.overrideInfo.copyWith(
          selectedCountry: isLk ? 'LK' : 'OTHER',
          isCountryOverride: isOverride,
          riskFlag: isOverride ? 'country_mismatch' : null,
          clearRiskFlag: !isOverride,
        ),
      ),
    );
    
    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, isLk ? 'LK' : 'OTHER');
  }

  void setMode({required bool isLogin}) {
    state = state.copyWith(isLogin: isLogin);
  }

  // ── Field updates ────────────────────────────────────────────────────────

  void updateFullName(String v) =>
      _updateData(state.data.copyWith(fullName: v));
  void updateNic(String v) => _updateData(state.data.copyWith(nic: v));
  void updatePhone(String v) => _updateData(state.data.copyWith(phone: v));
  void updateEmail(String v) => _updateData(state.data.copyWith(email: v));
  void updateCountry(String v) => _updateData(state.data.copyWith(country: v));
  void updateApproxArea(String v) =>
      _updateData(state.data.copyWith(approxArea: v));
  void updatePreciseAddress(String v) =>
      _updateData(state.data.copyWith(preciseAddress: v));
  void updateDeliveryNote(String v) =>
      _updateData(state.data.copyWith(deliveryNote: v));

  void updateProvince(SriLankaProvince? p) {
    // Changing province clears the district selection.
    _updateData(state.data.copyWith(
      province: p,
      clearDistrict: true,
    ));
  }

  void updateDistrict(SriLankaDistrict? d) =>
      _updateData(state.data.copyWith(district: d));

  /// Called when GPS auto-detect fills province + district automatically.
  void applyGpsLocation({
    required SriLankaProvince province,
    required SriLankaDistrict district,
    required String approxArea,
  }) {
    _updateData(state.data.copyWith(
      province: province,
      district: district,
      approxArea: approxArea,
    ));
  }

  void clearError() => state = state.copyWith(clearError: true);

  // ── OTP flow ─────────────────────────────────────────────────────────────

  /// Sends OTP to the primary contact. On success advances to [RegistrationStep.verifyOtp].
  Future<void> sendOtp() async {
    state = state.copyWith(
      step: RegistrationStep.sendingOtp,
      isLoading: true,
      clearError: true,
    );
    try {
      final contact = state.data.primaryContact;
      final channel = state.data.isLkUser ? OtpChannel.phone : OtpChannel.email;
      final result = await _otp.sendOtp(
        channel: channel,
        destination: contact,
      );
      if (result.success) {
        state = state.copyWith(
          step: RegistrationStep.verifyOtp,
          isLoading: false,
          maskedContact: result.maskedContact,
        );
      } else {
        state = state.copyWith(
          step: RegistrationStep.details,
          isLoading: false,
          error: result.message ?? 'Failed to send OTP. Please try again.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        step: RegistrationStep.details,
        isLoading: false,
        error: 'Could not send OTP. Check your connection and try again.',
      );
    }
  }

  /// Verifies [code] against the sent OTP. On success advances to [RegistrationStep.success].
  Future<bool> verifyOtp(String code) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final contact = state.data.primaryContact;
      final channel = state.data.isLkUser ? OtpChannel.phone : OtpChannel.email;
      final ok = await _otp.verifyOtp(
        channel: channel,
        destination: contact,
        code: code,
      );
      if (ok) {
        state = state.copyWith(
          step: RegistrationStep.success,
          isLoading: false,
          data: state.data.copyWith(
            overrideInfo: state.data.overrideInfo.copyWith(
              verifiedPhone: state.data.isLkUser,
              verifiedEmail: !state.data.isLkUser,
            ),
          ),
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Incorrect OTP code. Please try again.',
        );
        return false;
      }
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Verification failed. Please try again.',
      );
      return false;
    }
  }

  /// Returns to the details step (called from OTP screen "← Change details").
  void backToDetails() {
    state = state.copyWith(
      step: RegistrationStep.details,
      clearError: true,
    );
  }

  /// Resets the entire registration flow (e.g. user logs out mid-flow).
  void reset() {
    state = const CustomerRegistrationState();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _updateData(CustomerRegistrationData d) {
    state = state.copyWith(data: d, clearError: true);
  }
}

// ── Providers ──────────────────────────────────────────────────────────────

/// Service providers — swap these to inject real implementations.
final countryDetectionServiceProvider = Provider<CountryDetectionService>(
  (_) => CountryDetectionService(),
);

final otpServiceProvider = Provider<OtpService>(
  (_) => MockOtpService(mockValidCode: '123456'),
);

/// Main registration state provider.
final customerRegistrationProvider = StateNotifierProvider<
    CustomerRegistrationNotifier, CustomerRegistrationState>(
  (ref) => CustomerRegistrationNotifier(
    ref.watch(countryDetectionServiceProvider),
    ref.watch(otpServiceProvider),
  ),
);
