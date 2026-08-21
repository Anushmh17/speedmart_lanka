import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform;
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/utils/sri_lanka_phone_helper.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/models/vendor_status.dart';
import 'package:uuid/uuid.dart';
import 'package:speedmart_lanka/core/utils/error_translator.dart';

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

  String? get currentFirebaseUid => _firebaseAuth.currentUser?.uid;

  /// Helper to record a new session limit (max 5)
  Future<UserModel> _recordSession(UserModel user) async {
    const uuid = Uuid();
    final newSessionId = uuid.v4();
    
    // Save to local storage so the device knows its own ID
    await StorageService.saveSessionId(newSessionId);
    
    List<String> sessions = user.activeSessions?.toList() ?? [];
    sessions.add(newSessionId);
    
    // Enforce 5-device limit
    if (sessions.length > 5) {
      sessions = sessions.sublist(sessions.length - 5);
    }
    
    final updatedUser = user.copyWith(activeSessions: sessions);
    
    // The session listener starts immediately after login.  Persist this ID
    // first so its initial snapshot cannot see an older active_sessions list
    // and incorrectly log the device out.
    await _syncUserToFirestore(updatedUser);
    
    return updatedUser;
  }

  CollectionReference<Map<String, dynamic>> _collectionForRole(UserRole role) {
    switch (role) {
      case UserRole.vendor:
        return FirestoreService.collection('users/vendors/profiles');
      case UserRole.admin:
        return FirestoreService.collection('users/admins/profiles');
      case UserRole.customer:
        return FirestoreService.collection('users/customers/profiles');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUsersFromFirestore() async {
    Future<List<Map<String, dynamic>>> loadCollection(String path) async {
      try {
        final snapshot = await FirestoreService.collection(path).limit(500).get();
        return snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
      } catch (_) {
        // Role-scoped rules intentionally deny some profile collections.
        return [];
      }
    }

    final results = await Future.wait([
      loadCollection('users/customers/profiles'),
      loadCollection('users/vendors/profiles'),
      loadCollection('users/admins/profiles'),
    ]);
    return results.expand((users) => users).toList();
  }

  /// Real-time stream for the user profile document (used for session tracking and live updates)
  Stream<DocumentSnapshot<Map<String, dynamic>>> userStream(String uid, UserRole role) {
    return _collectionForRole(role).doc(uid).snapshots();
  }

  /// Fetches a single user by email from the correct role subcollection.
  Future<UserModel?> _fetchUserByEmail(String email, UserRole role) async {
    try {
      final snapshot = await _collectionForRole(role)
          .where('email', isEqualTo: email.toLowerCase().trim())
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return UserModel.fromJson({...doc.data(), 'id': doc.id});
    } catch (e) {
      debugPrint('[Auth] _fetchUserByEmail error: $e');
      return null;
    }
  }

  /// Normalizes a phone number to +94XXXXXXXXX format for Firestore queries.
  static String _normalizeToE164(String phone) {
    final digits = _digitsOnly(phone.trim());
    if (digits.length == 9) return '+94$digits'; // 771234567
    if (digits.length == 10 && digits.startsWith('0'))
      return '+94${digits.substring(1)}'; // 0771234567
    if (digits.length == 11 && digits.startsWith('94'))
      return '+$digits'; // 94771234567
    if (digits.length == 12 && digits.startsWith('94'))
      return '+${digits.substring(0)}'; // already +94...
    return phone.trim(); // fallback — e.g. already +94771234567
  }

  /// Fetches a single customer by phone or email from Firestore.
  Future<UserModel?> _fetchCustomerByContact(String contact) async {
    try {
      final isEmail = contact.contains('@');
      final field = isEmail ? 'email' : 'phone';
      final value =
          isEmail ? contact.toLowerCase().trim() : _normalizeToE164(contact);
      final snapshot =
          await FirestoreService.collection('users/customers/profiles')
              .where(field, isEqualTo: value)
              .limit(1)
              .get();
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return UserModel.fromJson({...doc.data(), 'id': doc.id});
    } catch (e) {
      debugPrint('[Auth] _fetchCustomerByContact error: $e');
      return null;
    }
  }

  Future<bool> _customerExistsInFirestore({
    required String field,
    String? value,
    List<String>? values,
  }) async {
    try {
      final col = FirestoreService.collection('users/customers/profiles');
      Query<Map<String, dynamic>> query = col;
      QuerySnapshot<Map<String, dynamic>> snapshot;

      if (values != null && values.isNotEmpty) {
        snapshot = await query.where(field, whereIn: values).limit(1).get();
      } else if (value != null) {
        snapshot = await query.where(field, isEqualTo: value).limit(1).get();
      } else {
        return false;
      }

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('[Auth] _customerExistsInFirestore($field) error: $e');
      // PERMISSION_DENIED means the user isn't authenticated yet — treat as
      // unavailable so the caller falls back to local cache instead of crashing.
      final msg = e.toString();
      if (msg.contains('permission-denied') || msg.contains('PERMISSION_DENIED')) {
        throw Exception('firestore_unavailable');
      }
      rethrow;
    }
  }

  static String _normalizeNicForQuery(String nic) {
    return nic.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }

  Future<void> _syncUserToFirestore(UserModel user) async {
    try {
      final doc = _collectionForRole(user.role).doc(user.id);
      await doc.set(user.toJson(), SetOptions(merge: true));
      debugPrint(
          '[Auth] Synced user ${user.id} to Firestore (${user.role.name})');
    } catch (e) {
      debugPrint('[Auth] Failed to sync user ${user.id} to Firestore: $e');
      rethrow;
    }
  }

  Future<void> _createFirebaseUser(String email, String password) async {
    // Only vendors register with email+password.
    // Customers get their Firebase account created automatically by
    // Firebase Phone Auth during OTP verification — skip for them.
    if (password.isEmpty) return;
    try {
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
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
    // Do NOT fetch from Firestore here — no user is authenticated yet.
    // Users are loaded on-demand during login/OTP after Firebase Auth signs in.
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
      debugPrint(
          '[Auth] Reloaded ${firestoreUsers.length} users from Firestore');
    } catch (e) {
      debugPrint('[Auth] reloadFromFirestore error: $e');
    }
  }

  Future<void> _persistUsers() async {
    await _syncUsersToFirestore(_sessionUsers);
    debugPrint(
        '[Auth] Users synced to Firestore: ${_sessionUsers.length} users');
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

    return _completeVendorLogin(email, role);
  }

  /// Completes vendor login after phone OTP verification.
  ///
  /// Firebase Phone Auth changes the current Firebase user to the phone-based
  /// account. Sign back in as the email account so its UID matches the vendor
  /// profile document before reading or updating Firestore.
  Future<({UserModel user, String token})> loginVendorAfterOtp({
    required String email,
    required String password,
  }) async {
    await ensureInitialized();
    await _signInWithFirebase(email, password);
    return _completeVendorLogin(email, UserRole.vendor);
  }

  Future<({UserModel user, String token})> _completeVendorLogin(
      String email, UserRole role) async {
    final fetchedUser = await _fetchUserByEmail(email, role);
    if (fetchedUser == null) {
      await _firebaseAuth.signOut();
      throw Exception('No account found with this email for the selected role.');
    }

    final index = _sessionUsers.indexWhere((u) => u.id == fetchedUser.id);
    if (index >= 0) {
      _sessionUsers[index] = fetchedUser;
    } else {
      _sessionUsers.add(fetchedUser);
    }

    debugPrint('[Auth] User found: ${fetchedUser.email}, vendorStatus=${fetchedUser.vendorStatus}, isActive=${fetchedUser.isActive}');

    if (!fetchedUser.isActive) {
      throw Exception('Your account has been suspended. Contact support.');
    }

    _currentToken = 'auth_token_${fetchedUser.id}_${DateTime.now().millisecondsSinceEpoch}';
    _currentUserId = _firebaseAuth.currentUser?.uid ?? fetchedUser.id;
    debugPrint('[Auth] Login success: ${fetchedUser.email}');

    _uploadDeviceTokenForUser(fetchedUser);
    
    final updatedUser = await _recordSession(fetchedUser);
    return (user: updatedUser, token: _currentToken!);
  }

  // ── Customer OTP Authentication ──────────────────────────────────────────

  Future<bool> checkCustomerExists(String contact) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 600));
    final isEmail = contact.contains('@');
    final inCache = _sessionUsers.any((u) {
      if (u.role != UserRole.customer) return false;
      if (isEmail) return u.email.toLowerCase() == contact.toLowerCase().trim();
      return _phoneMatches(contact, u.phone);
    });
    if (inCache) return true;
    final fetched = await _fetchCustomerByContact(contact);
    return fetched != null;
  }

  Future<void> validateCustomerRegistrationData({
    String? phone,
    String? email,
    String? nic,
  }) async {
    await ensureInitialized();
    final normPhone = phone?.trim();
    final normEmail = email?.trim().toLowerCase();
    final normNic = nic?.trim().toUpperCase();

    List<Map<String, dynamic>>? localCheckList;

    Future<List<Map<String, dynamic>>> getLocalCheckList() async {
      localCheckList ??= _sessionUsers.isNotEmpty
          ? _sessionUsers
              .map((u) => {'email': u.email, 'phone': u.phone, 'nic': u.nic})
              .toList()
          : await StorageService.getRegistrationIndex();
      return localCheckList!;
    }

    if (normPhone != null && normPhone.isNotEmpty) {
      final normalizedPhone = _normalizeToE164(normPhone);
      var firestoreUnavailable = false;
      var firestoreMatch = false;
      try {
        firestoreMatch = await _customerExistsInFirestore(
          field: 'phone',
          value: normalizedPhone,
        );
      } catch (_) {
        firestoreUnavailable = true;
      }
      if (!firestoreUnavailable && firestoreMatch) {
        throw Exception('An account with this phone number already exists.');
      }
      if (firestoreUnavailable) {
        final checkList = await getLocalCheckList();
        final exists = checkList.any((e) {
          final p = e['phone']?.toString() ?? '';
          return _phoneMatches(normPhone, p);
        });
        if (exists) {
          throw Exception('An account with this phone number already exists.');
        }
      }
    }

    if (normEmail != null && normEmail.isNotEmpty) {
      var firestoreUnavailable = false;
      var firestoreMatch = false;
      try {
        firestoreMatch = await _customerExistsInFirestore(
          field: 'email',
          value: normEmail,
        );
      } catch (_) {
        firestoreUnavailable = true;
      }
      if (!firestoreUnavailable && firestoreMatch) {
        throw Exception('An account with this email already exists.');
      }
      if (firestoreUnavailable) {
        final checkList = await getLocalCheckList();
        final exists = checkList.any((e) {
          final em = e['email']?.toString().toLowerCase() ?? '';
          return em.isNotEmpty && em == normEmail;
        });
        if (exists) throw Exception('An account with this email already exists.');
      }
    }

    if (normNic != null && normNic.isNotEmpty) {
      var firestoreUnavailable = false;
      var firestoreMatch = false;
      try {
        final cleaned = _normalizeNicForQuery(normNic);
        final candidates = <String>{
          normNic,
          normNic.toLowerCase(),
          cleaned,
          cleaned.toLowerCase()
        }..removeWhere((s) => s.trim().isEmpty);

        if (candidates.isNotEmpty) {
          firestoreMatch = await _customerExistsInFirestore(
            field: 'nic',
            values: candidates.toList(),
          );
        }
      } catch (_) {
        firestoreUnavailable = true;
      }

      if (!firestoreUnavailable && firestoreMatch) {
        throw Exception('An account with this NIC number already exists.');
      }

      if (firestoreUnavailable) {
        final checkList = await getLocalCheckList();
        final exists = checkList.any((e) {
          final n = e['nic']?.toString() ?? '';
          return n.isNotEmpty && _normalizeNicForQuery(n) == _normalizeNicForQuery(normNic);
        });
        if (exists) {
          throw Exception('An account with this NIC number already exists.');
        }
      }
    }
  }

  Future<({UserModel user, String token})> loginCustomerOtp(
      String contact) async {
    await ensureInitialized();

    // Firebase Phone Auth already signed the user in during OTP verification.
    // _firebaseAuth.currentUser is now set with the real phone-linked UID.
    final firebaseUser = _firebaseAuth.currentUser;
    debugPrint('[Auth] loginCustomerOtp: firebaseUser=${firebaseUser?.uid}');

    // Force a fresh ID token so the Firestore SDK has valid auth credentials
    // before we run any queries. Without this, there is a race condition where
    // OTP verification completes but the Firestore client hasn't yet received
    // the updated token — causing PERMISSION_DENIED on the phone query.
    if (firebaseUser != null) {
      try {
        await firebaseUser.getIdToken(true);
        debugPrint('[Auth] ID token refreshed successfully after OTP');
      } catch (e) {
        debugPrint('[Auth] ID token refresh failed (non-fatal): $e');
      }
    }

    // Small grace period for Firestore SDK to propagate the new auth token
    await Future.delayed(const Duration(milliseconds: 800));

    if (firebaseUser == null) {
      throw Exception('Phone verification did not complete. Please try again.');
    }

    // Customer profiles are stored with their Firebase Auth UID as the document
    // ID. Reading that document is allowed by the owner rule and avoids an
    // account-discovery query during sign-in.
    final profile = await _collectionForRole(UserRole.customer)
        .doc(firebaseUser.uid)
        .get();

    UserModel? fetchedUser;
    if (profile.exists) {
      fetchedUser = UserModel.fromJson({...profile.data()!, 'id': profile.id});
    } else {
      // Supports profiles created before Firebase UIDs were used as document IDs.
      // At this point the customer is authenticated, so the rules permit it.
      fetchedUser = await _fetchCustomerByContact(contact);
    }
    if (fetchedUser == null) {
      throw Exception('No account found for this phone number. Please register.');
    }
    final customer = fetchedUser;

    if (!customer.isActive) {
      throw Exception('Your account has been suspended. Contact support.');
    }

    // Merge into session cache
    final index = _sessionUsers.indexWhere((u) => u.id == customer.id);
    if (index >= 0) {
      _sessionUsers[index] = customer;
    } else {
      _sessionUsers.add(customer);
    }

    _currentToken =
        'auth_token_${customer.id}_${DateTime.now().millisecondsSinceEpoch}';
    _currentUserId = customer.id;
    _uploadDeviceTokenForUser(customer);
    
    final updatedUser = await _recordSession(customer);
    return (user: updatedUser, token: _currentToken!);
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
    await ensureInitialized();

    final normalizedEmail = email.trim();
    final rawPhone = phone.trim();
    final normalizedPhone = rawPhone.isNotEmpty
        ? SriLankaPhoneHelper.normalizeSriLankaPhoneForStorage(rawPhone)
        : rawPhone;

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

    final normalizedNic = nic?.trim().toUpperCase();
    if (normalizedNic != null && normalizedNic.isNotEmpty) {
      final nicExists = _sessionUsers.any(
        (u) =>
            u.nic != null &&
            u.nic!.trim().toLowerCase() == normalizedNic.toLowerCase(),
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
      vendorStatus:
          role == UserRole.vendor ? VendorStatus.pendingApproval : null,
      vendorApproved: role == UserRole.vendor ? false : null,
      vendorCategories: categories,
      verifiedPhone: verifiedPhone,
      verifiedEmail: verifiedEmail,
      detectedCountry: detectedCountry,
      detectionSource: detectionSource,
      riskFlag: riskFlag,
      nic: normalizedNic,
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
      assignedRadiusKm:
          role == UserRole.vendor ? AppConstants.defaultDeliveryRadius : null,
      commissionRate:
          role == UserRole.vendor ? AppConstants.defaultCommissionRate : null,
    );

    await _createFirebaseUser(resolvedEmail, password);
    // For customers: Firebase Phone Auth already created their account during
    // OTP verification — currentUser.uid is their real phone-linked UID.
    // For vendors: createUserWithEmailAndPassword sets currentUser.
    final firebaseUid = _firebaseAuth.currentUser?.uid;
    // Always use the Firebase Auth UID as the Firestore document ID so that
    // security rules (isOwner check) work correctly. Falling back to the
    // local generated id is only a last resort for offline scenarios.
    final userId = firebaseUid ?? newUser.id;
    final userWithFirebaseId = newUser.copyWith(id: userId);
    debugPrint('[Auth] Firebase user created, UID=$userId');
    _sessionUsers.add(userWithFirebaseId);
    _currentUserId = userId;
    await _syncUserToFirestore(userWithFirebaseId);
    // Persist to local index so duplicate checks work offline on this device.
    await StorageService.addToRegistrationIndex(
      email: resolvedEmail,
      phone: normalizedPhone,
      nic: normalizedNic,
    );

    debugPrint('[Auth] Registration saved: email=$resolvedEmail, id=$userId');

    _currentToken =
        'auth_token_${userId}_${DateTime.now().millisecondsSinceEpoch}';
    _currentUserId = userId;
    _uploadDeviceTokenForUser(userWithFirebaseId);
    
    final updatedUser = await _recordSession(userWithFirebaseId);
    return (user: updatedUser, token: _currentToken!);
  }

  // Best-effort upload of device FCM token to backend. No-op if backend URL not configured.
  static const String _backendBaseUrl = '';

  Future<void> _uploadDeviceTokenForUser(UserModel user,
      {String? token}) async {
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
        debugPrint(
            '[Auth] No logged-in user; skipping token upload on refresh');
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
  Future<void> logout({bool keepFirebaseSession = false}) async {
    if (!keepFirebaseSession) {
      try {
        await _firebaseAuth.signOut();
      } catch (e) {
        debugPrint('[Auth] Firebase sign out error (non-fatal): $e');
      }
    }
    await Future.delayed(const Duration(milliseconds: 300));
    _currentToken = null;
    _currentUserId = null;
  }

  // ── Restore session ────────────────────────────────────────────────────────
  Future<UserModel?> restoreSession(String token) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 500));
    // Restore anonymous session for customers on app restart
    if (_firebaseAuth.currentUser == null) {
      try {
        await _firebaseAuth.signInAnonymously();
      } catch (e) {
        debugPrint('[Auth] Anonymous sign-in on restore failed (non-fatal): $e');
      }
    }
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
      debugPrint(
          '[VendorStatusFix] Suspend vendor before: status=${vendor.vendorStatus}, isActive=${vendor.isActive}, approved=${vendor.vendorApproved}');

      _sessionUsers[index] = vendor.copyWith(
        vendorStatus: VendorStatus.suspended,
        isActive: false,
        vendorApproved: true, // Keep approval status
      );

      debugPrint(
          '[VendorStatusFix] Suspend vendor after: status=${_sessionUsers[index].vendorStatus}, isActive=${_sessionUsers[index].isActive}, approved=${_sessionUsers[index].vendorApproved}');
      await _persistUsers();
      debugPrint(
          '[VendorStatusFix] Persisted vendorStatus: ${_sessionUsers[index].vendorStatus}');
    }
  }

  Future<void> toggleUserActive(String userId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _sessionUsers.indexWhere((u) => u.id == userId);
    if (index != -1) {
      final user = _sessionUsers[index];
      final newIsActive = !user.isActive;

      debugPrint(
          '[VendorStatusFix] Toggle before: status=${user.vendorStatus}, isActive=${user.isActive}, approved=${user.vendorApproved}');

      // If activating a suspended vendor, restore approved status
      if (newIsActive && user.vendorStatus == VendorStatus.suspended) {
        _sessionUsers[index] = user.copyWith(
          vendorStatus: VendorStatus.approved,
          isActive: true,
          vendorApproved: true,
        );
        debugPrint(
            '[VendorStatusFix] Activate vendor after: status=${_sessionUsers[index].vendorStatus}, isActive=${_sessionUsers[index].isActive}, approved=${_sessionUsers[index].vendorApproved}');
      } else if (!newIsActive && user.role == UserRole.vendor) {
        // If deactivating, set to suspended
        _sessionUsers[index] = user.copyWith(
          vendorStatus: VendorStatus.suspended,
          isActive: false,
          vendorApproved: true,
        );
        debugPrint(
            '[VendorStatusFix] Suspend vendor after: status=${_sessionUsers[index].vendorStatus}, isActive=${_sessionUsers[index].isActive}, approved=${_sessionUsers[index].vendorApproved}');
      } else {
        // For non-vendors, just toggle isActive
        _sessionUsers[index] = user.copyWith(
          isActive: newIsActive,
        );
        debugPrint(
            '[VendorStatusFix] Toggle after: isActive=${_sessionUsers[index].isActive}');
      }

      await _persistUsers();
      debugPrint(
          '[VendorStatusFix] Persisted vendorStatus: ${_sessionUsers[index].vendorStatus}');
    }
  }

  // ── Vendor Credential Check (without authenticating) ─────────────────────

  /// Verifies vendor credentials without setting auth state.
  /// Returns the matched user if credentials are valid.
  Future<({UserModel user, String phone})> verifyVendorCredentials({
    required String email,
    required String password,
  }) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 1200));

    // Sign in first, then fetch the vendor doc
    await _signInWithFirebase(email, password);
    final fetchedUser = await _fetchUserByEmail(email, UserRole.vendor);
    if (fetchedUser == null) {
      await _firebaseAuth.signOut();
      throw Exception('No vendor account found with this email.');
    }

    final index = _sessionUsers.indexWhere((u) => u.id == fetchedUser.id);
    if (index >= 0) {
      _sessionUsers[index] = fetchedUser;
    } else {
      _sessionUsers.add(fetchedUser);
    }

    if (!fetchedUser.isActive) {
      throw Exception('Your account has been suspended. Contact support.');
    }

    return (user: fetchedUser, phone: fetchedUser.phone);
  }

  // ── Password Reset ──────────────────────────────────────────────────────

  /// Returns null — passwords are now managed entirely by Firebase Auth.
  Future<String?> getVendorPassword(String email) async => null;

  /// Checks if a vendor with [email] exists and returns a mock OTP.
  Future<String> generateResetOtp(String email) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 800));
    // Check cache first, then query Firestore anonymously (vendors collection is readable when signed in)
    final inCache = _sessionUsers.any(
      (u) =>
          u.role == UserRole.vendor &&
          u.email.toLowerCase() == email.toLowerCase().trim(),
    );
    if (!inCache) {
      // Try Firestore directly — will only work if already signed in
      final fetched = await _fetchUserByEmail(email, UserRole.vendor);
      if (fetched == null)
        throw Exception('No vendor account found with this email.');
    }
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
      (u) =>
          u.role == UserRole.vendor && u.email.toLowerCase() == normalizedEmail,
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
      debugPrint(
          '[CommissionAudit] Vendor $vendorId commission set to ${rate == null ? 'default (0%)' : '${(rate * 100).toStringAsFixed(2)}%'}');
    }
  }

  /// Fetches the vendor's Firestore doc and refreshes the in-memory user.
  /// Returns the refreshed user, or null if not found.
  Future<UserModel?> refreshVendorStatus(String vendorId) async {
    try {
      final doc = await FirestoreService.collection('users/vendors/profiles')
          .doc(vendorId)
          .get();
      if (!doc.exists) return null;
      final user = UserModel.fromJson({...doc.data()!, 'id': doc.id});
      final index = _sessionUsers.indexWhere((u) => u.id == vendorId);
      if (index != -1) {
        _sessionUsers[index] = user;
      } else {
        _sessionUsers.add(user);
      }
      return user;
    } catch (e) {
      debugPrint('[Auth] refreshVendorStatus error: $e');
      return null;
    }
  }

  Future<void> deleteStaleDoc(
      {required UserRole role, required String docId}) async {
    try {
      await _collectionForRole(role).doc(docId).delete();
      debugPrint('[Auth] Deleted stale doc $docId');
    } catch (e) {
      debugPrint('[Auth] Could not delete stale doc $docId: $e');
    }
  }

  Future<UserModel> updateUser(UserModel user) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 500));

    debugPrint('[CategoryAudit] ===== REPOSITORY UPDATE START =====');
    debugPrint('[CategoryAudit] updateUser called for userId: ${user.id}');
    debugPrint(
        '[CategoryAudit] user.allowedCategories being saved: ${user.allowedCategories}');
    debugPrint(
        '[CategoryAudit] user.vendorCategories: ${user.vendorCategories}');

    // Update in-memory cache so duplicate checks reflect the new phone/email.
    final index = _sessionUsers.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _sessionUsers[index] = user;
    } else {
      _sessionUsers.add(user);
    }

    await _syncUserToFirestore(user);
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
      debugPrint(
          '[CategorySync] ===== BATCH UPDATE COMPLETE: ${users.length} users persisted =====');
    } catch (e) {
      debugPrint('[CategorySync] ERROR in batch update: $e');
      rethrow;
    }
  }
}
