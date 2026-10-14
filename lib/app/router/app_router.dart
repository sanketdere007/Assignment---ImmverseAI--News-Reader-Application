import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/providers/auth_state.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/bookmarks/presentation/screens/bookmarks_screen.dart';
import '../../features/news/domain/entities/news_article.dart';
import '../../features/news/presentation/screens/home_screen.dart';
import '../../features/news/presentation/screens/news_detail_screen.dart';
import '../../features/news/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

/// Bridge notifier that triggers GoRouter redirects whenever [AuthState] changes.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authNotifierProvider,
      (_, __) => notifyListeners(),
    );
  }
}

/// Provider exposing the [RouterNotifier] listenable.
final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

/// Riverpod provider for [GoRouter] with protected navigation and session redirects.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: AppRouter.splashPath,
    refreshListenable: notifier,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authNotifierProvider);

      final isRestoring = authState.status == AuthStatus.initial;
      final isAuthenticated = authState.status == AuthStatus.authenticated;
      final isAuthenticating = authState.status == AuthStatus.authenticating;

      final matchedLocation = state.matchedLocation;
      final isLogin = matchedLocation == AppRouter.loginPath;
      final isSplash = matchedLocation == AppRouter.splashPath;

      // 1. Session restoration in progress: remain on or redirect to splash
      if (isRestoring) {
        return isSplash ? null : AppRouter.splashPath;
      }

      // 2. Unauthenticated user: force login (unless currently authenticating or on login)
      if (!isAuthenticated && !isAuthenticating) {
        return isLogin ? null : AppRouter.loginPath;
      }

      // 3. Authenticated user visiting login or splash: redirect to home
      if (isAuthenticated && (isLogin || isSplash)) {
        return AppRouter.homePath;
      }

      // 4. Default: allow requested location
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRouter.splashPath,
        name: 'splash',
        builder: (BuildContext context, GoRouterState state) =>
            const SplashScreen(),
      ),
      GoRoute(
        path: AppRouter.homePath,
        name: 'home',
        builder: (BuildContext context, GoRouterState state) =>
            const HomeScreen(),
      ),
      GoRoute(
        path: AppRouter.loginPath,
        name: 'login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: AppRouter.newsDetailPath,
        name: 'newsDetail',
        builder: (BuildContext context, GoRouterState state) =>
            NewsDetailScreen(article: state.extra as NewsArticle?),
      ),
      GoRoute(
        path: AppRouter.searchPath,
        name: 'search',
        builder: (BuildContext context, GoRouterState state) =>
            const SearchScreen(),
      ),
      GoRoute(
        path: AppRouter.bookmarksPath,
        name: 'bookmarks',
        builder: (BuildContext context, GoRouterState state) =>
            const BookmarksScreen(),
      ),
      GoRoute(
        path: AppRouter.settingsPath,
        name: 'settings',
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      appBar: AppBar(
        title: const Text('Page Not Found'),
      ),
      body: Center(
        child: Text(
          'No route configured for: ${state.uri.toString()}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    ),
  );
});

/// Application route path constants.
abstract final class AppRouter {
  static const String splashPath = '/splash';
  static const String homePath = '/';
  static const String loginPath = '/login';
  static const String searchPath = '/search';
  static const String newsDetailPath = '/news-detail';
  static const String bookmarksPath = '/bookmarks';
  static const String settingsPath = '/settings';
}
