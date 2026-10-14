import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Centralized storage service foundation using Hive.
///
/// Ensures Hive is safely initialized once at application launch.
/// Prepares box name constants for future bookmarks and news caching.
///
/// NOTE: Passwords and sensitive session tokens must NEVER be stored in Hive.
/// Use FlutterSecureStorage for sensitive credentials.
///
/// Adapter Generation Note:
/// When domain model adapters (e.g., ArticleAdapter) are generated via `hive_generator`
/// in later steps, register them in [registerAdapters] before boxes are opened.
abstract final class StorageService {
  static bool _initialized = false;

  /// Reserved box name for saved user bookmarks.
  static const String bookmarksBox = 'bookmarks_box';

  /// Reserved box name for cached news articles and feed data.
  static const String newsCacheBox = 'news_cache_box';

  /// Reserved box name for user preferences (e.g. theme mode, category filters).
  static const String settingsBox = 'settings_box';

  /// Initializes Hive for Flutter. Safe to call multiple times; executes only once.
  static Future<void> init() async {
    if (_initialized) return;

    try {
      await Hive.initFlutter();
      registerAdapters();
      _initialized = true;
      if (kDebugMode) {
        debugPrint('[StorageService] Hive initialized successfully.');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[StorageService] Error initializing Hive: $e\n$stackTrace',
        );
      }
      rethrow;
    }
  }

  /// Hook to register generated Hive type adapters before boxes are opened.
  /// Adapters created via `hive_generator` will be registered here.
  static void registerAdapters() {
    // Generated Hive adapters will be registered here in future steps.
    // Example: Hive.registerAdapter(ArticleAdapter());
  }

  /// Whether Hive has been successfully initialized.
  static bool get isInitialized => _initialized;

  /// Allows unit and widget tests to configure initialization state.
  @visibleForTesting
  static void setInitializedForTesting([bool value = true]) {
    _initialized = value;
  }

  /// Safely opens and returns a Hive Box by name.
  static Future<Box<T>> openBox<T>(String boxName) async {
    if (!_initialized) {
      await init();
    }
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<T>(boxName);
    }
    return Hive.openBox<T>(boxName);
  }

  /// Cleans up and closes all open Hive boxes.
  static Future<void> closeAll() async {
    if (_initialized) {
      await Hive.close();
      _initialized = false;
    }
  }
}
