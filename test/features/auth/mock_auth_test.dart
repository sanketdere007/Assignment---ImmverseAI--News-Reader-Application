import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/core/constants/app_constants.dart';
import 'package:quicknews/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:quicknews/features/auth/data/datasources/mock_auth_remote_data_source.dart';
import 'package:quicknews/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:quicknews/features/auth/domain/entities/user_entity.dart';
import 'package:quicknews/features/auth/presentation/providers/auth_provider.dart';
import 'package:quicknews/features/auth/presentation/providers/auth_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../lib/features/settings/presentation/providers/theme_mode_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRemoteDataSource remoteDataSource;
  late SharedPreferences prefs;
  late AuthLocalDataSource localDataSource;
  late AuthRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    remoteDataSource = const MockAuthRemoteDataSourceImpl(
      networkDelay: Duration.zero,
    );
    localDataSource = AuthLocalDataSourceImpl(prefs: prefs);
    repository = AuthRepositoryImpl(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
    );
  });

  group('MockAuthRemoteDataSource', () {
    test('authenticates successfully with valid demo credentials', () async {
      final user = await remoteDataSource.authenticate(
        email: 'reader@quicknews.com',
        password: 'password123',
      );

      expect(user.id, MockAuthRemoteDataSourceImpl.demoUserId);
      expect(user.email, MockAuthRemoteDataSourceImpl.demoEmail);
      expect(user.displayName, MockAuthRemoteDataSourceImpl.demoDisplayName);
      expect(user.token, MockAuthRemoteDataSourceImpl.demoToken);
    });

    test('authenticates successfully ignoring case and leading/trailing whitespace in email', () async {
      final user = await remoteDataSource.authenticate(
        email: '  READER@QuickNews.COM  ',
        password: 'password123',
      );

      expect(user.email, MockAuthRemoteDataSourceImpl.demoEmail);
    });

    test('throws AuthException when given invalid password', () async {
      expect(
        () => remoteDataSource.authenticate(
          email: 'reader@quicknews.com',
          password: 'wrongpassword',
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Invalid email or password. Please try again.',
          ),
        ),
      );
    });

    test('throws AuthException when given unknown email', () async {
      expect(
        () => remoteDataSource.authenticate(
          email: 'unknown@example.com',
          password: 'password123',
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Invalid email or password. Please try again.',
          ),
        ),
      );
    });
  });

  group('AuthLocalDataSource - Session Persistence', () {
    const testUser = UserEntity(
      id: 'usr_test_1',
      email: 'test@example.com',
      displayName: 'Test User',
      token: 'jwt_mock_token_123',
    );

    test('saves session indicators correctly', () async {
      await localDataSource.saveSession(testUser);

      expect(prefs.getBool(AuthStorageKeys.rememberMe), isTrue);
      expect(
        prefs.getString(AuthStorageKeys.sessionToken),
        'jwt_mock_token_123',
      );
      expect(prefs.getString(AuthStorageKeys.userId), 'usr_test_1');
      expect(prefs.getString(AuthStorageKeys.userEmail), 'test@example.com');
      expect(
        prefs.getString(AuthStorageKeys.userDisplayName),
        'Test User',
      );
    });

    test('restores session when Remember Me was true', () async {
      await localDataSource.saveSession(testUser);

      final restored = await localDataSource.restoreSession();
      expect(restored, isNotNull);
      expect(restored!.id, testUser.id);
      expect(restored.email, testUser.email);
      expect(restored.token, testUser.token);
    });

    test('does NOT restore session when Remember Me was false or not set',
        () async {
      // Simulate session token saved without rememberMe flag
      await prefs.setString(AuthStorageKeys.sessionToken, 'jwt_mock_token');
      await prefs.setString(AuthStorageKeys.userId, 'usr_test_1');
      await prefs.setString(AuthStorageKeys.userEmail, 'test@example.com');
      await prefs.setBool(AuthStorageKeys.rememberMe, false);

      final restored = await localDataSource.restoreSession();
      expect(restored, isNull);
    });

    test('does NOT treat saved email text alone as proof of authentication',
        () async {
      await prefs.setString(AuthStorageKeys.userEmail, 'reader@quicknews.com');
      await prefs.setBool(AuthStorageKeys.rememberMe, true);
      // Missing token and user id!

      final restored = await localDataSource.restoreSession();
      expect(restored, isNull);
    });

    test('clearSession removes all auth keys while preserving theme preference',
        () async {
      // Set a theme preference
      await prefs.setString(AppConstants.themeModeStorageKey, 'dark');

      // Save an auth session
      await localDataSource.saveSession(testUser);

      // Verify both exist
      expect(prefs.getString(AppConstants.themeModeStorageKey), 'dark');
      expect(prefs.getString(AuthStorageKeys.sessionToken), isNotNull);

      // Clear session
      await localDataSource.clearSession();

      // Auth keys removed
      expect(prefs.getString(AuthStorageKeys.sessionToken), isNull);
      expect(prefs.getString(AuthStorageKeys.userId), isNull);
      expect(prefs.getBool(AuthStorageKeys.rememberMe), isNull);

      // Theme mode is preserved!
      expect(prefs.getString(AppConstants.themeModeStorageKey), 'dark');
    });
  });

  group('AuthRepositoryImpl', () {
    test('login with rememberMe: true saves session', () async {
      final user = await repository.login(
        email: 'reader@quicknews.com',
        password: 'password123',
        rememberMe: true,
      );

      expect(user.email, 'reader@quicknews.com');
      expect(prefs.getBool(AuthStorageKeys.rememberMe), isTrue);
      expect(prefs.getString(AuthStorageKeys.sessionToken), isNotNull);
    });

    test('login with rememberMe: false does NOT persist session across restart',
        () async {
      final user = await repository.login(
        email: 'reader@quicknews.com',
        password: 'password123',
        rememberMe: false,
      );

      expect(user.email, 'reader@quicknews.com');
      expect(prefs.getBool(AuthStorageKeys.rememberMe), isNull);
      expect(prefs.getString(AuthStorageKeys.sessionToken), isNull);

      // Simulating app restart
      final restored = await repository.restoreSession();
      expect(restored, isNull);
    });

    test('logout clears persisted session', () async {
      await repository.login(
        email: 'reader@quicknews.com',
        password: 'password123',
        rememberMe: true,
      );
      expect(prefs.getString(AuthStorageKeys.sessionToken), isNotNull);

      await repository.logout();
      expect(prefs.getString(AuthStorageKeys.sessionToken), isNull);

      final restored = await repository.restoreSession();
      expect(restored, isNull);
    });
  });

  group('AuthNotifier and State Lifecycle', () {
    test('successful login sets authenticated state', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mockAuthRemoteDataSourceProvider.overrideWithValue(
            const MockAuthRemoteDataSourceImpl(networkDelay: Duration.zero),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Initially initial/restoring, settles to unauthenticated
      await pumpEventQueue();

      final notifier = container.read(authNotifierProvider.notifier);
      final success = await notifier.login(
        email: 'reader@quicknews.com',
        password: 'password123',
        rememberMe: false,
      );

      expect(success, isTrue);
      final state = container.read(authNotifierProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user?.email, 'reader@quicknews.com');
      expect(state.isAuthenticated, isTrue);
    });

    test('invalid login sets failure state with clear error message', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mockAuthRemoteDataSourceProvider.overrideWithValue(
            const MockAuthRemoteDataSourceImpl(networkDelay: Duration.zero),
          ),
        ],
      );
      addTearDown(container.dispose);

      await pumpEventQueue();

      final notifier = container.read(authNotifierProvider.notifier);
      final success = await notifier.login(
        email: 'reader@quicknews.com',
        password: 'wrong_password',
        rememberMe: false,
      );

      expect(success, isFalse);
      final state = container.read(authNotifierProvider);
      expect(state.status, AuthStatus.failure);
      expect(
        state.errorMessage,
        'Invalid email or password. Please try again.',
      );
      expect(state.isAuthenticated, isFalse);
    });

    test('logout transitions state to unauthenticated', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mockAuthRemoteDataSourceProvider.overrideWithValue(
            const MockAuthRemoteDataSourceImpl(networkDelay: Duration.zero),
          ),
        ],
      );
      addTearDown(container.dispose);

      await pumpEventQueue();

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.login(
        email: 'reader@quicknews.com',
        password: 'password123',
        rememberMe: true,
      );
      expect(container.read(authNotifierProvider).isAuthenticated, isTrue);

      await notifier.logout();
      expect(
        container.read(authNotifierProvider).status,
        AuthStatus.unauthenticated,
      );
      expect(container.read(authNotifierProvider).user, isNull);
    });

    test('restores remembered session on startup', () async {
      // Pre-seed storage with a remembered session
      await localDataSource.saveSession(
        const UserEntity(
          id: 'usr_restored',
          email: 'restored@quicknews.com',
          displayName: 'Restored User',
          token: 'token_abc',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // Trigger build and wait for async session restore
      container.read(authNotifierProvider);
      await pumpEventQueue();

      final state = container.read(authNotifierProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user?.email, 'restored@quicknews.com');
      expect(state.user?.displayName, 'Restored User');
    });
  });
}
