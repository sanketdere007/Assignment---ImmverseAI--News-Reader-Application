import '../entities/user_entity.dart';

/// Contract defining authentication operations for QuickNews.
abstract class AuthRepository {
  /// Authenticates user with [email] and [password].
  ///
  /// When [rememberMe] is true, session information is persisted locally.
  Future<UserEntity> login({
    required String email,
    required String password,
    required bool rememberMe,
  });

  /// Restores a persisted session if one exists and Remember Me was enabled.
  ///
  /// Returns [UserEntity] if valid session exists, otherwise null.
  Future<UserEntity?> restoreSession();

  /// Clears the active session and removes persisted authentication data.
  Future<void> logout();
}
