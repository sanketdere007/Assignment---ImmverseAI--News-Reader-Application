import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_router.dart';
import '../../../bookmarks/presentation/providers/bookmarks_provider.dart';

/// Settings section providing direct navigation to saved bookmarks with live count.
class BookmarksSection extends ConsumerWidget {
  const BookmarksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bookmarkCount = ref.watch(bookmarksCountProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Reading List',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            key: const Key('settings_bookmarks_tile'),
            leading: Icon(
              Icons.bookmark_outline_rounded,
              color: colorScheme.primary,
            ),
            title: const Text(
              'Offline Bookmarks',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              bookmarkCount > 0
                  ? '$bookmarkCount saved article${bookmarkCount == 1 ? '' : 's'} available offline'
                  : 'No saved articles yet. Bookmark news to read offline.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRouter.bookmarksPath),
          ),
        ],
      ),
    );
  }
}
