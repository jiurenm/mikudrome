import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/config.dart';
import 'server_config_store.dart';
import 'server_url.dart';

enum AppConfigStatus { loading, unconfigured, configured, error }

class AppConfigState {
  const AppConfigState({required this.status, this.serverUrl, this.error});

  const AppConfigState.loading() : this(status: AppConfigStatus.loading);

  final AppConfigStatus status;
  final String? serverUrl;
  final String? error;
}

abstract class AppConfigStore {
  Future<String?> loadServerUrl();
  Future<void> saveServerUrl(String serverUrl);
  Future<void> clearServerUrl();
}

class ServerConfigStoreAdapter implements AppConfigStore {
  ServerConfigStoreAdapter([ServerConfigStore? store])
    : _store = store ?? ServerConfigStore();

  final ServerConfigStore _store;

  @override
  Future<String?> loadServerUrl() => _store.loadServerUrl();

  @override
  Future<void> saveServerUrl(String serverUrl) =>
      _store.saveServerUrl(serverUrl);

  @override
  Future<void> clearServerUrl() => _store.clearServerUrl();
}

typedef ConnectionTester = Future<void> Function(String serverUrl);

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
        ApiConfig.clearRuntimeBaseUrl();
        _setState(const AppConfigState(status: AppConfigStatus.unconfigured));
        return;
      }
      ApiConfig.setRuntimeBaseUrl(serverUrl);
      _setState(
        AppConfigState(
          status: AppConfigStatus.configured,
          serverUrl: ApiConfig.defaultBaseUrl,
        ),
      );
    } catch (error) {
      ApiConfig.clearRuntimeBaseUrl();
      _setState(
        AppConfigState(status: AppConfigStatus.error, error: error.toString()),
      );
      rethrow;
    }
  }

  Future<void> saveServerUrl(String serverUrl) async {
    final normalized = normalizeServerUrl(serverUrl);
    final previousServerUrl =
        _state.status == AppConfigStatus.configured ||
            _state.status == AppConfigStatus.error
        ? _state.serverUrl
        : null;
    _setState(
      AppConfigState(status: AppConfigStatus.loading, serverUrl: normalized),
    );
    try {
      await _connectionTester(normalized);
      await _store.saveServerUrl(normalized);
      ApiConfig.setRuntimeBaseUrl(normalized);
      _setState(
        AppConfigState(
          status: AppConfigStatus.configured,
          serverUrl: normalized,
        ),
      );
    } catch (error) {
      _setState(
        AppConfigState(
          status: AppConfigStatus.error,
          serverUrl: previousServerUrl ?? normalized,
          error: error.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<void> clearServerUrl() async {
    await _store.clearServerUrl();
    ApiConfig.clearRuntimeBaseUrl();
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

  static Future<void> _defaultConnectionTester(String serverUrl) {
    return ApiClient(baseUrl: serverUrl).checkConnection();
  }
}
