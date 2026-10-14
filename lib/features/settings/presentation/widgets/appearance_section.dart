import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_mode_provider.dart';

/// Clean Material Design 3 appearance section allowing selection between
/// Light Mode, Dark Mode, and System Default with persistent storage.
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          const Divider(height: 1),
          RadioListTile<ThemeMode>(
            key: const Key('theme_option_light'),
            secondary: const Icon(Icons.light_mode_outlined),
            title: const Text('Light Mode'),
            subtitle: const Text('Always use light theme'),
            value: ThemeMode.light,
            groupValue: themeMode,
            onChanged: (ThemeMode? value) {
              if (value != null) {
                ref.read(themeModeProvider.notifier).setThemeMode(value);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            key: const Key('theme_option_dark'),
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            subtitle: const Text('Always use dark theme'),
            value: ThemeMode.dark,
            groupValue: themeMode,
            onChanged: (ThemeMode? value) {
              if (value != null) {
                ref.read(themeModeProvider.notifier).setThemeMode(value);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            key: const Key('theme_option_system'),
            secondary: const Icon(Icons.brightness_auto_outlined),
            title: const Text('System Default'),
            subtitle: const Text('Follow system brightness setting'),
            value: ThemeMode.system,
            groupValue: themeMode,
            onChanged: (ThemeMode? value) {
              if (value != null) {
                ref.read(themeModeProvider.notifier).setThemeMode(value);
              }
            },
          ),
        ],
      ),
    );
  }
}
