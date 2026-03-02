/// API configuration: base URL and defaults.
abstract final class ApiConfig {
  ApiConfig._();

  /// Default backend base URL. Used when no baseUrl is provided.
  static const String defaultBaseUrl = 'http://127.0.0.1:8081';
}
