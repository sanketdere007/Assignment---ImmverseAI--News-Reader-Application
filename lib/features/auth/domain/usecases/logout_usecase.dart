import '../repositories/auth_repository.dart';

/// Use case for logging out and clearing user session data.
class LogoutUseCase {
  final AuthRepository _repository;

  const LogoutUseCase(this._repository);

  Future<void> call() {
    return _repository.logout();
  }
}
