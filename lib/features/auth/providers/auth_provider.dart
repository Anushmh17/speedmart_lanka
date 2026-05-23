import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/storage_service.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/models/user_role.dart';
import '../data/mock_auth_repository.dart';
import '../domain/auth_state.dart';

/// Riverpod [StateNotifier] that drives all authentication logic.
/// UI listens to [authProvider]; screens call methods on [authNotifier].
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState.initial()) {
    _bootstrap();
  }

  final _repo = MockAuthRepository.instance;

  Future<void> _bootstrap() async {
    try {
      await _repo.ensureInitialized();
      await _restoreSession();
    } catch (_) {
      await StorageService.clearSession();
      state = const AuthState.unauthenticated();
    }
  }

  // ── Restore saved session on app start ────────────────────────────────────
  Future<void> _restoreSession() async {
    final token = await StorageService.getToken();
    if (token == null) {
      state = const AuthState.unauthenticated();
      return;
    }

    final userJson = await StorageService.getUser();
    if (userJson != null) {
      final user = UserModel.fromJson(userJson);
      state = AuthState.authenticated(user);
      return;
    }

    final user = await _repo.restoreSession(token);
    if (user != null) {
      await StorageService.saveUser(user.toJson());
      state = AuthState.authenticated(user);
    } else {
      await StorageService.clearSession();
      state = const AuthState.unauthenticated();
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<void> login({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repo.login(
        email: email,
        password: password,
        role: role,
      );
      await StorageService.saveToken(result.token);
      await StorageService.saveUser(result.user.toJson());
      await StorageService.saveRole(result.user.role.name);
      state = AuthState.authenticated(result.user);
    } catch (e) {
      state = AuthState.withError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ── Customer OTP Login ─────────────────────────────────────────────────────
  Future<bool> checkCustomerExists(String contact) async {
    await _repo.ensureInitialized();
    return _repo.checkCustomerExists(contact);
  }

  Future<void> loginCustomerOtp({required String contact}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repo.loginCustomerOtp(contact);
      await StorageService.saveToken(result.token);
      await StorageService.saveUser(result.user.toJson());
      await StorageService.saveRole(result.user.role.name);
      state = AuthState.authenticated(result.user);
    } catch (e) {
      state = AuthState.withError(e.toString().replaceAll('Exception: ', ''));
      rethrow;
    }
  }

  // ── Register ───────────────────────────────────────────────────────────────
  Future<void> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
    String? businessName,
    List<String>? categories,
    String? detectedCountry,
    String? selectedCountry,
    bool? countryOverride,
    String? detectionSource,
    String? riskFlag,
    bool? verifiedPhone,
    bool? verifiedEmail,
    String? nic,
    String? deliveryCountry,
    String? deliveryProvince,
    String? deliveryDistrict,
    String? deliveryApproxArea,
    String? deliveryPreciseAddress,
    String? deliveryNote,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repo.register(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
        role: role,
        businessName: businessName,
        categories: categories,
        detectedCountry: detectedCountry,
        selectedCountry: selectedCountry,
        countryOverride: countryOverride,
        detectionSource: detectionSource,
        riskFlag: riskFlag,
        verifiedPhone: verifiedPhone,
        verifiedEmail: verifiedEmail,
        nic: nic,
        deliveryCountry: deliveryCountry,
        deliveryProvince: deliveryProvince,
        deliveryDistrict: deliveryDistrict,
        deliveryApproxArea: deliveryApproxArea,
        deliveryPreciseAddress: deliveryPreciseAddress,
        deliveryNote: deliveryNote,
      );
      await StorageService.saveToken(result.token);
      await StorageService.saveUser(result.user.toJson());
      await StorageService.saveRole(result.user.role.name);
      state = AuthState.authenticated(result.user);
    } catch (e) {
      state = AuthState.withError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _repo.logout();
    await StorageService.clearSession();
    state = const AuthState.unauthenticated();
  }

  // ── Update Profile ────────────────────────────────────────────────────────
  Future<void> updateProfile({
    required String fullName,
    required String phone,
    String? businessName,
    List<String>? vendorCategories,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final currentUser = state.user;
      if (currentUser == null) throw Exception('No authenticated user found.');

      final updatedUser = currentUser.copyWith(
        fullName: fullName,
        phone: phone,
        businessName: businessName,
        vendorCategories: vendorCategories,
      );

      // Update in repository
      final savedUser = await _repo.updateUser(updatedUser);

      // Update in local storage
      await StorageService.saveUser(savedUser.toJson());

      // Update state
      state = AuthState.authenticated(savedUser);
    } catch (e) {
      state = AuthState.withError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ── Phone Verification (for request submission gatekeeping) ────────────────
  /// Marks the current user's phone as verified and persists the update.
  /// Called after a successful phone OTP verification from the request flow.
  Future<void> markPhoneVerified({required String phone}) async {
    final currentUser = state.user;
    if (currentUser == null) return;

    final updatedUser = currentUser.copyWith(
      verifiedPhone: true,
      phone: phone,
    );

    // Update in repository
    final savedUser = await _repo.updateUser(updatedUser);

    // Persist to local storage
    await StorageService.saveUser(savedUser.toJson());

    // Update state
    state = AuthState.authenticated(savedUser);
  }

  // ── Clear error ────────────────────────────────────────────────────────────
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

/// Convenient shortcut to get current user (nullable)
final currentUserProvider = Provider<UserModel?>(
  (ref) => ref.watch(authProvider).user,
);

/// Convenient shortcut to check auth loading state
final authLoadingProvider = Provider<bool>(
  (ref) => ref.watch(authProvider).isLoading,
);
