import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../settings/presentation/providers/theme_mode_provider.dart';
import '../../data/datasources/auth_local_data_source.dart';
import '../../data/datasources/mock_auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/restore_session_usecase.dart';
import 'auth_state.dart';

/// Provider for [MockAuthRemoteDataSource].
final mockAuthRemoteDataSourceProvider =
    Provider<MockAuthRemoteDataSource>((ref) {
  return const MockAuthRemoteDataSourceImpl();
});

/// Provider for [AuthLocalDataSource].
final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthLocalDataSourceImpl(prefs: prefs);
});

/// Provider for [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remote = ref.watch(mockAuthRemoteDataSourceProvider);
  final local = ref.watch(authLocalDataSourceProvider);
  return AuthRepositoryImpl(remoteDataSource: remote, localDataSource: local);
});

/// Provider for [LoginUseCase].
final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return LoginUseCase(repo);
});

/// Provider for [RestoreSessionUseCase].
final restoreSessionUseCaseProvider = Provider<RestoreSessionUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return RestoreSessionUseCase(repo);
});

/// Provider for [LogoutUseCase].
final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return LogoutUseCase(repo);
});

/// Riverpod Notifier managing authentication state and actions.
class AuthNotifier extends Notifier<AuthState> {
  late final LoginUseCase _loginUseCase;
  late final RestoreSessionUseCase _restoreSessionUseCase;
  late final LogoutUseCase _logoutUseCase;

  @override
  AuthState build() {
    _loginUseCase = ref.watch(loginUseCaseProvider);
    _restoreSessionUseCase = ref.watch(restoreSessionUseCaseProvider);
    _logoutUseCase = ref.watch(logoutUseCaseProvider);

    _restoreSession();
    return AuthState.initial();
  }

  Future<void> _restoreSession() async {
    try {
      final user = await _restoreSessionUseCase();
      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        state = AuthState.unauthenticated();
      }
    } catch (_) {
      state = AuthState.unauthenticated();
    }
  }

  /// Attempts mock login with validation and error handling.
  /// Prevents concurrent requests if already authenticating.
  Future<bool> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    if (state.status == AuthStatus.authenticating) {
      return false;
    }

    state = AuthState.authenticating();

    try {
      final user = await _loginUseCase(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );
      state = AuthState.authenticated(user);
      return true;
    } on AuthException catch (e) {
      state = AuthState.failure(e.message);
      return false;
    } catch (_) {
      state = AuthState.failure(
        'An unexpected error occurred. Please try again.',
      );
      return false;
    }
  }

  /// Logs out user, clears persisted session, and sets state to unauthenticated.
  Future<void> logout() async {
    try {
      await _logoutUseCase();
    } catch (_) {
      // Storage failure handled safely without leaving invalid auth state
    } finally {
      state = AuthState.unauthenticated();
    }
  }

  /// Clears any transient failure error message.
  void clearError() {
    if (state.status == AuthStatus.failure) {
      state = AuthState.unauthenticated();
    }
  }
}

/// Global provider for [AuthNotifier] and [AuthState].
final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
