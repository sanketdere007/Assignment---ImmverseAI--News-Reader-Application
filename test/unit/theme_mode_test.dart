import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/features/settings/presentation/providers/theme_mode_provider.dart';

void main() {
  group('ThemeModeNotifier Tests', () {
    test('initial state is ThemeMode.system', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('can toggle and set specific theme modes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(themeModeProvider.notifier);
      notifier.setLight();
      expect(container.read(themeModeProvider), ThemeMode.light);

      notifier.setDark();
      expect(container.read(themeModeProvider), ThemeMode.dark);

      notifier.toggleTheme();
      expect(container.read(themeModeProvider), ThemeMode.light);

      notifier.setSystem();
      expect(container.read(themeModeProvider), ThemeMode.system);
    });
  });
}
