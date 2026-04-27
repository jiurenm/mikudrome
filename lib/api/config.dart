import 'package:flutter/foundation.dart';

import '../config/server_url.dart';

/// API configuration: base URL and defaults.
///
/// Web keeps using --dart-define=API_BASE_URL or same-origin relative URLs.
/// Mobile can set a runtime base URL after reading local server config.
abstract final class ApiConfig {
  ApiConfig._();

  static const String dartDefineBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String? _runtimeBaseUrl;

  static String get defaultBaseUrl => _runtimeBaseUrl ?? dartDefineBaseUrl;

  static void setRuntimeBaseUrl(String serverUrl) {
    _runtimeBaseUrl = normalizeServerUrl(serverUrl);
  }

  static void clearRuntimeBaseUrl() {
    _runtimeBaseUrl = null;
  }

  @visibleForTesting
  static void resetRuntimeBaseUrlForTests() {
    _runtimeBaseUrl = null;
  }
}
