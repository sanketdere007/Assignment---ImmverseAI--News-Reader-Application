abstract final class ApiConstants {
  /// Base URL for the NewsAPI service.
  static const String baseUrl = 'https://newsapi.org/v2';

  // API Endpoints
  static const String topHeadlinesEndpoint = '/top-headlines';
  static const String everythingEndpoint = '/everything';

  // Environment variable and Authentication
  static const String newsApiKeyEnv = 'NEWS_API_KEY';
  static const String apiKeyHeader = 'X-Api-Key';

  /// Compile-time API key provided securely via environment variables.
  /// Reads directly using `const String.fromEnvironment('NEWS_API_KEY')`.
  static const String apiKey = String.fromEnvironment('NEWS_API_KEY');

  /// Cleaned API key with whitespace and accidental shell quotes stripped.
  static String get cleanApiKey {
    var key = apiKey.trim();
    if ((key.startsWith('"') && key.endsWith('"')) ||
        (key.startsWith("'") && key.endsWith("'"))) {
      key = key.substring(1, key.length - 1).trim();
    }
    return key;
  }

  /// Whether a valid non-empty API key is configured.
  static bool get hasApiKey => cleanApiKey.isNotEmpty;

  /// Safe diagnostic string reporting presence and character count only.
  /// Never reveals the API key value.
  static String get apiKeyDiagnostic => hasApiKey
      ? 'Present (${cleanApiKey.length} chars)'
      : 'Missing (0 chars)';

  // Pagination & Defaults
  static const String defaultCountry = 'us';
  static const String defaultCategory = 'general';
  static const int defaultPageSize = 20;
  static const String defaultSortBy = 'publishedAt';

  /// Supported top-headlines categories on NewsAPI.
  static const List<String> supportedCategories = [
    'general',
    'business',
    'technology',
    'entertainment',
    'health',
    'science',
    'sports',
  ];

  // Network Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);
}
