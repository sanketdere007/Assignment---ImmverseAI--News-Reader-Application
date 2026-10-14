import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quicknews/app/router/app_router.dart';
import 'package:quicknews/features/auth/data/datasources/mock_auth_remote_data_source.dart';
import 'package:quicknews/features/auth/domain/entities/user_entity.dart';
import 'package:quicknews/features/auth/presentation/providers/auth_provider.dart';
import 'package:quicknews/features/auth/presentation/providers/auth_state.dart';
import 'package:quicknews/features/settings/presentation/providers/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildTestApp({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        mockAuthRemoteDataSourceProvider.overrideWithValue(
          const MockAuthRemoteDataSourceImpl(networkDelay: Duration.zero),
        ),
        ...overrides,
      ],
      child: Consumer(
        builder: (context, ref, child) {
          final router = ref.watch(routerProvider);
          return MaterialApp.router(
            routerConfig: router,
          );
        },
      ),
    );
  }

  group('Router Protected Navigation & Redirect Behavior', () {
    testWidgets('unauthenticated user is redirected to LoginScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      // Let splash and session restoration resolve to unauthenticated
      await tester.pumpAndSettle();

      // Should land on LoginScreen
      expect(find.text('Sign in to access your curated news feed and saved articles'), findsOneWidget);
      expect(find.byKey(const Key('login_button')), findsOneWidget);
    });

    testWidgets('authenticated user lands on HomeScreen and cannot see LoginScreen',
        (WidgetTester tester) async {
      // Create a test user
      const authenticatedUser = UserEntity(
        id: 'usr_test',
        email: 'reader@quicknews.com',
        displayName: 'Alex Reader',
        token: 'token_123',
      );

      await tester.pumpWidget(
        buildTestApp(
          overrides: [
            // Pre-authenticate authNotifierProvider
            authNotifierProvider.overrideWith(
              () => _StaticAuthNotifier(
                AuthState.authenticated(authenticatedUser),
              ),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Should be on HomeScreen
      expect(find.text('Welcome, Alex Reader!'), findsOneWidget);
      expect(find.byKey(const Key('home_settings_button')), findsOneWidget);
      // LoginScreen is not present
      expect(find.byKey(const Key('login_button')), findsNothing);
    });

    testWidgets('authenticated user can navigate to SettingsScreen and view profile',
        (WidgetTester tester) async {
      const authenticatedUser = UserEntity(
        id: 'usr_test',
        email: 'reader@quicknews.com',
        displayName: 'Alex Reader',
        token: 'token_123',
      );

      await tester.pumpWidget(
        buildTestApp(
          overrides: [
            authNotifierProvider.overrideWith(
              () => _StaticAuthNotifier(
                AuthState.authenticated(authenticatedUser),
              ),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to Settings
      await tester.tap(find.byKey(const Key('home_settings_button')));
      await tester.pumpAndSettle();

      // Should see SettingsScreen, user profile, and theme options
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Alex Reader'), findsOneWidget);
      expect(find.text('reader@quicknews.com'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.byKey(const Key('logout_list_tile')), findsOneWidget);
    });

    testWidgets('logout prompts confirmation and redirects to LoginScreen',
        (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mockAuthRemoteDataSourceProvider.overrideWithValue(
            const MockAuthRemoteDataSourceImpl(networkDelay: Duration.zero),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Pre-authenticate the container
      await container.read(authNotifierProvider.notifier).login(
            email: 'reader@quicknews.com',
            password: 'password123',
            rememberMe: false,
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, child) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(
                routerConfig: router,
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Welcome, Alex Reader!'), findsOneWidget);

      // Navigate to Settings
      await tester.tap(find.byKey(const Key('home_settings_button')));
      await tester.pumpAndSettle();

      // Tap Sign Out tile
      await tester.tap(find.byKey(const Key('logout_list_tile')));
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.byKey(const Key('confirm_logout_button')), findsOneWidget);
      expect(
        find.text(
          'Are you sure you want to sign out of QuickNews? '
          'Your theme and cached settings will be preserved.',
        ),
        findsOneWidget,
      );

      // Confirm sign out
      await tester.tap(find.byKey(const Key('confirm_logout_button')));
      await tester.pumpAndSettle();

      // Must be redirected to LoginScreen
      expect(find.byKey(const Key('login_button')), findsOneWidget);
      expect(find.text('Sign in to access your curated news feed and saved articles'), findsOneWidget);
    });
  });
}

/// Helper notifier for injecting static AuthState during router testing.
class _StaticAuthNotifier extends AuthNotifier {
  final AuthState _initialState;

  _StaticAuthNotifier(this._initialState);

  @override
  AuthState build() {
    return _initialState;
  }
}
