import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/user_entity.dart';

/// SharedPreferences keys reserved exclusively for mock authentication session.
/// Kept strictly separate from theme preference and future news caching keys.
abstract final class AuthStorageKeys {
  static const String sessionToken = 'auth_session_token';
  static const String userId = 'auth_user_id';
  static const String userEmail = 'auth_user_email';
  static const String userDisplayName = 'auth_user_display_name';
  static const String rememberMe = 'auth_remember_me';
}

/// Local data source contract for managing persisted mock sessions.
abstract class AuthLocalDataSource {
  /// Persists session indicator and minimal non-sensitive user data.
  Future<void> saveSession(UserEntity user);

  /// Restores session if Remember Me was enabled and valid token exists.
  Future<UserEntity?> restoreSession();

  /// Clears only authentication session data from local storage.
  Future<void> clearSession();
}

/// Implementation of [AuthLocalDataSource] using [SharedPreferences].
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  SharedPreferences? _prefs;

  AuthLocalDataSourceImpl({SharedPreferences? prefs}) : _prefs = prefs;

  Future<SharedPreferences?> _getPrefs() async {
    if (_prefs != null) return _prefs;
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthLocalDataSource] SharedPreferences init error: $e');
      }
    }
    return _prefs;
  }

  @override
  Future<void> saveSession(UserEntity user) async {
    try {
      final prefs = await _getPrefs();
      if (prefs == null) return;

      // Passwords are NEVER persisted.
      if (user.token != null) {
        await prefs.setString(AuthStorageKeys.sessionToken, user.token!);
      }
      await prefs.setString(AuthStorageKeys.userId, user.id);
      await prefs.setString(AuthStorageKeys.userEmail, user.email);
      await prefs.setString(AuthStorageKeys.userDisplayName, user.displayName);
      await prefs.setBool(AuthStorageKeys.rememberMe, true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthLocalDataSource] Failed to save session: $e');
      }
    }
  }

  @override
  Future<UserEntity?> restoreSession() async {
    try {
      final prefs = await _getPrefs();
      if (prefs == null) return null;

      final isRemembered = prefs.getBool(AuthStorageKeys.rememberMe) ?? false;
      if (!isRemembered) {
        // Remember Me was disabled; do not restore session across restart
        return null;
      }

      final token = prefs.getString(AuthStorageKeys.sessionToken);
      final id = prefs.getString(AuthStorageKeys.userId);
      final email = prefs.getString(AuthStorageKeys.userEmail);
      final displayName = prefs.getString(AuthStorageKeys.userDisplayName);

      // Validate presence of required session indicators.
      // Saved email text alone is never treated as proof of authentication.
      if (token == null ||
          token.isEmpty ||
          id == null ||
          id.isEmpty ||
          email == null ||
          email.isEmpty) {
        return null;
      }

      return UserEntity(
        id: id,
        email: email,
        displayName: displayName ?? 'QuickNews Reader',
        token: token,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthLocalDataSource] Failed to restore session: $e');
      }
      return null;
    }
  }

  @override
  Future<void> clearSession() async {
    try {
      final prefs = await _getPrefs();
      if (prefs == null) return;

      // Selectively remove authentication keys; preserve theme and bookmarks
      await prefs.remove(AuthStorageKeys.sessionToken);
      await prefs.remove(AuthStorageKeys.userId);
      await prefs.remove(AuthStorageKeys.userEmail);
      await prefs.remove(AuthStorageKeys.userDisplayName);
      await prefs.remove(AuthStorageKeys.rememberMe);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthLocalDataSource] Failed to clear session: $e');
      }
    }
  }
}
