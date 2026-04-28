import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/config.dart';
import 'server_config_store.dart';
import 'server_url.dart';

enum AppConfigStatus { loading, unconfigured, configured, error }

class AppConfigState {
  const AppConfigState({
    required this.status,
    this.serverUrl,
    this.serverCookie,
    this.error,
  });

  const AppConfigState.loading() : this(status: AppConfigStatus.loading);

  final AppConfigStatus status;
  final String? serverUrl;
  final String? serverCookie;
  final String? error;
}

abstract class AppConfigStore {
  Future<String?> loadServerUrl();
  Future<String?> loadServerCookie();
  Future<void> saveServerUrl(String serverUrl);
  Future<void> saveServerCookie(String? serverCookie);
  Future<void> clearServerUrl();
  Future<void> clearServerCookie();
}

class ServerConfigStoreAdapter implements AppConfigStore {
  ServerConfigStoreAdapter([ServerConfigStore? store])
    : _store = store ?? ServerConfigStore();

  final ServerConfigStore _store;

  @override
  Future<String?> loadServerUrl() => _store.loadServerUrl();

  @override
  Future<String?> loadServerCookie() => _store.loadServerCookie();

  @override
  Future<void> saveServerUrl(String serverUrl) =>
      _store.saveServerUrl(serverUrl);

  @override
  Future<void> saveServerCookie(String? serverCookie) =>
      _store.saveServerCookie(serverCookie);

  @override
  Future<void> clearServerUrl() => _store.clearServerUrl();

  @override
  Future<void> clearServerCookie() => _store.clearServerCookie();
}

typedef ConnectionTester =
    Future<void> Function(String serverUrl, {String? serverCookie});

class AppConfigController extends ChangeNotifier {
  AppConfigController({
    AppConfigStore? store,
    ConnectionTester? connectionTester,
  }) : _store = store ?? ServerConfigStoreAdapter(),
       _connectionTester = connectionTester ?? _defaultConnectionTester;

  final AppConfigStore _store;
  final ConnectionTester _connectionTester;

  AppConfigState _state = const AppConfigState.loading();
  bool _disposed = false;

  AppConfigState get state => _state;

  Future<void> load() async {
    _setState(const AppConfigState.loading());
    try {
      final serverUrl = await _store.loadServerUrl();
      if (serverUrl == null) {
        ApiConfig.clearRuntimeConfig();
        _setState(const AppConfigState(status: AppConfigStatus.unconfigured));
        return;
      }
      final serverCookie = await _store.loadServerCookie();
      ApiConfig.setRuntimeBaseUrl(serverUrl);
      ApiConfig.setRuntimeCookie(serverCookie);
      _setState(
        AppConfigState(
          status: AppConfigStatus.configured,
          serverUrl: ApiConfig.defaultBaseUrl,
          serverCookie: serverCookie,
        ),
      );
    } catch (error) {
      ApiConfig.clearRuntimeConfig();
      _setState(
        AppConfigState(status: AppConfigStatus.error, error: error.toString()),
      );
      rethrow;
    }
  }

  Future<void> saveServerUrl(String serverUrl) async {
    await saveServerConfig(
      serverUrl: serverUrl,
      serverCookie: _state.serverCookie,
    );
  }

  Future<void> saveServerConfig({
    required String serverUrl,
    String? serverCookie,
  }) async {
    final normalized = normalizeServerUrl(serverUrl);
    final normalizedCookie = _normalizeCookie(serverCookie);
    final previousServerUrl =
        _state.status == AppConfigStatus.configured ||
            _state.status == AppConfigStatus.error
        ? _state.serverUrl
        : null;
    final previousServerCookie =
        _state.status == AppConfigStatus.configured ||
            _state.status == AppConfigStatus.error
        ? _state.serverCookie
        : null;
    _setState(
      AppConfigState(
        status: AppConfigStatus.loading,
        serverUrl: normalized,
        serverCookie: normalizedCookie,
      ),
    );
    try {
      await _connectionTester(normalized, serverCookie: normalizedCookie);
      await _store.saveServerUrl(normalized);
      await _store.saveServerCookie(normalizedCookie);
      ApiConfig.setRuntimeBaseUrl(normalized);
      ApiConfig.setRuntimeCookie(normalizedCookie);
      _setState(
        AppConfigState(
          status: AppConfigStatus.configured,
          serverUrl: normalized,
          serverCookie: normalizedCookie,
        ),
      );
    } catch (error) {
      if (previousServerUrl == null) {
        ApiConfig.clearRuntimeConfig();
      } else {
        ApiConfig.setRuntimeBaseUrl(previousServerUrl);
        ApiConfig.setRuntimeCookie(previousServerCookie);
      }
      _setState(
        AppConfigState(
          status: AppConfigStatus.error,
          serverUrl: previousServerUrl ?? normalized,
          serverCookie: previousServerCookie ?? normalizedCookie,
          error: error.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<void> clearServerUrl() async {
    await _store.clearServerUrl();
    await _store.clearServerCookie();
    ApiConfig.clearRuntimeConfig();
    _setState(const AppConfigState(status: AppConfigStatus.unconfigured));
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _setState(AppConfigState next) {
    _state = next;
    if (!_disposed) {
      notifyListeners();
    }
  }

  static Future<void> _defaultConnectionTester(
    String serverUrl, {
    String? serverCookie,
  }) {
    return ApiClient(
      baseUrl: serverUrl,
      serverCookie: serverCookie,
    ).checkConnection();
  }

  static String? _normalizeCookie(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
