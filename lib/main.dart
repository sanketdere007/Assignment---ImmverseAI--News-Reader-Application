import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'core/storage/storage_service.dart';
import 'features/settings/presentation/providers/theme_mode_provider.dart';

Future<void> main() async {
  // Ensure Flutter engine bindings are initialized first
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive local storage foundation
  await StorageService.init();

  // Initialize SharedPreferences for theme and key-value preferences
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[main] Error initializing SharedPreferences: $e');
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const QuickNewsApp(),
    ),
  );
}

/// Compatibility alias for default template references.
typedef MyApp = QuickNewsApp;
