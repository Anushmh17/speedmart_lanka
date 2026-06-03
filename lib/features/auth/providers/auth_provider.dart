import 'package:flutter/foundation.dart';
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
    // Vendor shop details
    String? shopName,
    String? shopAddress,
    String? shopProvince,
    String? shopDistrict,
    String? shopArea,
    double? shopLatitude,
    double? shopLongitude,
    double? shopLocationAccuracyMeters,
    DateTime? shopLocationDetectedAt,
    String? businessRegistrationNumber,
  }) async {
    debugPrint('[Auth] Register submit started: email=$email, role=$role');
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
        shopName: shopName,
        shopAddress: shopAddress,
        shopProvince: shopProvince,
        shopDistrict: shopDistrict,
        shopArea: shopArea,
        shopLatitude: shopLatitude,
        shopLongitude: shopLongitude,
        shopLocationAccuracyMeters: shopLocationAccuracyMeters,
        shopLocationDetectedAt: shopLocationDetectedAt,
        businessRegistrationNumber: businessRegistrationNumber,
      );
      debugPrint('[Auth] Register result role: ${result.user.role.name}, email: ${result.user.email}');
      await StorageService.saveToken(result.token);
      debugPrint('[Auth] Storage: token saved');
      await StorageService.saveUser(result.user.toJson());
      debugPrint('[Auth] Storage: user saved');
      await StorageService.saveRole(result.user.role.name);
      debugPrint('[Auth] Storage: role saved');
      state = AuthState.authenticated(result.user);
      debugPrint('[Auth] Register success: authenticated user ${result.user.email}');
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      debugPrint('[Auth] Register error caught: $errorMsg');
      state = AuthState.withError(errorMsg);
      debugPrint('[Auth] Error state set, hasError=${state.hasError}, error=${state.error}');
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

  // ── Admin: Vendor Shop Assignment ──────────────────────────────────────────
  /// Admin assigns shop location and details to a vendor.
  Future<void> updateVendorShopAssignment({
    required String vendorId,
    required String shopName,
    required String shopAddress,
    required double shopLatitude,
    required double shopLongitude,
    required double assignedRadiusKm,
    required bool vendorApproved,
    required List<String> allowedCategories,
  }) async {
    debugPrint('[Auth] Updating vendor shop assignment: vendorId=$vendorId');
    debugPrint('[Auth] Admin-approved categories: $allowedCategories');

    // Get the vendor from repository
    final vendor = await _repo.getUserById(vendorId);
    if (vendor == null) throw Exception('Vendor not found');

    final updatedVendor = vendor.copyWith(
      shopName: shopName,
      shopAddress: shopAddress,
      shopLatitude: shopLatitude,
      shopLongitude: shopLongitude,
      assignedRadiusKm: assignedRadiusKm,
      vendorApproved: vendorApproved,
      allowedCategories: allowedCategories,
      isShopLocationAssigned: true,
    );

    debugPrint('[Auth] Updated vendor allowedCategories in memory: ${updatedVendor.allowedCategories}');

    // Update in repository
    await _repo.updateUser(updatedVendor);

    debugPrint('[Auth] Updated vendor in repository');

    // Persist to local storage
    await StorageService.saveUser(updatedVendor.toJson());

    debugPrint('[Auth] Persisted vendor to storage with allowedCategories: ${updatedVendor.allowedCategories}');

    // If updating current user, update state
    if (state.user?.id == vendorId) {
      state = AuthState.authenticated(updatedVendor);
      debugPrint('[Auth] Updated current user state with new allowedCategories');
    }
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
