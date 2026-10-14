import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_router.dart';
import '../providers/news_feed_provider.dart';
import '../providers/news_feed_state.dart';
import '../widgets/category_selector.dart';
import '../widgets/news_article_card.dart';
import '../widgets/news_empty_view.dart';
import '../widgets/news_error_view.dart';
import '../widgets/news_loading_view.dart';
import '../widgets/search_prompt_view.dart';

/// Complete, responsive News Home Screen adhering to Material Design 3.
///
/// Features:
/// - Top headlines query with default country=us
/// - Categorized headline tabs
/// - Keyword search across `/everything` endpoint
/// - Pull-to-refresh
/// - Infinite scroll pagination
/// - Adaptive tablet/desktop responsive constraints
/// - Robust loading, empty, and error feedback states
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchActive = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Detects when the user approaches the bottom of the list and triggers pagination.
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Trigger next page when within 250 pixels of the scroll boundary
    if (currentScroll >= maxScroll - 250) {
      ref.read(newsFeedNotifierProvider.notifier).fetchNextPage();
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) {
      if (ref.read(newsFeedNotifierProvider).isSearching) {
        ref.read(newsFeedNotifierProvider.notifier).clearSearch();
      }
      setState(() {});
      return;
    }

    setState(() {});

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.read(newsFeedNotifierProvider.notifier).search(clean);
      }
    });
  }

  void _submitSearch(String query) {
    _debounceTimer?.cancel();
    final clean = query.trim();
    if (clean.isNotEmpty) {
      FocusScope.of(context).unfocus();
      ref.read(newsFeedNotifierProvider.notifier).search(clean);
    }
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _isSearchActive = false;
    });
    FocusScope.of(context).unfocus();
    ref.read(newsFeedNotifierProvider.notifier).clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final feedState = ref.watch(newsFeedNotifierProvider);
    final notifier = ref.read(newsFeedNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: _isSearchActive
            ? TextField(
                key: const Key('home_search_text_field'),
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search news...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                onSubmitted: _submitSearch,
                onChanged: _onSearchChanged,
              )
            : const Text(
                'News Reader',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
        elevation: 0,
        leading: _isSearchActive
            ? IconButton(
                key: const Key('close_search_button'),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to headlines',
                onPressed: _clearSearch,
              )
            : null,
        actions: [
          if (_isSearchActive) ...[
            IconButton(
              key: const Key('submit_search_button'),
              icon: const Icon(Icons.search),
              tooltip: 'Submit search',
              onPressed: () => _submitSearch(_searchController.text),
            ),
            IconButton(
              key: const Key('open_search_screen_button'),
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open full search',
              onPressed: () => context.push(AppRouter.searchPath),
            ),
            IconButton(
              key: const Key('clear_search_field_button'),
              icon: const Icon(Icons.close),
              tooltip: 'Clear',
              onPressed: _clearSearch,
            ),
          ] else ...[
            IconButton(
              key: const Key('home_search_button'),
              icon: const Icon(Icons.search),
              tooltip: 'Search news',
              onPressed: () {
                setState(() {
                  _isSearchActive = true;
                });
                _searchFocusNode.requestFocus();
              },
            ),
            IconButton(
              key: const Key('home_bookmarks_button'),
              icon: const Icon(Icons.bookmark_outline),
              tooltip: 'Bookmarks',
              onPressed: () => context.push(AppRouter.bookmarksPath),
            ),
            IconButton(
              key: const Key('home_settings_button'),
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => context.push(AppRouter.settingsPath),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Column(
              children: [
                // Active search banner or horizontal category bar
                if (feedState.isSearching)
                  Container(
                    key: const Key('active_search_banner'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Results for "${feedState.searchQuery}"',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('search_banner_clear_button'),
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Clear'),
                        ),
                      ],
                    ),
                  )
                else if (!_isSearchActive)
                  CategorySelector(
                    selectedCategory: feedState.selectedCategory,
                    onCategorySelected: (category) {
                      notifier.changeCategory(category);
                    },
                  ),

                // News Feed Body
                Expanded(
                  child: _isSearchActive
                      ? (_searchController.text.trim().isEmpty &&
                              !feedState.isSearching)
                          ? SearchPromptView(
                              onSuggestionSelected: (suggestion) {
                                _searchController.text = suggestion;
                                _submitSearch(suggestion);
                              },
                            )
                          : (feedState.isInitialLoading ||
                                  (!feedState.isSearching &&
                                      _searchController.text.trim().isNotEmpty))
                              ? const NewsLoadingView()
                              : _buildFeedBody(
                                  context,
                                  feedState,
                                  notifier,
                                  theme,
                                  colorScheme,
                                )
                      : _buildFeedBody(
                          context,
                          feedState,
                          notifier,
                          theme,
                          colorScheme,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Determines the active state representation (loading, error, empty, or article list).
  Widget _buildFeedBody(
    BuildContext context,
    NewsFeedState state,
    NewsFeedNotifier notifier,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    // 1. Initial Loading State
    if (state.isInitialLoading) {
      return const NewsLoadingView();
    }

    // 2. Initial Error State (Zero articles loaded)
    if (state.status == NewsFeedStatus.error && state.articles.isEmpty) {
      return NewsErrorView(
        errorMessage: state.errorMessage,
        onRetry: () {
          if (state.isSearching && state.searchQuery != null) {
            notifier.search(state.searchQuery!);
          } else if (_isSearchActive &&
              _searchController.text.trim().isNotEmpty) {
            notifier.search(_searchController.text.trim());
          } else {
            notifier.loadInitialHeadlines();
          }
        },
      );
    }

    // 3. Empty Results State
    if (state.status == NewsFeedStatus.empty && state.articles.isEmpty) {
      final categoryTitle = state.selectedCategory.isNotEmpty
          ? '${state.selectedCategory[0].toUpperCase()}${state.selectedCategory.substring(1)}'
          : 'Selected';
      final activeQuery = (state.isSearching && state.searchQuery != null)
          ? state.searchQuery!
          : (_isSearchActive ? _searchController.text.trim() : '');

      return NewsEmptyView(
        message: activeQuery.isNotEmpty
            ? 'No news articles found for "$activeQuery". Try different search terms.'
            : 'No articles currently available in $categoryTitle. Check back soon or refresh.',
        onRetry: () {
          if (activeQuery.isNotEmpty) {
            notifier.search(activeQuery);
          } else {
            notifier.loadInitialHeadlines();
          }
        },
      );
    }

    // 4. Articles List with Pull-To-Refresh and Infinite Scroll
    return RefreshIndicator(
      key: const Key('news_refresh_indicator'),
      onRefresh: () => notifier.refresh(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.articles.length +
            (state.isLoadingMore || state.paginationErrorMessage != null
                ? 1
                : 0),
        itemBuilder: (context, index) {
          // If we reached the footer slot
          if (index == state.articles.length) {
            if (state.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              );
            }

            if (state.paginationErrorMessage != null) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Card(
                  elevation: 0,
                  color: colorScheme.errorContainer.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            state.paginationErrorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('pagination_retry_button'),
                          onPressed: () => notifier.fetchNextPage(),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return const SizedBox.shrink();
          }

          final article = state.articles[index];
          final stableKey = article.url.isNotEmpty
              ? 'article_${article.url}'
              : 'article_${article.title}_$index';

          return NewsArticleCard(
            key: Key(stableKey),
            article: article,
            onTap: () {
              // Navigates to article detail with selected entity
              context.push(AppRouter.newsDetailPath, extra: article);
            },
          );
        },
      ),
    );
  }
}
