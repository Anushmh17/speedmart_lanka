import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speedmart_lanka/features/location/models/sri_lanka_district.dart';
import 'package:speedmart_lanka/features/location/models/sri_lanka_province.dart';
import '../models/customer_registration_data.dart';
import '../models/registration_step.dart';
import '../services/otp_service.dart';

// ── State ──────────────────────────────────────────────────────────────────

class CustomerRegistrationState {
  const CustomerRegistrationState({
    this.step = RegistrationStep.details,
    this.data = const CustomerRegistrationData(),
    this.isLogin = false,
    this.isLoading = false,
    this.error,
    this.maskedContact,
  });

  final RegistrationStep step;
  final CustomerRegistrationData data;
  final bool isLogin;
  final bool isLoading;
  final String? error;
  final String? maskedContact;

  bool get hasError => error != null;
  bool get isLkUser => data.isLkUser;

  CustomerRegistrationState copyWith({
    RegistrationStep? step,
    CustomerRegistrationData? data,
    bool? isLogin,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? maskedContact,
  }) {
    return CustomerRegistrationState(
      step: step ?? this.step,
      data: data ?? this.data,
      isLogin: isLogin ?? this.isLogin,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      maskedContact: maskedContact ?? this.maskedContact,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────

class CustomerRegistrationNotifier
    extends StateNotifier<CustomerRegistrationState> {
  CustomerRegistrationNotifier(this._otp)
      : super(const CustomerRegistrationState());

  final OtpService _otp;

  void setMode({required bool isLogin}) {
    state = state.copyWith(isLogin: isLogin);
  }

  void setLkUser(bool isLk) {
    _updateData(state.data.copyWith(
      isLkUser: isLk,
      country: isLk ? 'Sri Lanka' : '',
    ));
  }

  void toggleCountry() => setLkUser(!state.data.isLkUser);

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

final otpServiceProvider = Provider<OtpService>(
  (_) => MockOtpService(mockValidCode: '123456'),
);

final customerRegistrationProvider = StateNotifierProvider<
    CustomerRegistrationNotifier, CustomerRegistrationState>(
  (ref) => CustomerRegistrationNotifier(
    ref.watch(otpServiceProvider),
  ),
);
