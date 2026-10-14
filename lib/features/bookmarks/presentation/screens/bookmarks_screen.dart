import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_router.dart';
import '../../../news/presentation/widgets/news_article_card.dart';
import '../../../news/presentation/widgets/news_error_view.dart';
import '../../../news/presentation/widgets/news_loading_view.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/bookmarks_state.dart';

/// Dedicated Material 3 Bookmarks Screen displaying saved articles for offline access.
///
/// Features:
/// - Immediate offline accessibility
/// - Synchronized bookmark removal with Undo capability
/// - Clean empty state with headline navigation prompt
/// - Pull-to-refresh to sync local box
/// - Clear all bookmarks confirmation dialog
class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Clear All Bookmarks?'),
          content: const Text(
            'Are you sure you want to remove all saved articles from your offline bookmarks?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('confirm_clear_bookmarks_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final success =
          await ref.read(bookmarksNotifierProvider.notifier).clearAllBookmarks();
      if (context.mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All bookmarks removed'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bookmarksState = ref.watch(bookmarksNotifierProvider);
    final notifier = ref.read(bookmarksNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bookmarks',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          if (bookmarksState.bookmarks.isNotEmpty)
            IconButton(
              key: const Key('clear_all_bookmarks_button'),
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all bookmarks',
              onPressed: () => _confirmClearAll(context, ref),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: _buildBody(context, ref, bookmarksState, notifier, theme, colorScheme),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    BookmarksState state,
    BookmarksNotifier notifier,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    // 1. Loading State (initial box load)
    if (state.isLoading && state.bookmarks.isEmpty) {
      return const NewsLoadingView();
    }

    // 2. Storage Error State
    if (state.errorMessage != null && state.bookmarks.isEmpty) {
      return NewsErrorView(
        errorMessage: state.errorMessage,
        onRetry: () => notifier.loadBookmarks(),
      );
    }

    // 3. Clean Empty State
    if (state.bookmarks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bookmark_border_rounded,
                  size: 38,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No bookmarks yet',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Articles you bookmark will be saved locally so you can read them anytime, even without an internet connection.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('explore_news_button'),
                icon: const Icon(Icons.newspaper_rounded, size: 18),
                label: const Text('Explore Headlines'),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRouter.homePath);
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    // 4. Saved Bookmarks List View
    final bookmarks = state.bookmarks;

    return RefreshIndicator(
      key: const Key('bookmarks_refresh_indicator'),
      onRefresh: () => notifier.loadBookmarks(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: bookmarks.length + 1, // Header + Items
        itemBuilder: (context, index) {
          if (index == 0) {
            // Header: Saved Articles count and offline status chip
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Saved Articles (${bookmarks.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.offline_pin_outlined,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Available Offline',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          final article = bookmarks[index - 1];
          final stableKey = article.url.isNotEmpty
              ? 'bookmark_card_${article.url}'
              : 'bookmark_card_${article.title}_$index';

          return NewsArticleCard(
            key: Key(stableKey),
            article: article,
            isBookmarked: true,
            onTap: () {
              context.push(AppRouter.newsDetailPath, extra: article);
            },
          );
        },
      ),
    );
  }
}
