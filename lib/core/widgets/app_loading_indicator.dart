import 'package:flutter/material.dart';

/// Reusable loading indicator supporting full-screen and section-embedded contexts.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.message,
    this.isFullScreen = false,
    this.strokeWidth = 3.0,
    this.size = 36.0,
  });

  /// Optional message shown beneath the progress indicator.
  final String? message;

  /// Whether the indicator should fill the entire screen inside a Scaffold.
  final bool isFullScreen;

  /// Stroke width of the CircularProgressIndicator.
  final double strokeWidth;

  /// Outer dimension of the CircularProgressIndicator.
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: strokeWidth,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (isFullScreen) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(child: content),
      );
    }

    return content;
  }
}
