import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/storage/storage_service.dart';
import '../../../features/notifications/data/notification_repository.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/models/user_role.dart';
import '../data/auth_repository.dart';
import '../domain/auth_state.dart';

/// Riverpod [StateNotifier] that drives all authentication logic.
/// UI listens to [authProvider]; screens call methods on [authNotifier].
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState.initial()) {
    _bootstrap();
  }

  final _repo = AuthRepository.instance;
  
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;

  Future<void> _setupSessionListener(UserModel user) async {
    _userSubscription?.cancel();
    final localSessionId = await StorageService.getSessionId();
    if (localSessionId == null) return;
    
    _userSubscription = _repo.userStream(user.id, user.role).listen(
      (snapshot) {
        if (!snapshot.exists) {
          unawaited(logout());
          return;
        }
        final latestUser =
            UserModel.fromJson({...snapshot.data()!, 'id': snapshot.id});
        if (latestUser.activeSessions != null &&
            !latestUser.activeSessions!.contains(localSessionId)) {
          debugPrint(
              '[Auth] Session $localSessionId is no longer active. Forcing logout.');
          unawaited(logout());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        // A stream may emit an error while logout is cancelling it. Retain the
        // current session; only an explicit profile/session update can log out.
        debugPrint('[Auth] Session listener error: $error');
      },
    );
  }

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

    // Extract userId from token to validate against stored user JSON
    String? tokenUserId;
    try {
      final parts = token.split('_');
      if (parts.length >= 3) {
        tokenUserId = parts.sublist(2, parts.length - 1).join('_');
      }
    } catch (_) {}

    // If Firebase Auth is signed in, ensure the stored user ID matches the Firebase UID.
    // This migrates users who registered before the Firebase UID fix.
    final firebaseUid = AuthRepository.instance.currentFirebaseUid;
    
    final userJson = await StorageService.getUser();
    if (userJson != null) {
      final savedRole = userJson['role'] as String?;
      final shouldRestore = switch (savedRole) {
        'customer' => await StorageService.getCustomerRememberMe(),
        'vendor' => await StorageService.getVendorRememberMe(),
        _ => true,
      };
      if (!shouldRestore) {
        await StorageService.clearSession();
        state = const AuthState.unauthenticated();
        return;
      }
    }

    // For vendors/admins signed in with Firebase Auth, ensure stored ID matches Firebase UID.
    if (userJson != null && firebaseUid != null &&
        userJson['id'] != firebaseUid &&
        userJson['role'] != 'customer') {
      final oldId = userJson['id'] as String?;
      userJson['id'] = firebaseUid;
      await StorageService.saveUser(userJson);
      if (oldId != null && oldId != firebaseUid) {
        try {
          final role = UserRole.values.firstWhere(
            (r) => r.name == (userJson['role'] as String? ?? ''),
            orElse: () => UserRole.customer,
          );
          await AuthRepository.instance.deleteStaleDoc(role: role, docId: oldId);
        } catch (_) {}
      }
    }
    // Strip stale local image paths before restoring session — they cause
    // PathNotFoundException in FileImage when the cache file no longer exists.
    if (userJson != null) {
      final imgUrl = userJson['profile_image_url'] as String?;
      if (imgUrl != null &&
          (imgUrl.startsWith('/') || imgUrl.contains(':\\') || imgUrl.contains(':/')) &&
          !File(imgUrl).existsSync()) {
        userJson['profile_image_url'] = null;
        await StorageService.saveUser(userJson);
      }
    }

    if (userJson != null && (tokenUserId == null || userJson['id'] == tokenUserId || firebaseUid == tokenUserId)) {
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
      
      debugPrint('[CategoryAudit] ===== SESSION RESTORED WITH CLEAN CATEGORIES =====');
      
      NotificationRepository.instance.resetForNewSession();
      // Re-subscribe vendor to FCM topics on session restore
      if (cleanedUser.role == UserRole.vendor) {
        FcmService.subscribeVendorToTopics(shopDistrict: cleanedUser.shopDistrict);
      }
      state = AuthState.authenticated(cleanedUser);
      _setupSessionListener(cleanedUser);
      return;
    }

    final user = await _repo.restoreSession(token);
    if (user != null) {
      final cleanedUser = await _cleanUserCategoriesOnLogin(user);
      await StorageService.saveUser(cleanedUser.toJson());
      NotificationRepository.instance.resetForNewSession();
      state = AuthState.authenticated(cleanedUser);
      _setupSessionListener(cleanedUser);
    } else {
      await StorageService.clearSession();
      state = const AuthState.unauthenticated();
    }
  }

  // ── Vendor Credential Check (without authenticating) ──────────────────────
  /// Verifies vendor email+password without setting auth state.
  /// Router won't redirect because isAuthenticated stays false.
  /// Call [login] after OTP is verified to complete authentication.
  Future<({UserModel user, String phone})?> verifyVendorCredentials({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repo.verifyVendorCredentials(email: email, password: password);
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = AuthState.withError(e.toString().replaceAll('Exception: ', ''));
      return null;
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  /// Completes vendor login after phone OTP verification. Phone Auth signs in
  /// with a phone-based Firebase user, so restore the email account that owns
  /// the vendor Firestore profile before creating the application session.
  Future<void> loginVendorAfterOtp({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repo.loginVendorAfterOtp(
        email: email,
        password: password,
      );
      final cleanedUser = await _cleanUserCategoriesOnLogin(result.user);
      await StorageService.saveToken(result.token);
      await StorageService.saveUser(cleanedUser.toJson());
      await StorageService.saveRole(cleanedUser.role.name);
      NotificationRepository.instance.resetForNewSession();
      // Subscribe vendor to district-based request notification topics
      if (cleanedUser.role == UserRole.vendor) {
        FcmService.subscribeVendorToTopics(shopDistrict: cleanedUser.shopDistrict);
      }
      state = AuthState.authenticated(cleanedUser);
      _setupSessionListener(cleanedUser);
    } catch (e) {
      state = AuthState.withError(e.toString().replaceAll('Exception: ', ''));
    }
  }

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
      NotificationRepository.instance.resetForNewSession();
      // Subscribe vendor to district-based request notification topics
      if (cleanedUser.role == UserRole.vendor) {
        FcmService.subscribeVendorToTopics(shopDistrict: cleanedUser.shopDistrict);
      }
      state = AuthState.authenticated(cleanedUser);
      _setupSessionListener(cleanedUser);
    } catch (e) {
      state = AuthState.withError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ── Customer OTP Login ─────────────────────────────────────────────────────
  Future<bool> checkCustomerExists(String contact) async {
    await _repo.ensureInitialized();
    return _repo.checkCustomerExists(contact);
  }

  Future<void> validateCustomerRegistrationData({
    String? phone,
    String? email,
    String? nic,
  }) async {
    await _repo.validateCustomerRegistrationData(
      phone: phone,
      email: email,
      nic: nic,
    );
  }

  Future<void> loginCustomerOtp({required String contact}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repo.loginCustomerOtp(contact);
      await StorageService.saveToken(result.token);
      await StorageService.saveUser(result.user.toJson());
      await StorageService.saveRole(result.user.role.name);
      NotificationRepository.instance.resetForNewSession();
      state = AuthState.authenticated(result.user);
      _setupSessionListener(result.user);
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
    bool? verifiedPhone,
    bool? verifiedEmail,
    String? detectedCountry,
    String? detectionSource,
    String? riskFlag,
    String? nic,
    String? deliveryProvince,
    String? deliveryDistrict,
    String? deliveryApproxArea,
    String? deliveryPreciseAddress,
    String? deliveryNote,
    double? deliveryLatitude,
    double? deliveryLongitude,
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
    debugPrint('[Auth] Register shop coordinates: lat=$shopLatitude, lng=$shopLongitude');
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
        verifiedPhone: verifiedPhone,
        verifiedEmail: verifiedEmail,
        detectedCountry: detectedCountry,
        detectionSource: detectionSource,
        riskFlag: riskFlag,
        nic: nic,
        deliveryProvince: deliveryProvince,
        deliveryDistrict: deliveryDistrict,
        deliveryApproxArea: deliveryApproxArea,
        deliveryPreciseAddress: deliveryPreciseAddress,
        deliveryNote: deliveryNote,
        deliveryLatitude: deliveryLatitude,
        deliveryLongitude: deliveryLongitude,
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
      _setupSessionListener(result.user);
      debugPrint('[Auth] Register success: authenticated user ${result.user.email}');
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      debugPrint('[Auth] Register error caught: $errorMsg');
      state = AuthState.withError(errorMsg);
      debugPrint('[Auth] Error state set, hasError=${state.hasError}, error=${state.error}');
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<bool> restoreRememberedSession({
    required UserRole role,
    required bool Function(UserModel user) matchesAccount,
  }) async {
    final saved = await StorageService.getRememberedSession();
    if (saved == null) return false;

    final user = UserModel.fromJson(saved.user);
    if (user.role != role ||
        !matchesAccount(user) ||
        _repo.currentFirebaseUid != user.id) {
      return false;
    }

    await StorageService.saveToken(saved.token);
    await StorageService.saveUser(saved.user);
    await StorageService.saveRole(user.role.name);
    NotificationRepository.instance.resetForNewSession();
    state = AuthState.authenticated(user);
    await _setupSessionListener(user);
    return true;
  }

  Future<void> logout({bool keepRememberedSession = false}) async {
    state = state.copyWith(isLoading: true);
    try {
      // Unsubscribe vendor from FCM topics before clearing session
      final role = state.user?.role;
      final shopDistrict = state.user?.shopDistrict;
      if (role == UserRole.vendor) {
        await FcmService.unsubscribeVendorFromTopics(shopDistrict: shopDistrict);
      }
      final user = state.user;
      final token = await StorageService.getToken();
      if (keepRememberedSession && user != null && token != null) {
        await StorageService.saveRememberedSession(
          userJson: user.toJson(),
          token: token,
        );
      } else {
        await StorageService.clearRememberedSession();
      }
      await _userSubscription?.cancel();
      _userSubscription = null;
      await _repo.logout(keepFirebaseSession: keepRememberedSession);
      await StorageService.clearSession();
      if (role != null) await StorageService.saveRole(role.name);
      state = const AuthState.unauthenticated();
    } catch (e) {
      debugPrint('[Auth] Logout failed: $e');
      // If we failed to hit the network, we should still clear local session 
      // so the user isn't permanently trapped.
      await StorageService.clearSession();
      state = const AuthState.unauthenticated();
    }
  }

  // ── Update Profile ────────────────────────────────────────────────────────
  Future<void> updateProfile({
    required String fullName,
    required String phone,
    String? businessName,
    String? profileImageUrl,
    List<String>? vendorCategories,
    List<String>? requestedCategories,
    String? bankName,
    String? bankBranch,
    String? bankAccountName,
    String? bankAccountNumber,
    bool? acceptsCashOnDelivery,
    bool? acceptsBankTransfer,
  }) async {
    // Do NOT set isLoading here — it triggers the router's refreshListenable
    // and causes unwanted navigation during a simple profile update.
    try {
      final currentUser = state.user;
      if (currentUser == null) throw Exception('No authenticated user found.');

      final updatedUser = currentUser.copyWith(
        fullName: fullName,
        phone: phone,
        businessName: businessName,
        profileImageUrl: profileImageUrl ?? currentUser.profileImageUrl,
        vendorCategories: vendorCategories,
        requestedCategories: requestedCategories,
        hasPendingCategoryRequest: requestedCategories?.isNotEmpty == true,
        bankName: bankName ?? currentUser.bankName,
        bankBranch: bankBranch ?? currentUser.bankBranch,
        bankAccountName: bankAccountName ?? currentUser.bankAccountName,
        bankAccountNumber: bankAccountNumber ?? currentUser.bankAccountNumber,
        acceptsCashOnDelivery: acceptsCashOnDelivery ?? currentUser.acceptsCashOnDelivery,
        acceptsBankTransfer: acceptsBankTransfer ?? currentUser.acceptsBankTransfer,
      );

      final savedUser = await _repo.updateUser(updatedUser);

      // Update registration index if phone changed
      if (phone != currentUser.phone) {
        await StorageService.updateRegistrationIndex(
          email: currentUser.email,
          newPhone: phone,
        );
      }

      if (currentUser.id == updatedUser.id) {
        await StorageService.saveUser(savedUser.toJson());
        state = AuthState.authenticated(savedUser);
      } else {
        await StorageService.saveUser(currentUser.toJson());
      }
    } catch (e) {
      // Preserve the authenticated user — only attach the error message.
      // Using AuthState.withError would set user=null and trigger a router
      // redirect to the login screen.
      state = state.copyWith(error: e.toString().replaceAll('Exception: ', ''));
      rethrow;
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

    // Keep the local duplicate-check index aligned with the verified phone.
    if (phone != currentUser.phone) {
      await StorageService.updateRegistrationIndex(
        email: currentUser.email,
        newPhone: phone,
      );
    }

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
  Future<UserModel> _cleanUserCategoriesOnLogin(UserModel user) async {
    return user;
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

  // ── Refresh vendor status from Firestore ─────────────────────────────────
  Future<void> refreshVendorStatus() async {
    final currentUser = state.user;
    if (currentUser == null || currentUser.role != UserRole.vendor) return;
    final refreshed = await _repo.refreshVendorStatus(currentUser.id);
    if (refreshed == null) return;
    await StorageService.saveUser(refreshed.toJson());
    state = AuthState.authenticated(refreshed);
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

