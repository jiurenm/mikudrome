/// API configuration: base URL and defaults.
///
/// Base URL is read from build-time env via `--dart-define=API_BASE_URL=...`.
/// - Empty or unset: use relative URLs (same-origin, e.g. Docker production).
/// - Set to URL: use that base (e.g. `http://127.0.0.1:8080` for local dev).
abstract final class ApiConfig {
  ApiConfig._();

  /// Backend base URL from env API_BASE_URL. Empty = same-origin (relative).
  static final String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
}
