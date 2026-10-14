import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_router.dart';
import '../providers/search_news_provider.dart';
import '../providers/search_news_state.dart';
import '../widgets/news_article_card.dart';
import '../widgets/news_empty_view.dart';
import '../widgets/news_error_view.dart';
import '../widgets/news_loading_view.dart';
import '../widgets/search_prompt_view.dart';

/// Dedicated Material 3 News Search Screen.
///
/// Features:
/// - Real-time and on-submit news search against NewsAPI `/everything`
/// - Helpful initial prompt state with suggestions
/// - Pull-to-refresh
/// - Infinite scroll pagination
/// - Responsive layout
/// - Clear (X) action
/// - Clean loading, empty, and detailed error states
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (currentScroll > 0 && currentScroll >= maxScroll - 250) {
      ref.read(searchNewsNotifierProvider.notifier).fetchNextPage();
    }
  }

  void _onSubmit(String query) {
    final clean = query.trim();
    if (clean.isNotEmpty) {
      _focusNode.unfocus();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      ref.read(searchNewsNotifierProvider.notifier).search(clean);
    }
  }

  void _onClear() {
    _searchController.clear();
    setState(() {});
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    ref.read(searchNewsNotifierProvider.notifier).clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final searchState = ref.watch(searchNewsNotifierProvider);
    final notifier = ref.read(searchNewsNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('search_back_button'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRouter.homePath);
            }
          },
        ),
        title: TextField(
          key: const Key('search_text_field'),
          controller: _searchController,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search news...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    key: const Key('search_clear_button'),
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Clear',
                    onPressed: _onClear,
                  )
                : null,
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: _onSubmit,
          onChanged: (val) {
            setState(() {});
            notifier.onQueryChanged(val);
          },
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: _buildSearchBody(
              context,
              searchState,
              notifier,
              theme,
              colorScheme,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBody(
    BuildContext context,
    SearchNewsState state,
    SearchNewsNotifier notifier,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    // 1. Initial State: Display prompt and search suggestions
    if (state.isInitial && _searchController.text.trim().isEmpty) {
      return SearchPromptView(
        onSuggestionSelected: (suggestion) {
          _searchController.text = suggestion;
          setState(() {});
          _onSubmit(suggestion);
        },
      );
    }

    // 2. Loading State: Display skeleton placeholders (including during typing debounce)
    if (state.isInitialLoading ||
        (state.isInitial && _searchController.text.trim().isNotEmpty)) {
      return const NewsLoadingView();
    }

    // 3. Error State: Display error feedback and retry action
    if (state.status == SearchStatus.error && state.articles.isEmpty) {
      return NewsErrorView(
        errorMessage: state.errorMessage,
        onRetry: () => _onSubmit(_searchController.text),
      );
    }

    // 4. Empty State: No articles found matching query
    if (state.status == SearchStatus.empty && state.articles.isEmpty) {
      return NewsEmptyView(
        message:
            'No news articles found for "${state.query}". Try searching for different keywords.',
        onRetry: () => _onSubmit(_searchController.text),
      );
    }

    // 5. Results List: Infinite scrolling and pull-to-refresh
    return RefreshIndicator(
      key: const Key('search_refresh_indicator'),
      onRefresh: () => notifier.refresh(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (scrollInfo.metrics.pixels > 0 &&
              scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 250) {
            notifier.fetchNextPage();
          }
          return false;
        },
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: state.articles.length +
              (state.isLoadingMore || state.paginationErrorMessage != null
                  ? 1
                  : 0),
          itemBuilder: (context, index) {
            // Pagination footer slot
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
                            key: const Key('search_pagination_retry_button'),
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
                ? 'search_article_${article.url}'
                : 'search_article_${article.title}_$index';

            return NewsArticleCard(
              key: Key(stableKey),
              article: article,
              onTap: () {
                context.push(AppRouter.newsDetailPath, extra: article);
              },
            );
          },
        ),
      ),
    );
  }
}
