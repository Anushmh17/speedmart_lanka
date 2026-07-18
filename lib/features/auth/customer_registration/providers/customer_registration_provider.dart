import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speedmart_lanka/core/constants/app_constants.dart';
import 'package:speedmart_lanka/features/location/models/sri_lanka_district.dart';
import 'package:speedmart_lanka/features/location/models/sri_lanka_province.dart';
import '../models/customer_registration_data.dart';
import '../models/registration_step.dart';
import '../services/country_detection_service.dart';
import '../services/otp_service.dart';

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

  /// True when OTHER is selected but Sri Lanka was detected — show mismatch dialog.
  final bool pendingOverrideConfirmation;

  /// True if a saved [selectedCountry] preference was loaded from SharedPreferences.
  final bool hasSavedCountryPreference;

  /// True if the UI should force the user to pick a country because detection failed.
  final bool shouldShowCountryDialog;

  bool get hasError => error != null;
  bool get isLkUser => data.isLkUser;

  /// User chose OTHER while GPS/locale detected Sri Lanka.
  bool get hasCountryMismatch {
    final info = data.overrideInfo;
    return info.selectedCountry == 'OTHER' && info.detectedCountry == 'LK';
  }

  /// Blocks registration submit until user confirms international or switches to LK.
  bool get hasCountryMismatchBlockingSubmit =>
      hasCountryMismatch && !data.overrideInfo.isCountryOverride;

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
      hasSavedCountryPreference:
          hasSavedCountryPreference ?? this.hasSavedCountryPreference,
      shouldShowCountryDialog:
          shouldShowCountryDialog ?? this.shouldShowCountryDialog,
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

  // ── Country detection ────────────────────────────────────────────────────

  /// Loads saved [selectedCountry], always runs GPS/locale detection, then
  /// compares detected vs selected for mismatch warnings.
  Future<void> detectCountry() async {
    if (state.countryDetected) return;
    state = state.copyWith(isDetectingCountry: true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSelected = await _loadSavedSelectedCountry(prefs);

      debugPrint(
        '[CountryDetection] Saved selectedCountry: ${savedSelected ?? 'none'}',
      );

      // Always run GPS/locale — saved preference must not skip detection.
      final result = await _countryDetection.detect();
      final needsManualPick = !result.isConfident;

      final detectedCode = needsManualPick
          ? 'UNKNOWN'
          : (result.isLkUser ? 'LK' : (result.countryCode ?? 'OTHER'));

      debugPrint('[CountryDetection] detectedCountry: $detectedCode');
      debugPrint('[CountryDetection] Source: ${result.method.name}');
      debugPrint('[CountryDetection] Confident: ${result.isConfident}');

      // selectedCountry: saved UI preference, else default from detection.
      final String? selectedCode = savedSelected ??
          (needsManualPick ? null : (result.isLkUser ? 'LK' : 'OTHER'));

      if (selectedCode != null) {
        debugPrint('[CountryDetection] selectedCountry: $selectedCode');
      }

      final isLk = selectedCode == 'LK';
      final isMismatch = selectedCode == 'OTHER' && detectedCode == 'LK';

      state = state.copyWith(
        isDetectingCountry: false,
        countryDetected: true,
        isCountryAmbiguous: needsManualPick,
        hasSavedCountryPreference: savedSelected != null,
        shouldShowCountryDialog: needsManualPick && selectedCode == null,
        pendingOverrideConfirmation: isMismatch,
        data: state.data.copyWith(
          isLkUser: selectedCode != null ? isLk : false,
          country: isLk ? 'Sri Lanka' : '',
          overrideInfo: state.data.overrideInfo.copyWith(
            detectedCountry: detectedCode,
            detectionSource: result.method.name,
            selectedCountry: selectedCode,
            clearRiskFlag: isLk,
            isCountryOverride: false,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[CountryDetection] Exception during detection: $e');
      debugPrint('[CountryDetection] detectedCountry: UNKNOWN');

      state = state.copyWith(
        isDetectingCountry: false,
        countryDetected: true,
        isCountryAmbiguous: true,
        shouldShowCountryDialog: true,
        data: state.data.copyWith(
          isLkUser: false,
          country: '',
          overrideInfo: state.data.overrideInfo.copyWith(
            detectedCountry: 'UNKNOWN',
            detectionSource: 'error',
            selectedCountry: null,
          ),
        ),
      );
    }
  }

  Future<String?> _loadSavedSelectedCountry(SharedPreferences prefs) async {
    final selected = prefs.getString(AppConstants.selectedCountryKey);
    if (selected != null) return selected;

    final legacy = prefs.getString(AppConstants.legacyCountryPreferenceKey);
    if (legacy != null) {
      await prefs.setString(AppConstants.selectedCountryKey, legacy);
      return legacy;
    }
    return null;
  }

  Future<void> _saveSelectedCountry(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.selectedCountryKey, code);
    await prefs.remove(AppConstants.legacyCountryPreferenceKey);
  }

  // ── Manual Country Overrides ─────────────────────────────────────────────

  void setLkUser(bool isLk) {
    if (!isLk && state.data.overrideInfo.detectedCountry == 'LK') {
      state = state.copyWith(pendingOverrideConfirmation: true);
      return;
    }
    _applyLkChange(isLk);
  }

  void toggleCountry() {
    setLkUser(!state.data.isLkUser);
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

  /// Call before registration submit when OTHER + detected LK without override.
  void requestMismatchConfirmationBeforeSubmit() {
    if (state.hasCountryMismatchBlockingSubmit) {
      state = state.copyWith(pendingOverrideConfirmation: true);
    }
  }

  Future<void> _applyLkChange(bool isLk, {bool isOverride = false}) async {
    state = state.copyWith(
      isCountryAmbiguous: false,
      shouldShowCountryDialog: false,
      hasSavedCountryPreference: true,
      pendingOverrideConfirmation: false,
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

    await _saveSelectedCountry(isLk ? 'LK' : 'OTHER');
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
    _updateData(state.data.copyWith(
      province: p,
      clearDistrict: true,
    ));
  }

  void updateDistrict(SriLankaDistrict? d) =>
      _updateData(state.data.copyWith(district: d));

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
      final msg = e.toString();
      final isNetworkError = msg.contains('SocketException') ||
          msg.contains('NetworkException') ||
          msg.contains('TimeoutException') ||
          msg.contains('HandshakeException') ||
          msg.contains('Connection refused') ||
          msg.contains('Failed host lookup');
      state = state.copyWith(
        step: RegistrationStep.details,
        isLoading: false,
        error: isNetworkError
            ? 'No internet connection. Please check your network and try again.'
            : 'Failed to send OTP. Please try again.',
      );
    }
  }

  Future<bool> verifyOtp(String code) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final contact = state.data.primaryContact;
      final channel = state.data.isLkUser ? OtpChannel.phone : OtpChannel.email;
      final ok = await _otp.verifyOtp(
        channel: channel,
        destination: contact,
        code: code.trim(),
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
    } catch (e) {
      final msg = e.toString();
      final isNetworkError = msg.contains('SocketException') ||
          msg.contains('NetworkException') ||
          msg.contains('TimeoutException') ||
          msg.contains('HandshakeException') ||
          msg.contains('Connection refused') ||
          msg.contains('Failed host lookup');
      state = state.copyWith(
        isLoading: false,
        error: isNetworkError
            ? 'No internet connection. Please check your network and try again.'
            : 'Verification failed. Please try again.',
      );
      return false;
    }
  }

  void backToDetails() {
    state = state.copyWith(
      step: RegistrationStep.details,
      clearError: true,
    );
  }

  void reset() {
    state = const CustomerRegistrationState();
  }

  void _updateData(CustomerRegistrationData d) {
    state = state.copyWith(data: d, clearError: true);
  }
}

final countryDetectionServiceProvider = Provider<CountryDetectionService>(
  (_) => CountryDetectionService(),
);

final otpServiceProvider = Provider<OtpService>(
  (_) => MockOtpService(mockValidCode: '123456'),
);

final customerRegistrationProvider = StateNotifierProvider<
    CustomerRegistrationNotifier, CustomerRegistrationState>(
  (ref) => CustomerRegistrationNotifier(
    ref.watch(countryDetectionServiceProvider),
    ref.watch(otpServiceProvider),
  ),
);

