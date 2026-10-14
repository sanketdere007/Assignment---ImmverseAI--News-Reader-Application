import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/app/theme/app_theme.dart';
import 'package:quicknews/core/widgets/app_empty_widget.dart';
import 'package:quicknews/core/widgets/app_error_widget.dart';
import 'package:quicknews/core/widgets/app_loading_indicator.dart';

void main() {
  group('Common Widgets Tests', () {
    testWidgets('AppLoadingIndicator renders message and progress indicator',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: AppLoadingIndicator(message: 'Loading articles...'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading articles...'), findsOneWidget);
    });

    testWidgets(
        'AppErrorWidget renders error message and handles retry callback',
        (WidgetTester tester) async {
      var retryClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: AppErrorWidget(
              message: 'Failed to fetch news feed.',
              onRetry: () => retryClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('Failed to fetch news feed.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      expect(retryClicked, isTrue);
    });

    testWidgets(
        'AppEmptyWidget renders title, message, and executes action button',
        (WidgetTester tester) async {
      var actionClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AppEmptyWidget(
              title: 'No bookmarks yet',
              message: 'Save articles to read them offline later.',
              actionLabel: 'Browse News',
              onAction: () => actionClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('No bookmarks yet'), findsOneWidget);
      expect(
        find.text('Save articles to read them offline later.'),
        findsOneWidget,
      );
      expect(find.text('Browse News'), findsOneWidget);

      await tester.tap(find.text('Browse News'));
      expect(actionClicked, isTrue);
    });
  });
}
