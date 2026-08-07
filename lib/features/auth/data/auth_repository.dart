import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firestore_service.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/services/fcm_service.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/models/vendor_status.dart';

/// Authentication repository — Firebase Auth for credentials, Firestore for user data.
class AuthRepository {
  AuthRepository._() {
    _initFuture = _initialize();
  }

  static final AuthRepository instance = AuthRepository._();

  late final Future<void> _initFuture;
  bool _isInitialized = false;
  String? _currentUserId;

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final List<UserModel> _sessionUsers = [];
  String? _currentToken;

  CollectionReference<Map<String, dynamic>> _collectionForRole(UserRole role) {
    switch (role) {
      case UserRole.vendor:
        return FirestoreService.collection('users/vendors/profiles');
      case UserRole.admin:
        return FirestoreService.collection('users/admins/profiles');
      case UserRole.customer:
      default:
        return FirestoreService.collection('users/customers/profiles');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUsersFromFirestore() async {
    try {
      final results = await Future.wait([
        FirestoreService.collection('users/customers/profiles').get(),
        FirestoreService.collection('users/vendors/profiles').get(),
        FirestoreService.collection('users/admins/profiles').get(),
      ]);
      return results.expand((snapshot) => snapshot.docs.map((doc) {
        return {...doc.data(), 'id': doc.id};
      })).toList();
    } catch (e) {
      debugPrint('[Auth] Failed to load users from Firestore: $e');
      return [];
    }
  }

  Future<void> _syncUserToFirestore(UserModel user) async {
    try {
      final doc = _collectionForRole(user.role).doc(user.id);
      await doc.set(user.toJson(), SetOptions(merge: true));
      debugPrint('[Auth] Synced user ${user.id} to Firestore (${user.role.name})');
    } catch (e) {
      debugPrint('[Auth] Failed to sync user ${user.id} to Firestore: $e');
      rethrow;
    }
  }

  Future<void> _createFirebaseUser(String email, String password) async {
    // Customers register via OTP with no password — generate a strong one for Firebase Auth.
    final effectivePassword = password.isNotEmpty
        ? password
        : 'OTP_${email.hashCode.abs()}_${DateTime.now().millisecondsSinceEpoch}';
    try {
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: effectivePassword,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('An account with this email already exists.');
      }
      throw Exception('Failed to create auth account: ${e.message ?? e.code}');
    }
  }

  Future<void> _signInWithFirebase(String email, String password) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('No account found with this email.');
      }
      if (e.code == 'wrong-password') {
        throw Exception('Incorrect password. Please try again.');
      }
      throw Exception('Login failed: ${e.message ?? e.code}');
    } catch (e) {
      throw Exception('Login failed: $e');
    } finally {
      // Do NOT sign out here — signing out triggers authStateChanges(null)
      // which causes NotificationRepository to reset and the router to
      // briefly see isAuthenticated=false, kicking the user to login.
    }
  }

  Future<void> _syncUsersToFirestore(List<UserModel> users) async {
    for (final user in users) {
      await _syncUserToFirestore(user);
    }
  }

  /// Ensures saved users are loaded before auth operations.
  Future<void> ensureInitialized() => _initFuture;

  Future<void> _initialize() async {
    if (_isInitialized) return;

    _sessionUsers.clear();

    try {
      final firestoreUsers = await _fetchUsersFromFirestore();
      if (firestoreUsers.isNotEmpty) {
        debugPrint('[Auth] Loaded ${firestoreUsers.length} users from Firestore');
        for (final json in firestoreUsers) {
          final user = UserModel.fromJson(json);
          final index = _sessionUsers.indexWhere((u) => u.id == user.id);
          if (index >= 0) {
            _sessionUsers[index] = user;
          } else {
            _sessionUsers.add(user);
          }
        }
      } else {
        // Firestore unavailable (not authenticated yet) — fall back to local storage
        final savedJson = await StorageService.getRegisteredUsers();
        if (savedJson.isNotEmpty) {
          debugPrint('[Auth] Loaded ${savedJson.length} users from local storage (offline fallback)');
          for (final json in savedJson) {
            _sessionUsers.add(UserModel.fromJson(json));
          }
        }
      }
      debugPrint('[Auth] Total users loaded: ${_sessionUsers.length}');
    } catch (e) {
      debugPrint('[Auth] Failed to load users during initialization: $e');
    }

    _isInitialized = true;
  }

  /// Forces a re-sync from Firestore (e.g. after registration when auth state is now set).
  Future<void> reloadFromFirestore() async {
    if (_firebaseAuth.currentUser == null) return;
    try {
      final firestoreUsers = await _fetchUsersFromFirestore();
      for (final json in firestoreUsers) {
        final user = UserModel.fromJson(json);
        final index = _sessionUsers.indexWhere((u) => u.id == user.id);
        if (index >= 0) {
          _sessionUsers[index] = user;
        } else {
          _sessionUsers.add(user);
        }
      }
      debugPrint('[Auth] Reloaded ${firestoreUsers.length} users from Firestore');
    } catch (e) {
      debugPrint('[Auth] reloadFromFirestore error: $e');
    }
  }

  Future<void> _persistUsers() async {
    await _syncUsersToFirestore(_sessionUsers);
    debugPrint('[Auth] Users synced to Firestore: ${_sessionUsers.length} users');
  }

  static String _digitsOnly(String value) =>
      value.replaceAll(RegExp(r'[^\d]'), '');

  static bool _phoneMatches(String a, String b) {
    final da = _digitsOnly(a);
    final db = _digitsOnly(b);
    if (da.isEmpty || db.isEmpty) return false;
    if (da.length >= 9 && db.length >= 9) {
      return da.endsWith(db.substring(db.length - 9)) ||
          db.endsWith(da.substring(da.length - 9));
    }
    return da == db;
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<({UserModel user, String token})> login({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 1200));

    debugPrint('[Auth] Login attempt: email=$email, role=$role');

    // Sign in with Firebase first so Firestore reads are authenticated.
    await _signInWithFirebase(email, password);
    // Now reload users from Firestore with valid auth.
    await reloadFromFirestore();

    debugPrint('[Auth] Total users available: ${_sessionUsers.length}');

    final match = _sessionUsers.where(
      (u) =>
          u.email.toLowerCase() == email.toLowerCase() &&
          u.role == role,
    );

    if (match.isEmpty) {
      debugPrint('[Auth] No user found with email=$email and role=$role');
      debugPrint('[Auth] Available users: ${_sessionUsers.map((u) => '${u.email}(${u.role.name})').join(', ')}');
      throw Exception('No account found with this email for the selected role.');
    }

    final user = match.first;
    debugPrint('[Auth] Firebase auth verification succeeded for ${user.email}');
    debugPrint('[Auth] User found: ${user.email}, vendorStatus=${user.vendorStatus}, isActive=${user.isActive}');

    if (!user.isActive) {
      throw Exception('Your account has been suspended. Contact support.');
    }

    _currentToken =
        'auth_token_${user.id}_${DateTime.now().millisecondsSinceEpoch}';
    _currentUserId = user.id;
    debugPrint('[Auth] Login success: ${user.email}');

    // Upload FCM token to backend (best-effort)
    _uploadDeviceTokenForUser(user);
    return (user: user, token: _currentToken!);
  }

  // ── Customer OTP Authentication ──────────────────────────────────────────
  Future<bool> checkCustomerExists(String contact) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 600));
    final isEmail = contact.contains('@');

    return _sessionUsers.any((u) {
      if (u.role != UserRole.customer) return false;
      if (isEmail) {
        return u.email.toLowerCase() == contact.toLowerCase().trim();
      }
      return _phoneMatches(contact, u.phone);
    });
  }

  Future<void> validateCustomerRegistrationData({
    String? phone,
    String? email,
    String? nic,
  }) async {
    await ensureInitialized();
    final normPhone = phone?.trim();
    final normEmail = email?.trim().toLowerCase();
    final normNic = nic?.trim().toLowerCase();

    if (normPhone != null && normPhone.isNotEmpty) {
      final phoneExists = _sessionUsers.any(
        (u) => _phoneMatches(normPhone, u.phone),
      );
      if (phoneExists) {
        throw Exception('An account with this phone number already exists.');
      }
    }

    if (normEmail != null && normEmail.isNotEmpty) {
      final emailExists = _sessionUsers.any(
        (u) => u.email.isNotEmpty && u.email.toLowerCase() == normEmail,
      );
      if (emailExists) {
        throw Exception('An account with this email already exists.');
      }
    }

    if (normNic != null && normNic.isNotEmpty) {
      final nicExists = _sessionUsers.any(
        (u) => u.nic != null && u.nic!.trim().toLowerCase() == normNic,
      );
      if (nicExists) {
        throw Exception('An account with this NIC number already exists.');
      }
    }
  }

  Future<({UserModel user, String token})> loginCustomerOtp(String contact) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 1000));
    // Reload from Firestore if already authenticated (e.g. session restore)
    await reloadFromFirestore();
    final isEmail = contact.contains('@');

    final match = _sessionUsers.where((u) {
      if (u.role != UserRole.customer) return false;
      if (isEmail) {
        return u.email.toLowerCase() == contact.toLowerCase().trim();
      }
      return _phoneMatches(contact, u.phone);
    });

    if (match.isEmpty) {
      throw Exception('No account found for this ${isEmail ? 'email' : 'phone number'}. Please register.');
    }
    final user = match.first;

    if (!user.isActive) {
      throw Exception('Your account has been suspended. Contact support.');
    }

    _currentToken =
        'auth_token_${user.id}_${DateTime.now().millisecondsSinceEpoch}';
    _currentUserId = user.id;
    // Upload FCM token to backend (best-effort)
    _uploadDeviceTokenForUser(user);
    return (user: user, token: _currentToken!);
  }

  // ── Register ───────────────────────────────────────────────────────────────
  Future<({UserModel user, String token})> register({
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
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 1500));

    final normalizedEmail = email.trim();
    final normalizedPhone = phone.trim();

    if (normalizedEmail.isNotEmpty) {
      final emailExists = _sessionUsers.any(
        (u) =>
            u.email.isNotEmpty &&
            u.email.toLowerCase() == normalizedEmail.toLowerCase(),
      );
      if (emailExists) {
        throw Exception('An account with this email already exists.');
      }
    }

    if (normalizedPhone.isNotEmpty) {
      final phoneExists = _sessionUsers.any(
        (u) => _phoneMatches(normalizedPhone, u.phone),
      );
      if (phoneExists) {
        throw Exception('An account with this phone number already exists.');
      }
    }

    final normalizedNic = nic?.trim();
    if (normalizedNic != null && normalizedNic.isNotEmpty) {
      final nicExists = _sessionUsers.any(
        (u) => u.nic != null && u.nic!.trim().toLowerCase() == normalizedNic.toLowerCase(),
      );
      if (nicExists) {
        throw Exception('An account with this NIC number already exists.');
      }
    }

    final resolvedEmail = normalizedEmail.isNotEmpty
        ? normalizedEmail
        : (normalizedPhone.isNotEmpty
            ? '${_digitsOnly(normalizedPhone)}@customer.speedmart.local'
            : '${role.name}-${DateTime.now().millisecondsSinceEpoch}@speedmart.local');

    final newUser = UserModel(
      id: '${role.name}-${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName,
      email: resolvedEmail,
      phone: normalizedPhone,
      role: role,
      isActive: true,
      isVerified: role != UserRole.vendor,
      createdAt: DateTime.now(),
      businessName: businessName,
      vendorStatus: role == UserRole.vendor ? VendorStatus.pendingApproval : null,
      vendorApproved: role == UserRole.vendor ? false : null,
      vendorCategories: categories,
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
      isShopLocationAssigned: false,
      businessRegistrationNumber: businessRegistrationNumber,
    );

    await _createFirebaseUser(resolvedEmail, password);
    // After createUserWithEmailAndPassword, currentUser is set — Firestore writes are now authenticated.
    debugPrint('[Auth] Firebase user created, currentUser=${_firebaseAuth.currentUser?.uid}');
    _sessionUsers.add(newUser);
    await _syncUserToFirestore(newUser);

    debugPrint('[VendorLocationAudit] Stored vendor coordinates: lat=$shopLatitude, lng=$shopLongitude');
    debugPrint('[Auth] Vendor registration saved: email=$resolvedEmail, id=${newUser.id}, status=${newUser.vendorStatus}');
    debugPrint('[Auth] Shop details submitted: address=${shopAddress}, lat=$shopLatitude, lng=$shopLongitude');
    debugPrint('[Auth] Total users in memory: ${_sessionUsers.length}');

    _currentToken =
        'auth_token_${newUser.id}_${DateTime.now().millisecondsSinceEpoch}';
    _currentUserId = newUser.id;
    // Upload FCM token to backend (best-effort)
    _uploadDeviceTokenForUser(newUser);
    return (user: newUser, token: _currentToken!);
  }

  // Best-effort upload of device FCM token to backend. No-op if backend URL not configured.
  static const String _backendBaseUrl = '';

  Future<void> _uploadDeviceTokenForUser(UserModel user, {String? token}) async {
    try {
      if (_backendBaseUrl.isEmpty) {
        debugPrint('[Auth] No backend URL configured; skipping token upload');
        return;
      }

      final resolvedToken = token ?? await FcmService.getToken();
      if (resolvedToken == null) return;

      final dio = Dio();
      final resp = await dio.post('$_backendBaseUrl/devices', data: {
        'userId': user.id,
        'token': resolvedToken,
        'platform': defaultTargetPlatform.toString(),
      });
      debugPrint('[Auth] Uploaded FCM token: ${resp.statusCode}');
    } catch (e) {
      debugPrint('[Auth] Failed to upload FCM token: $e');
    }
  }

  /// Called when Firebase issues a new token (on refresh). If a user is
  /// currently logged in, attempt to upload immediately.
  Future<void> handleFcmTokenRefresh(String token) async {
    try {
      if (_currentUserId == null) {
        debugPrint('[Auth] No logged-in user; skipping token upload on refresh');
        return;
      }
      final user = await getUserById(_currentUserId!);
      if (user == null) {
        debugPrint('[Auth] Current user id not found in registry');
        return;
      }
      await _uploadDeviceTokenForUser(user, token: token);
    } catch (e) {
      debugPrint('[Auth] handleFcmTokenRefresh error: $e');
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentToken = null;
    _currentUserId = null;
  }

  // ── Restore session ────────────────────────────────────────────────────────
  Future<UserModel?> restoreSession(String token) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      final parts = token.split('_');
      if (parts.length >= 3) {
        final userId = parts.sublist(2, parts.length - 1).join('_');
        return _sessionUsers.firstWhere(
          (u) => u.id == userId,
          orElse: () => throw Exception('Session expired'),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<List<UserModel>> getAllUsers() async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_sessionUsers);
  }

  Future<UserModel?> getUserById(String userId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return _sessionUsers.firstWhere((u) => u.id == userId);
    } catch (_) {
      return null;
    }
  }

  Future<void> approveVendor(String vendorId, {String? notes}) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 400));
    final index = _sessionUsers.indexWhere((u) => u.id == vendorId);
    if (index != -1) {
      _sessionUsers[index] = _sessionUsers[index].copyWith(
        vendorStatus: VendorStatus.approved,
        vendorApproved: true,
        isVerified: true,
      );
      await _persistUsers();
    }
  }

  Future<void> rejectVendor(String vendorId, {required String reason}) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 400));
    final index = _sessionUsers.indexWhere((u) => u.id == vendorId);
    if (index != -1) {
      _sessionUsers[index] = _sessionUsers[index].copyWith(
        vendorStatus: VendorStatus.rejected,
        vendorApproved: false,
      );
      await _persistUsers();
    }
  }

  Future<void> suspendVendor(String vendorId, {required String reason}) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 400));
    final index = _sessionUsers.indexWhere((u) => u.id == vendorId);
    if (index != -1) {
      final vendor = _sessionUsers[index];
      debugPrint('[VendorStatusFix] Suspend vendor before: status=${vendor.vendorStatus}, isActive=${vendor.isActive}, approved=${vendor.vendorApproved}');
      
      _sessionUsers[index] = vendor.copyWith(
        vendorStatus: VendorStatus.suspended,
        isActive: false,
        vendorApproved: true, // Keep approval status
      );
      
      debugPrint('[VendorStatusFix] Suspend vendor after: status=${_sessionUsers[index].vendorStatus}, isActive=${_sessionUsers[index].isActive}, approved=${_sessionUsers[index].vendorApproved}');
      await _persistUsers();
      debugPrint('[VendorStatusFix] Persisted vendorStatus: ${_sessionUsers[index].vendorStatus}');
    }
  }

  Future<void> toggleUserActive(String userId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _sessionUsers.indexWhere((u) => u.id == userId);
    if (index != -1) {
      final user = _sessionUsers[index];
      final newIsActive = !user.isActive;
      
      debugPrint('[VendorStatusFix] Toggle before: status=${user.vendorStatus}, isActive=${user.isActive}, approved=${user.vendorApproved}');
      
      // If activating a suspended vendor, restore approved status
      if (newIsActive && user.vendorStatus == VendorStatus.suspended) {
        _sessionUsers[index] = user.copyWith(
          vendorStatus: VendorStatus.approved,
          isActive: true,
          vendorApproved: true,
        );
        debugPrint('[VendorStatusFix] Activate vendor after: status=${_sessionUsers[index].vendorStatus}, isActive=${_sessionUsers[index].isActive}, approved=${_sessionUsers[index].vendorApproved}');
      } else if (!newIsActive && user.role == UserRole.vendor) {
        // If deactivating, set to suspended
        _sessionUsers[index] = user.copyWith(
          vendorStatus: VendorStatus.suspended,
          isActive: false,
          vendorApproved: true,
        );
        debugPrint('[VendorStatusFix] Suspend vendor after: status=${_sessionUsers[index].vendorStatus}, isActive=${_sessionUsers[index].isActive}, approved=${_sessionUsers[index].vendorApproved}');
      } else {
        // For non-vendors, just toggle isActive
        _sessionUsers[index] = user.copyWith(
          isActive: newIsActive,
        );
        debugPrint('[VendorStatusFix] Toggle after: isActive=${_sessionUsers[index].isActive}');
      }
      
      await _persistUsers();
      debugPrint('[VendorStatusFix] Persisted vendorStatus: ${_sessionUsers[index].vendorStatus}');
    }
  }

  // ── Vendor Credential Check (without authenticating) ─────────────────────

  /// Verifies vendor credentials without setting auth state.
  /// Returns the matched user if credentials are valid.
  Future<UserModel> verifyVendorCredentials({
    required String email,
    required String password,
  }) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 1200));

    final match = _sessionUsers.where(
      (u) =>
          u.role == UserRole.vendor &&
          u.email.toLowerCase() == email.toLowerCase().trim(),
    );

    if (match.isEmpty) {
      throw Exception('No vendor account found with this email.');
    }

    final user = match.first;
    await _signInWithFirebase(user.email, password);
    // Reload Firestore after auth so we have the latest user data.
    await reloadFromFirestore();

    if (!user.isActive) {
      throw Exception('Your account has been suspended. Contact support.');
    }

    return user;
  }

  // ── Password Reset ──────────────────────────────────────────────────────

  /// Returns null — passwords are now managed entirely by Firebase Auth.
  Future<String?> getVendorPassword(String email) async => null;

  /// Checks if a vendor with [email] exists and returns a mock OTP.
  Future<String> generateResetOtp(String email) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 800));
    final exists = _sessionUsers.any(
      (u) =>
          u.role == UserRole.vendor &&
          u.email.toLowerCase() == email.toLowerCase().trim(),
    );
    if (!exists) throw Exception('No vendor account found with this email.');
    // In a real app this would send an email; here we return a fixed mock OTP.
    return '123456';
  }

  /// Updates the password for the vendor with [email].
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 600));
    final normalizedEmail = email.toLowerCase().trim();
    final exists = _sessionUsers.any(
      (u) => u.role == UserRole.vendor && u.email.toLowerCase() == normalizedEmail,
    );
    if (!exists) throw Exception('No vendor account found with this email.');
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: normalizedEmail);
      debugPrint('[Auth] Password reset email sent for: $normalizedEmail');
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Failed to send password reset email.');
    }
  }

  /// Sets the commission rate for a specific vendor (admin-only action).
  /// [rate] is a fraction 0.0–1.0 (e.g. 0.05 for 5%). Pass null to reset to platform default.
  Future<void> updateVendorCommission(String vendorId, double? rate) async {
    await ensureInitialized();
    final index = _sessionUsers.indexWhere((u) => u.id == vendorId);
    if (index != -1) {
      _sessionUsers[index] = rate == null
          ? _sessionUsers[index].copyWith(clearCommissionRate: true)
          : _sessionUsers[index].copyWith(commissionRate: rate);
      await _persistUsers();
      debugPrint('[CommissionAudit] Vendor $vendorId commission set to ${rate == null ? 'default (0%)' : '${(rate * 100).toStringAsFixed(2)}%'}');
    }
  }

  Future<UserModel> updateUser(UserModel user) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 500));
    
    debugPrint('[CategoryAudit] ===== REPOSITORY UPDATE START =====');
    debugPrint('[CategoryAudit] updateUser called for userId: ${user.id}');
    debugPrint('[CategoryAudit] user.allowedCategories being saved: ${user.allowedCategories}');
    debugPrint('[CategoryAudit] user.vendorCategories: ${user.vendorCategories}');
    
    final index = _sessionUsers.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      debugPrint('[CategoryAudit] BEFORE update in _sessionUsers[${index}].allowedCategories: ${_sessionUsers[index].allowedCategories}');
      _sessionUsers[index] = user;
      debugPrint('[CategoryAudit] AFTER update in _sessionUsers[${index}].allowedCategories: ${_sessionUsers[index].allowedCategories}');
    } else {
      _sessionUsers.add(user);
      debugPrint('[CategoryAudit] User added to _sessionUsers (new user)');
    }
    await _persistUsers();
    debugPrint('[CategoryAudit] ===== REPOSITORY UPDATE COMPLETE =====');
    return user;
  }

  /// Batch update users with a single storage persist operation
  /// Optimized for category sync: update only affected users and persist once
  Future<void> batchUpdateUsers(List<UserModel> users) async {
    await ensureInitialized();
    
    if (users.isEmpty) {
      debugPrint('[CategorySync] Batch update: 0 users, skipping');
      return;
    }
    
    debugPrint('[CategorySync] ===== BATCH UPDATE START =====');
    debugPrint('[CategorySync] Updating ${users.length} users in single batch');
    
    try {
      // Update all users in memory
      for (final user in users) {
        final index = _sessionUsers.indexWhere((u) => u.id == user.id);
        if (index != -1) {
          _sessionUsers[index] = user;
          debugPrint('[CategorySync] Updated user ${user.id} in memory');
        } else {
          _sessionUsers.add(user);
          debugPrint('[CategorySync] Added new user ${user.id} in memory');
        }
      }
      
      // Persist all users only once after batch update completes
      await _persistUsers();
      debugPrint('[CategorySync] ===== BATCH UPDATE COMPLETE: ${users.length} users persisted =====');
    } catch (e) {
      debugPrint('[CategorySync] ERROR in batch update: $e');
      rethrow;
    }
  }
}

