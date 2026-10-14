import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Use case for authenticating with email and password.
class LoginUseCase {
  final AuthRepository _repository;

  const LoginUseCase(this._repository);

  Future<UserEntity> call({
    required String email,
    required String password,
    required bool rememberMe,
  }) {
    return _repository.login(
      email: email,
      password: password,
      rememberMe: rememberMe,
    );
  }
}
