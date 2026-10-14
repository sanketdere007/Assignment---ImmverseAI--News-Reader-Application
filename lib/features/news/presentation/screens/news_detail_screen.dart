import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../bookmarks/presentation/providers/bookmarks_provider.dart';
import '../../domain/entities/news_article.dart';

/// News article detail screen presenting full headline content, publisher metadata,
/// cover imagery, and synchronized bookmark toggle controls.
class NewsDetailScreen extends ConsumerWidget {
  final NewsArticle? article;

  const NewsDetailScreen({
    super.key,
    this.article,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (article == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Article Detail'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 64,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Article Selected',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select an article from headlines or search to read its full details.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRouter.homePath);
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Headlines'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentArticle = article!;
    final bool isSaved = ref.watch(
          bookmarksNotifierProvider.select<bool>(
            (state) => state.isBookmarked(currentArticle.url),
          ),
        ) ==
        true;

    final publishedDateStr =
        DateFormatter.formatPublishedDate(currentArticle.publishedAt);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentArticle.sourceName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            key: const Key('detail_bookmark_button'),
            icon: Icon(
              isSaved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: isSaved ? colorScheme.primary : null,
            ),
            tooltip: isSaved ? 'Remove bookmark' : 'Bookmark article',
            onPressed: () {
              ref
                  .read(bookmarksNotifierProvider.notifier)
                  .toggleBookmarkWithFeedback(context, currentArticle);
            },
          ),
          IconButton(
            key: const Key('detail_share_button'),
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy article link',
            onPressed: () {
              if (currentArticle.url.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: currentArticle.url));
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Article link copied to clipboard'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Featured Cover Image
                  if (currentArticle.hasValidImage) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          currentArticle.urlToImage!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: colorScheme.surfaceContainerHighest,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(strokeWidth: 2.5),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: colorScheme.surfaceContainerHighest,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.image_not_supported_rounded,
                                size: 48,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Metadata Row: Source pill, date, author
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          currentArticle.sourceName,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '•',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        publishedDateStr,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (currentArticle.author != null &&
                          currentArticle.author!.trim().isNotEmpty) ...[
                        Text(
                          '•',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              currentArticle.author!.trim(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Headline Title
                  Text(
                    currentArticle.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Offline Saved Indicator Banner (when article is saved)
                  if (isSaved)
                    Container(
                      key: const Key('saved_offline_banner'),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.bookmark_added_rounded,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Saved offline in your bookmarks. Available anytime.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Divider(height: 24),

                  // Description / Summary
                  if (currentArticle.description != null &&
                      currentArticle.description!.trim().isNotEmpty) ...[
                    Text(
                      currentArticle.description!.trim(),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Content Body
                  if (currentArticle.content != null &&
                      currentArticle.content!.trim().isNotEmpty) ...[
                    Text(
                      currentArticle.content!.trim(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Source Web Link Box
                  if (currentArticle.url.isNotEmpty)
                    Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.link_rounded,
                                  size: 20,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Original Article Source',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              currentArticle.url,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              key: const Key('copy_url_button'),
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text('Copy Article Link'),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: currentArticle.url),
                                );
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Article link copied to clipboard'),
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
