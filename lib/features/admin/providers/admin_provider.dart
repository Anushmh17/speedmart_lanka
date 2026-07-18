import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/data/mock_auth_repository.dart';

class AdminState {
  final bool isLoading;
  final String? error;
  final List<UserModel> users;

  const AdminState({
    this.isLoading = false,
    this.error,
    this.users = const [],
  });

  AdminState copyWith({
    bool? isLoading,
    String? error,
    List<UserModel>? users,
    bool clearError = false,
  }) {
    return AdminState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      users: users ?? this.users,
    );
  }
}

class AdminNotifier extends StateNotifier<AdminState> {
  AdminNotifier() : super(const AdminState()) {
    _authRepo = MockAuthRepository.instance;
    loadAllUsers();
  }

  late final MockAuthRepository _authRepo;

  Future<void> loadAllUsers() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final users = await _authRepo.getAllUsers();
      state = state.copyWith(isLoading: false, users: users);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> approveVendor({required String vendorId, String? notes}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authRepo.approveVendor(vendorId, notes: notes);
      final users = await _authRepo.getAllUsers();
      state = state.copyWith(isLoading: false, users: users);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> rejectVendor({required String vendorId, required String reason}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authRepo.rejectVendor(vendorId, reason: reason);
      final users = await _authRepo.getAllUsers();
      state = state.copyWith(isLoading: false, users: users);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> suspendVendor({required String vendorId, required String reason}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authRepo.suspendVendor(vendorId, reason: reason);
      final users = await _authRepo.getAllUsers();
      state = state.copyWith(isLoading: false, users: users);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> toggleUserActive(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authRepo.toggleUserActive(userId);
      final users = await _authRepo.getAllUsers();
      state = state.copyWith(isLoading: false, users: users);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Sets a per-vendor commission rate. [rate] is 0.0–1.0 (e.g. 0.05 = 5%).
  /// Pass null to reset to platform default (0%).
  Future<void> updateVendorCommission(String vendorId, double? rate) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authRepo.updateVendorCommission(vendorId, rate);
      final users = await _authRepo.getAllUsers();
      state = state.copyWith(isLoading: false, users: users);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final adminProvider = StateNotifierProvider<AdminNotifier, AdminState>((ref) {
  return AdminNotifier();
});

/// Derived provider: returns a specific vendor's commission rate (0.0–1.0).
/// Falls back to 0.0 if the vendor is not found or has no custom rate set.
final vendorCommissionRateProvider = Provider.family<double, String>((ref, vendorId) {
  final users = ref.watch(adminProvider).users;
  try {
    final vendor = users.firstWhere((u) => u.id == vendorId);
    return vendor.commissionRate ?? 0.0;
  } catch (_) {
    return 0.0;
  }
});
