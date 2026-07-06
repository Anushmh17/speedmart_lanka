import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/storage_service.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/models/user_role.dart';
import '../data/mock_auth_repository.dart';
import '../domain/auth_state.dart';
import '../../admin/providers/category_provider.dart';

/// Riverpod [StateNotifier] that drives all authentication logic.
/// UI listens to [authProvider]; screens call methods on [authNotifier].
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState.initial()) {
    _bootstrap();
  }

  final Ref _ref;
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
      debugPrint('[CategoryAudit] ===== VENDOR LOGIN RESTORE =====');
      debugPrint('[CategoryAudit] Restoring session from storage');
      debugPrint('[CategoryAudit] userJson allowed_categories (BEFORE): ${userJson['allowed_categories']}');
      debugPrint('[CategoryAudit] userJson vendor_categories (BEFORE): ${userJson['vendor_categories']}');
      debugPrint('[CategoryAudit] userJson requested_categories (BEFORE): ${userJson['requested_categories']}');
      
      final user = UserModel.fromJson(userJson);
      
      debugPrint('[CategoryAudit] UserModel.fromJson result (BEFORE cleanup):');
      debugPrint('[CategoryAudit] user.allowedCategories: ${user.allowedCategories}');
      debugPrint('[CategoryAudit] user.vendorCategories: ${user.vendorCategories}');
      debugPrint('[CategoryAudit] user.requestedCategories: ${user.requestedCategories}');
      
      // Clean stale category keys automatically on session restore
      final cleanedUser = await _cleanUserCategoriesOnLogin(user);
      
      debugPrint('[CategoryAudit] After automatic cleanup (AFTER):');
      debugPrint('[CategoryAudit] cleanedUser.allowedCategories: ${cleanedUser.allowedCategories}');
      debugPrint('[CategoryAudit] cleanedUser.vendorCategories: ${cleanedUser.vendorCategories}');
      debugPrint('[CategoryAudit] cleanedUser.requestedCategories: ${cleanedUser.requestedCategories}');
      debugPrint('[CategoryAudit] ===== SESSION RESTORED WITH CLEAN CATEGORIES =====');
      
      state = AuthState.authenticated(cleanedUser);
      return;
    }

    final user = await _repo.restoreSession(token);
    if (user != null) {
      final cleanedUser = await _cleanUserCategoriesOnLogin(user);
      await StorageService.saveUser(cleanedUser.toJson());
      state = AuthState.authenticated(cleanedUser);
    } else {
      await StorageService.clearSession();
      state = const AuthState.unauthenticated();
    }
  }

  // ── Vendor Credential Check (without authenticating) ──────────────────────
  /// Verifies vendor email+password without setting auth state.
  /// Router won't redirect because isAuthenticated stays false.
  /// Call [login] after OTP is verified to complete authentication.
  Future<UserModel?> verifyVendorCredentials({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.verifyVendorCredentials(email: email, password: password);
      state = state.copyWith(isLoading: false);
      return user;
    } catch (e) {
      state = AuthState.withError(e.toString().replaceAll('Exception: ', ''));
      return null;
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
      
      debugPrint('[CategorySync] ===== POST-LOGIN CATEGORY CLEANUP =====');
      debugPrint('[CategorySync] Login successful for: ${result.user.email}');
      debugPrint('[CategorySync] BEFORE cleanup: allowedCategories=${result.user.allowedCategories}');
      
      // Clean stale category keys automatically on login
      final cleanedUser = await _cleanUserCategoriesOnLogin(result.user);
      
      debugPrint('[CategorySync] AFTER cleanup: allowedCategories=${cleanedUser.allowedCategories}');
      debugPrint('[CategorySync] ===== CATEGORY CLEANUP COMPLETE =====');
      
      await StorageService.saveToken(result.token);
      await StorageService.saveUser(cleanedUser.toJson());
      await StorageService.saveRole(cleanedUser.role.name);
      state = AuthState.authenticated(cleanedUser);
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
      // Do not rethrow — error is captured in AuthState; callers must not
      // handle provider exceptions directly to avoid unhandled Future errors.
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
    String? shopLocationSource,
    String? businessRegistrationNumber,
  }) async {
    debugPrint('[Auth] Register submit started: email=$email, role=$role');
    debugPrint('[VendorLocationAudit] Registration coordinates: lat=$shopLatitude, lng=$shopLongitude');
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
        shopLocationSource: shopLocationSource,
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
    List<String>? requestedCategories,
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
        requestedCategories: requestedCategories,
        hasPendingCategoryRequest: requestedCategories?.isNotEmpty == true,
      );

      debugPrint('[AuthSessionFix] Current logged in user: ${currentUser.id}');
      debugPrint('[AuthSessionFix] Edited user: ${updatedUser.id}');
      debugPrint('[AuthSessionFix] Same user: ${currentUser.id == updatedUser.id}');

      // Update in repository
      final savedUser = await _repo.updateUser(updatedUser);

      // Only update session if updating current logged-in user
      if (currentUser.id == updatedUser.id) {
        debugPrint('[AuthSessionFix] Updating current user session because edited user is current user');
        await StorageService.saveUser(savedUser.toJson());
        state = AuthState.authenticated(savedUser);
      } else {
        debugPrint('[AuthSessionFix] Preserving current session after profile update');
        await StorageService.saveUser(currentUser.toJson());
      }
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
    List<String>? requestedCategories,
    bool? hasPendingCategoryRequest,
  }) async {
    debugPrint('[CategoryFix] ===== AUTH PROVIDER UPDATE START =====');
    debugPrint('[CategoryFix] vendorId=$vendorId');
    debugPrint('[CategoryFix] allowedCategories input: $allowedCategories');
    debugPrint('[CategoryFix] requestedCategories input: $requestedCategories');
    debugPrint('[CategoryFix] hasPendingCategoryRequest input: $hasPendingCategoryRequest');

    // Get the vendor from repository
    final vendor = await _repo.getUserById(vendorId);
    if (vendor == null) throw Exception('Vendor not found');

    debugPrint('[CategoryFix] Before update: vendor.allowedCategories=${vendor.allowedCategories}');
    debugPrint('[CategoryFix] Before update: vendor.requestedCategories=${vendor.requestedCategories}');

    final updatedVendor = vendor.copyWith(
      shopName: shopName,
      shopAddress: shopAddress,
      shopLatitude: shopLatitude,
      shopLongitude: shopLongitude,
      assignedRadiusKm: assignedRadiusKm,
      vendorApproved: vendorApproved,
      allowedCategories: allowedCategories,
      requestedCategories: requestedCategories ?? [],
      hasPendingCategoryRequest: hasPendingCategoryRequest ?? false,
      isShopLocationAssigned: true,
    );

    debugPrint('[CategoryFix] After update: updatedVendor.allowedCategories=${updatedVendor.allowedCategories}');
    debugPrint('[CategoryFix] After update: updatedVendor.requestedCategories=${updatedVendor.requestedCategories}');
    debugPrint('[CategoryFix] After update: updatedVendor.hasPendingCategoryRequest=${updatedVendor.hasPendingCategoryRequest}');

    // Update in repository
    await _repo.updateUser(updatedVendor);

    debugPrint('[CategoryFix] Updated vendor in repository');

    // Get current logged-in user
    final currentUser = state.user;
    debugPrint('[AuthSessionFix] Current logged in user: ${currentUser?.id}');
    debugPrint('[AuthSessionFix] Edited vendor user: ${updatedVendor.id}');
    debugPrint('[AuthSessionFix] Same user: ${currentUser?.id == updatedVendor.id}');

    // Only update storage and state if editing current logged-in user
    if (currentUser != null && currentUser.id == updatedVendor.id) {
      debugPrint('[AuthSessionFix] Updating current user session because edited user is current user');
      final userJson = updatedVendor.toJson();
      debugPrint('[CategoryFix] User JSON allowed_categories=${userJson['allowed_categories']}');
      debugPrint('[CategoryFix] User JSON requested_categories=${userJson['requested_categories']}');
      await StorageService.saveUser(userJson);
      state = AuthState.authenticated(updatedVendor);
    } else {
      debugPrint('[AuthSessionFix] Preserving admin session after vendor update');
      // Admin editing another vendor - keep current session
      if (currentUser != null) {
        await StorageService.saveUser(currentUser.toJson());
      }
    }

    debugPrint('[CategoryFix] ===== PERSISTED TO STORAGE =====');
    debugPrint('[CategoryFix] Persisted allowedCategories: ${updatedVendor.allowedCategories}');
    debugPrint('[CategoryFix] Persisted requestedCategories: ${updatedVendor.requestedCategories}');
  }

  // ── Category Cleanup Helper ────────────────────────────────────────────────
  /// Automatically cleans stale category keys from user during login/restore
  /// Removes invalid keys from allowedCategories, vendorCategories, requestedCategories
  Future<UserModel> _cleanUserCategoriesOnLogin(UserModel user) async {
    // Only clean categories for vendor users
    if (user.role != UserRole.vendor) {
      return user;
    }
    
    try {
      // FORCE load categories before cleanup validation
      final categoryNotifier = _ref.read(categoryProvider.notifier);
      await categoryNotifier.loadCategories();
      final allCategories = categoryNotifier.getAllCategories();
      final validKeys = allCategories.map((c) => c.normalizedKey).toSet();
      
      debugPrint('[CategoryCleanup] Valid keys in repository: $validKeys');
      
      // If no categories loaded, DO NOT cleanup - return user unchanged
      if (validKeys.isEmpty) {
        debugPrint('[CategoryCleanup] WARNING: Category repository empty, skipping cleanup');
        return user;
      }
      
      // Clean each category list
      final cleanedAllowed = _cleanCategoryList(
        user.allowedCategories,
        validKeys,
        'allowedCategories',
        user.id,
      );
      final cleanedVendor = _cleanCategoryList(
        user.vendorCategories,
        validKeys,
        'vendorCategories',
        user.id,
      );
      final cleanedRequested = _cleanCategoryList(
        user.requestedCategories,
        validKeys,
        'requestedCategories',
        user.id,
      );
      
      // Check if anything changed
      if (cleanedAllowed != user.allowedCategories ||
          cleanedVendor != user.vendorCategories ||
          cleanedRequested != user.requestedCategories) {
        debugPrint('[CategoryCleanup] Categories cleaned for user ${user.id} during login');
        debugPrint('[CategoryCleanup] user.allowedCategories being saved: $cleanedAllowed');
        
        final cleanedUser = user.copyWith(
          allowedCategories: cleanedAllowed ?? [],
          vendorCategories: cleanedVendor ?? [],
          requestedCategories: cleanedRequested ?? [],
          hasPendingCategoryRequest: (cleanedRequested?.isNotEmpty ?? false),
        );
        
        // Persist cleaned user back to repository
        await _repo.updateUser(cleanedUser);
        return cleanedUser;
      }
      
      return user;
    } catch (e) {
      debugPrint('[CategoryCleanup] Error during login cleanup: $e');
      return user; // Return original user on error
    }
  }
  
  /// Helper: Clean a category list by removing invalid keys
  List<String>? _cleanCategoryList(
    List<String>? original,
    Set<String> validKeys,
    String fieldName,
    String userId,
  ) {
    if (original == null || original.isEmpty) return null;
    
    debugPrint('[CategoryCleanup] $fieldName BEFORE cleanup: $original');
    
    // Normalize and filter
    final cleaned = original
        .map((k) => k.toLowerCase().trim())
        .where((k) => k.isNotEmpty && validKeys.contains(k))
        .toSet()
        .toList();
    
    debugPrint('[CategoryCleanup] $fieldName AFTER cleanup: $cleaned');
    
    final removed = original.length - cleaned.length;
    if (removed > 0) {
      debugPrint('[CategoryCleanup] Removed $removed invalid keys from $fieldName for user $userId');
    }
    
    return cleaned.isEmpty ? null : cleaned;
  }

  // ── Password Reset ──────────────────────────────────────────────────────

  /// Returns the current stored password for a vendor email (for same-password check).
  Future<String?> getVendorPassword(String email) async {
    return _repo.getVendorPassword(email);
  }

  /// Returns a mock OTP string if the email belongs to a vendor.
  Future<String> generateResetOtp(String email) async {
    return _repo.generateResetOtp(email);
  }

  /// Replaces the stored password for [email] with [newPassword].
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.resetPassword(email: email, newPassword: newPassword);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = AuthState.withError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ── Clear error ────────────────────────────────────────────────────────────
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // ── Get user by ID (for admin operations) ──────────────────────────────────
  Future<UserModel?> getUserById(String userId) async {
    return await _repo.getUserById(userId);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);

/// Convenient shortcut to get current user (nullable)
final currentUserProvider = Provider<UserModel?>(
  (ref) => ref.watch(authProvider).user,
);

/// Convenient shortcut to check auth loading state
final authLoadingProvider = Provider<bool>(
  (ref) => ref.watch(authProvider).isLoading,
);
