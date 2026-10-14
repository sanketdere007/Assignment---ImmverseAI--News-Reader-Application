import 'package:flutter/material.dart';

/// Descriptor for news category tabs.
class NewsCategoryItem {
  final String id;
  final String label;
  final IconData icon;

  const NewsCategoryItem({
    required this.id,
    required this.label,
    required this.icon,
  });
}

/// Horizontally scrollable category selector bar adhering to Material 3 tokens.
class CategorySelector extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const CategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  /// The official categories supported by NewsAPI.
  static const List<NewsCategoryItem> categories = [
    NewsCategoryItem(id: 'general', label: 'General', icon: Icons.public),
    NewsCategoryItem(id: 'business', label: 'Business', icon: Icons.trending_up),
    NewsCategoryItem(id: 'technology', label: 'Technology', icon: Icons.memory),
    NewsCategoryItem(id: 'entertainment', label: 'Entertainment', icon: Icons.movie_outlined),
    NewsCategoryItem(id: 'health', label: 'Health', icon: Icons.favorite_outline),
    NewsCategoryItem(id: 'science', label: 'Science', icon: Icons.science_outlined),
    NewsCategoryItem(id: 'sports', label: 'Sports', icon: Icons.sports_soccer),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected =
              category.id.toLowerCase() == selectedCategory.toLowerCase();

          return FilterChip(
            key: Key('category_chip_${category.id}'),
            selected: isSelected,
            showCheckmark: false,
            avatar: Icon(
              category.icon,
              size: 16,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
            label: Text(
              category.label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            backgroundColor: colorScheme.surfaceContainerLow,
            selectedColor: colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            onSelected: (_) {
              if (!isSelected) {
                onCategorySelected(category.id);
              }
            },
          );
        },
      ),
    );
  }
}
