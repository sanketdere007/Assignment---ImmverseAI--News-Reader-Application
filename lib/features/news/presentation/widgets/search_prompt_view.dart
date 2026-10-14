import 'package:flutter/material.dart';

/// Helpful initial search state widget inviting the user to search articles.
class SearchPromptView extends StatelessWidget {
  final ValueChanged<String>? onSuggestionSelected;

  const SearchPromptView({
    super.key,
    this.onSuggestionSelected,
  });

  static const List<String> _popularSuggestions = [
    'Artificial Intelligence',
    'Technology',
    'Business',
    'Science',
    'Finance',
    'Climate Change',
    'Space Exploration',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      key: const Key('search_initial_prompt'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_rounded,
                size: 42,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Search QuickNews',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                'Enter keywords to discover news stories, topics, and breaking headlines from thousands of publishers.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Try searching for',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _popularSuggestions.map((suggestion) {
                return ActionChip(
                  key: Key('suggestion_chip_${suggestion.toLowerCase().replaceAll(' ', '_')}'),
                  label: Text(suggestion),
                  avatar: const Icon(Icons.trending_up, size: 16),
                  backgroundColor: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  onPressed: () {
                    onSuggestionSelected?.call(suggestion);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
