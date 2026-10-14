import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/mock_auth_remote_data_source.dart';

/// Implementation of [AuthRepository] coordinating remote mock authentication
/// and local session persistence.
class AuthRepositoryImpl implements AuthRepository {
  final MockAuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  const AuthRepositoryImpl({
    required MockAuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  @override
  Future<UserEntity> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final user = await _remoteDataSource.authenticate(
      email: email,
      password: password,
    );

    if (rememberMe) {
      await _localDataSource.saveSession(user);
    } else {
      // Remember Me disabled: ensure no previous session indicator remains on disk
      await _localDataSource.clearSession();
    }

    return user;
  }

  @override
  Future<UserEntity?> restoreSession() {
    return _localDataSource.restoreSession();
  }

  @override
  Future<void> logout() {
    return _localDataSource.clearSession();
  }
}
