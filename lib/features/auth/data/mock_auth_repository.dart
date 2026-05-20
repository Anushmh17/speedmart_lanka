import '../../../shared/models/user_model.dart';
import '../../../shared/models/user_role.dart';

/// Mock authentication repository.
/// Replace the method bodies with real API calls (Dio) when backend is ready.
/// The interface stays the same — no other files need to change.
class MockAuthRepository {
  MockAuthRepository._();
  static final MockAuthRepository instance = MockAuthRepository._();

  // ── Hardcoded mock users for development/testing ──────────────────────────
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

  // ── In-memory registered users (persist across screens in same session) ───
  final List<UserModel> _sessionUsers = List.from(_mockUsers);
  String? _currentToken;

  // ── Login ──────────────────────────────────────────────────────────────────
  /// Returns [UserModel] on success, throws [Exception] on failure.
  Future<({UserModel user, String token})> login({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1200));

    final match = _sessionUsers.where(
      (u) =>
          u.email.toLowerCase() == email.toLowerCase() &&
          u.role == role,
    );

    if (match.isEmpty) {
      throw Exception('No account found with this email for the selected role.');
    }

    // In mock mode, any password works for existing users
    final user = match.first;
    if (!user.isActive) {
      throw Exception('Your account has been suspended. Contact support.');
    }

    _currentToken = 'mock_token_${user.id}_${DateTime.now().millisecondsSinceEpoch}';
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
  }) async {
    await Future.delayed(const Duration(milliseconds: 1500));

    // Check duplicate email
    final exists = _sessionUsers.any(
      (u) => u.email.toLowerCase() == email.toLowerCase(),
    );
    if (exists) {
      throw Exception('An account with this email already exists.');
    }

    final newUser = UserModel(
      id: '${role.name}-${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName,
      email: email,
      phone: phone,
      role: role,
      isActive: true,
      isVerified: role != UserRole.vendor, // vendors need admin verification
      createdAt: DateTime.now(),
      businessName: businessName,
      vendorApproved: role == UserRole.vendor ? false : null,
      vendorCategories: categories,
    );

    _sessionUsers.add(newUser);
    _currentToken = 'mock_token_${newUser.id}_${DateTime.now().millisecondsSinceEpoch}';
    return (user: newUser, token: _currentToken!);
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentToken = null;
  }

  // ── Restore session ────────────────────────────────────────────────────────
  Future<UserModel?> restoreSession(String token) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // In mock mode, decode user ID from token format: mock_token_{id}_{ts}
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
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_sessionUsers);
  }

  Future<void> approveVendor(String vendorId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final index = _sessionUsers.indexWhere((u) => u.id == vendorId);
    if (index != -1) {
      _sessionUsers[index] = _sessionUsers[index].copyWith(
        vendorApproved: true,
        isVerified: true,
      );
    }
  }

  Future<void> toggleUserActive(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _sessionUsers.indexWhere((u) => u.id == userId);
    if (index != -1) {
      _sessionUsers[index] = _sessionUsers[index].copyWith(
        isActive: !_sessionUsers[index].isActive,
      );
    }
  }

  Future<UserModel> updateUser(UserModel user) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _sessionUsers.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _sessionUsers[index] = user;
      return user;
    }
    throw Exception('User not found in session database.');
  }
}
