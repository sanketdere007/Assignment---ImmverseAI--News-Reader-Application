/// Utility class for formatting timestamps and dates cleanly across QuickNews.
abstract final class DateFormatter {
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Formats an article publication timestamp into a human-readable relative or calendar date.
  ///
  /// Examples:
  /// - Under a minute: 'Just now'
  /// - Under an hour: '15m ago'
  /// - Under 24 hours: '3h ago'
  /// - Under 7 days: '2d ago'
  /// - Older: 'Oct 14, 2026'
  static String formatPublishedDate(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Recently';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.isNegative || difference.inSeconds < 60) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    final month = _months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;

    return '$month $day, $year';
  }
}
