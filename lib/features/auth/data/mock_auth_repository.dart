import '../../../core/storage/storage_service.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/models/user_role.dart';

/// Mock authentication repository.
/// Users and sessions are persisted locally until the backend API is ready.
/// TODO: Replace local mock auth persistence with backend API later.
class MockAuthRepository {
  MockAuthRepository._() {
    _initFuture = _initialize();
  }

  static final MockAuthRepository instance = MockAuthRepository._();

  late final Future<void> _initFuture;
  bool _isInitialized = false;

  // ── Seed users for development/testing ────────────────────────────────────
  static final List<UserModel> _mockUsers = [
    UserModel(
      id: 'cust-001',
      fullName: 'Amara Perera',
      email: 'customer@test.com',
      phone: '0771234567',
      role: UserRole.customer,
      isActive: true,
      isVerified: true,
      createdAt: DateTime(2025, 1, 15),
    ),
    UserModel(
      id: 'vend-001',
      fullName: 'Kamal Silva',
      email: 'vendor@test.com',
      phone: '0779876543',
      role: UserRole.vendor,
      isActive: true,
      isVerified: true,
      businessName: 'Silva Super Store',
      vendorApproved: true,
      vendorCategories: ['Groceries', 'Home Appliances'],
      createdAt: DateTime(2025, 2, 10),
    ),
    UserModel(
      id: 'vend-002',
      fullName: 'Nimal Fernando',
      email: 'vendor2@test.com',
      phone: '0761234567',
      role: UserRole.vendor,
      isActive: true,
      isVerified: false,
      businessName: 'Fernando Electronics',
      vendorApproved: false,
      vendorCategories: ['Electronics', 'Stationery'],
      createdAt: DateTime(2025, 3, 5),
    ),
    UserModel(
      id: 'admin-001',
      fullName: 'Admin User',
      email: 'admin@speedmart.lk',
      phone: '0112345678',
      role: UserRole.admin,
      isActive: true,
      isVerified: true,
      createdAt: DateTime(2024, 12, 1),
    ),
  ];

  final List<UserModel> _sessionUsers = [];
  String? _currentToken;

  /// Ensures saved users are loaded before auth operations.
  Future<void> ensureInitialized() => _initFuture;

  Future<void> _initialize() async {
    if (_isInitialized) return;

    _sessionUsers
      ..clear()
      ..addAll(_mockUsers);

    try {
      final savedJson = await StorageService.getRegisteredUsers();
      for (final json in savedJson) {
        final user = UserModel.fromJson(json);
        final index = _sessionUsers.indexWhere((u) => u.id == user.id);
        if (index >= 0) {
          _sessionUsers[index] = user;
        } else {
          _sessionUsers.add(user);
        }
      }
    } catch (_) {
      // Keep seed users if storage read fails.
    }

    _isInitialized = true;
  }

  Future<void> _persistUsers() async {
    // TODO: Replace with POST/PUT to backend user API.
    final payload = _sessionUsers.map((u) => u.toJson()).toList();
    await StorageService.saveRegisteredUsers(payload);
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

    final match = _sessionUsers.where(
      (u) =>
          u.email.toLowerCase() == email.toLowerCase() &&
          u.role == role,
    );

    if (match.isEmpty) {
      throw Exception('No account found with this email for the selected role.');
    }

    final user = match.first;
    if (!user.isActive) {
      throw Exception('Your account has been suspended. Contact support.');
    }

    _currentToken =
        'mock_token_${user.id}_${DateTime.now().millisecondsSinceEpoch}';
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

  Future<({UserModel user, String token})> loginCustomerOtp(String contact) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 1000));
    final isEmail = contact.contains('@');

    final match = _sessionUsers.where((u) {
      if (u.role != UserRole.customer) return false;
      if (isEmail) {
        return u.email.toLowerCase() == contact.toLowerCase().trim();
      }
      return _phoneMatches(contact, u.phone);
    });

    if (match.isEmpty) {
      throw Exception('No customer account found with this contact details.');
    }

    final user = match.first;
    if (!user.isActive) {
      throw Exception('Your account has been suspended. Contact support.');
    }

    _currentToken =
        'mock_token_${user.id}_${DateTime.now().millisecondsSinceEpoch}';
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
    );

    _sessionUsers.add(newUser);
    await _persistUsers();

    _currentToken =
        'mock_token_${newUser.id}_${DateTime.now().millisecondsSinceEpoch}';
    return (user: newUser, token: _currentToken!);
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentToken = null;
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

  Future<void> approveVendor(String vendorId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 400));
    final index = _sessionUsers.indexWhere((u) => u.id == vendorId);
    if (index != -1) {
      _sessionUsers[index] = _sessionUsers[index].copyWith(
        vendorApproved: true,
        isVerified: true,
      );
      await _persistUsers();
    }
  }

  Future<void> toggleUserActive(String userId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _sessionUsers.indexWhere((u) => u.id == userId);
    if (index != -1) {
      _sessionUsers[index] = _sessionUsers[index].copyWith(
        isActive: !_sessionUsers[index].isActive,
      );
      await _persistUsers();
    }
  }

  Future<UserModel> updateUser(UserModel user) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _sessionUsers.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _sessionUsers[index] = user;
    } else {
      _sessionUsers.add(user);
    }
    await _persistUsers();
    return user;
  }
}
