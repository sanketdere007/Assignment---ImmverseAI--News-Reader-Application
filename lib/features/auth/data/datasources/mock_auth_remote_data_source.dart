import '../../domain/entities/user_entity.dart';

/// Exception thrown during authentication failures.
class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

/// Remote data source contract for mock authentication.
abstract class MockAuthRemoteDataSource {
  /// Authenticates user against mock credentials.
  Future<UserEntity> authenticate({
    required String email,
    required String password,
  });
}

/// Implementation providing isolated mock credentials for testing and evaluation.
class MockAuthRemoteDataSourceImpl implements MockAuthRemoteDataSource {
  /// Documented demo credentials for reviewer testing.
  static const String demoEmail = 'reader@quicknews.com';
  static const String demoPassword = 'password123';
  static const String demoDisplayName = 'Alex Reader';
  static const String demoUserId = 'usr_demo_42';
  static const String demoToken = 'mock_jwt_session_token_xyz987';

  final Duration networkDelay;

  const MockAuthRemoteDataSourceImpl({
    this.networkDelay = const Duration(milliseconds: 400),
  });

  @override
  Future<UserEntity> authenticate({
    required String email,
    required String password,
  }) async {
    if (networkDelay > Duration.zero) {
      await Future<void>.delayed(networkDelay);
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail == demoEmail.toLowerCase() &&
        password == demoPassword) {
      return const UserEntity(
        id: demoUserId,
        email: demoEmail,
        displayName: demoDisplayName,
        token: demoToken,
      );
    }

    throw const AuthException('Invalid email or password. Please try again.');
  }
}
