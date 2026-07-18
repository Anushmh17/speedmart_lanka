import '../../../shared/models/user_model.dart';

/// Represents the possible states of the authentication system.
/// Used by authProvider to drive UI and routing decisions.
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  /// Convenience: initial state before any auth check
  const AuthState.initial()
      : user = null,
        isLoading = true,
        error = null;

  /// Convenience: authenticated state
  const AuthState.authenticated(UserModel this.user)
      : isLoading = false,
        error = null;

  /// Convenience: unauthenticated state
  const AuthState.unauthenticated()
      : user = null,
        isLoading = false,
        error = null;

  /// Convenience: loading state
  const AuthState.loading()
      : user = null,
        isLoading = true,
        error = null;

  /// Convenience: error state
  AuthState.withError(String this.error)
      : user = null,
        isLoading = false;

  /// Copy with overrides
  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }

  bool get isAuthenticated => user != null;
  bool get hasError => error != null && error!.isNotEmpty;

  @override
  String toString() =>
      'AuthState(user: ${user?.email}, loading: $isLoading, error: $error)';
}

