import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/app/app.dart';
import 'package:quicknews/core/constants/app_constants.dart';
import 'package:quicknews/features/settings/presentation/providers/theme_mode_provider.dart';
import 'package:quicknews/features/settings/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Three Theme Modes and Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'HomeScreen does not display theme selection and provides Settings navigation',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: QuickNewsApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('QuickNews'), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsOneWidget);

        // Ensure no theme selection control on HomeScreen
        expect(find.byType(RadioListTile<ThemeMode>), findsNothing);
        expect(find.text('Appearance'), findsNothing);
        expect(find.text('Light Mode'), findsNothing);
        expect(find.text('Dark Mode'), findsNothing);
        expect(find.text('System Default'), findsNothing);
      },
    );

    testWidgets(
      'SettingsScreen displays Appearance section with three theme options',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Appearance'), findsOneWidget);

        // Three theme mode options
        expect(find.text('Light Mode'), findsOneWidget);
        expect(find.text('Dark Mode'), findsOneWidget);
        expect(find.text('System Default'), findsOneWidget);

        // Suitable icons
        expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
        expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
        expect(find.byIcon(Icons.brightness_auto_outlined), findsOneWidget);

        // Exactly three RadioListTile widgets
        expect(find.byType(RadioListTile<ThemeMode>), findsNWidgets(3));
      },
    );

    testWidgets(
      'Switching theme persists value to SharedPreferences and updates state',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: const MaterialApp(
              home: SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initially defaults to system
        RadioListTile<ThemeMode> systemTile = tester.widget(
          find.byKey(const Key('theme_option_system')),
        );
        expect(systemTile.groupValue, ThemeMode.system);

        // 2. Select Dark Mode
        await tester.tap(find.byKey(const Key('theme_option_dark')));
        await tester.pumpAndSettle();

        RadioListTile<ThemeMode> darkTile = tester.widget(
          find.byKey(const Key('theme_option_dark')),
        );
        expect(darkTile.groupValue, ThemeMode.dark);
        expect(prefs.getString(AppConstants.themeModeStorageKey), 'dark');

        // 3. Select Light Mode
        await tester.tap(find.byKey(const Key('theme_option_light')));
        await tester.pumpAndSettle();

        RadioListTile<ThemeMode> lightTile = tester.widget(
          find.byKey(const Key('theme_option_light')),
        );
        expect(lightTile.groupValue, ThemeMode.light);
        expect(prefs.getString(AppConstants.themeModeStorageKey), 'light');

        // 4. Select System Default
        await tester.tap(find.byKey(const Key('theme_option_system')));
        await tester.pumpAndSettle();

        systemTile = tester.widget(
          find.byKey(const Key('theme_option_system')),
        );
        expect(systemTile.groupValue, ThemeMode.system);
        expect(prefs.getString(AppConstants.themeModeStorageKey), 'system');
      },
    );

    testWidgets(
      'Loads saved theme on startup without flash',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          AppConstants.themeModeStorageKey: 'dark',
        });
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: const QuickNewsApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to settings to inspect radio state
        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();

        final darkTile = tester.widget<RadioListTile<ThemeMode>>(
          find.byKey(const Key('theme_option_dark')),
        );
        expect(darkTile.groupValue, ThemeMode.dark);
      },
    );

    test('Helper parseThemeMode handles invalid/missing values safely', () {
      expect(ThemeModeNotifier.parseThemeMode(null), ThemeMode.system);
      expect(ThemeModeNotifier.parseThemeMode(''), ThemeMode.system);
      expect(ThemeModeNotifier.parseThemeMode('unknown'), ThemeMode.system);
      expect(ThemeModeNotifier.parseThemeMode('light'), ThemeMode.light);
      expect(ThemeModeNotifier.parseThemeMode('LIGHT '), ThemeMode.light);
      expect(ThemeModeNotifier.parseThemeMode('dark'), ThemeMode.dark);
      expect(ThemeModeNotifier.parseThemeMode('system'), ThemeMode.system);
    });

    test('Helper themeModeToString serializes correctly', () {
      expect(ThemeModeNotifier.themeModeToString(ThemeMode.light), 'light');
      expect(ThemeModeNotifier.themeModeToString(ThemeMode.dark), 'dark');
      expect(ThemeModeNotifier.themeModeToString(ThemeMode.system), 'system');
    });
  });
}
