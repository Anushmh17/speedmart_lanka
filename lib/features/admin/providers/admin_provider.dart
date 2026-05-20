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

  Future<void> approveVendor(String vendorId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authRepo.approveVendor(vendorId);
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
}

final adminProvider = StateNotifierProvider<AdminNotifier, AdminState>((ref) {
  return AdminNotifier();
});
