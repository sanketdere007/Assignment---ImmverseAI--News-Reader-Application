import 'package:flutter/foundation.dart';
import '../../domain/entities/user_entity.dart';

/// Status states for authentication lifecycle.
enum AuthStatus {
  /// Session restoration in progress during application startup.
  initial,

  /// Active authentication request is running.
  authenticating,

  /// User has successfully authenticated.
  authenticated,

  /// No active authenticated session.
  unauthenticated,

  /// Authentication failed with an error message.
  failure,
}

/// Immutable state representing authentication status and current user.
@immutable
class AuthState {
  final AuthStatus status;
  final UserEntity? user;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);

  factory AuthState.unauthenticated([String? errorMessage]) => AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: errorMessage,
      );

  factory AuthState.authenticating() => const AuthState(
        status: AuthStatus.authenticating,
      );

  factory AuthState.authenticated(UserEntity user) => AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );

  factory AuthState.failure(String message) => AuthState(
        status: AuthStatus.failure,
        errorMessage: message,
      );

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading =>
      status == AuthStatus.authenticating || status == AuthStatus.initial;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          user == other.user &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(status, user, errorMessage);

  @override
  String toString() =>
      'AuthState(status: $status, user: ${user?.displayName}, error: $errorMessage)';
}
