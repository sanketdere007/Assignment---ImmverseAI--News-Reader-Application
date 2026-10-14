import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../bookmarks/presentation/providers/bookmarks_provider.dart';
import '../../domain/entities/news_article.dart';

/// Material 3 news article card widget displaying headline, source, thumbnail, snippet,
/// and a synchronized bookmark toggle action.
class NewsArticleCard extends ConsumerWidget {
  final NewsArticle article;
  final VoidCallback? onTap;
  final VoidCallback? onBookmarkTap;
  final bool? isBookmarked;

  const NewsArticleCard({
    super.key,
    required this.article,
    this.onTap,
    this.onBookmarkTap,
    this.isBookmarked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final publishedDateStr = DateFormatter.formatPublishedDate(article.publishedAt);

    // Synchronize bookmark state efficiently with Riverpod selector
    final bool isSaved = isBookmarked == true ||
        (isBookmarked == null &&
            ref.watch(
                  bookmarksNotifierProvider.select<bool>(
                    (state) => state.isBookmarked(article.url),
                  ),
                ) ==
                true);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      color: colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Source Badge, Date, and Bookmark Action
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      article.sourceName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '•',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      publishedDateStr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    key: Key('bookmark_action_${article.url}'),
                    icon: Icon(
                      isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                    ),
                    iconSize: 22,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: isSaved ? 'Remove bookmark' : 'Save article',
                    color: isSaved
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    onPressed: onBookmarkTap ??
                        () {
                          ref
                              .read(bookmarksNotifierProvider.notifier)
                              .toggleBookmarkWithFeedback(context, article);
                        },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Content Row: Title + Description on left, Thumbnail on right
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (article.description != null &&
                            article.description!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            article.description!.trim(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Featured Image Thumbnail
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 90,
                      height: 90,
                      child: article.hasValidImage
                          ? Image.network(
                              article.urlToImage!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return _buildImagePlaceholder(colorScheme, isBusy: true);
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return _buildImagePlaceholder(colorScheme);
                              },
                            )
                          : _buildImagePlaceholder(colorScheme),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a themed placeholder when an image is unavailable, loading, or failed.
  Widget _buildImagePlaceholder(ColorScheme colorScheme, {bool isBusy = false}) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: isBusy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary.withValues(alpha: 0.6),
              ),
            )
          : Icon(
              Icons.newspaper_rounded,
              size: 32,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
    );
  }
}
