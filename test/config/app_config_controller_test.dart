import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/api/config.dart';
import 'package:mikudrome/config/app_config_controller.dart';

void main() {
  tearDown(ApiConfig.resetRuntimeBaseUrlForTests);

  test('load reports unconfigured when store is empty', () async {
    ApiConfig.setRuntimeBaseUrl('http://stale.example.test');
    final store = _FakeStore();
    final controller = AppConfigController(store: store);

    await controller.load();

    expect(controller.state.status, AppConfigStatus.unconfigured);
    expect(controller.state.serverUrl, isNull);
    expect(ApiConfig.defaultBaseUrl, ApiConfig.dartDefineBaseUrl);
  });

  test('load applies saved server url', () async {
    final store = _FakeStore(serverUrl: 'http://192.168.1.10:8080');
    final controller = AppConfigController(store: store);

    await controller.load();

    expect(controller.state.status, AppConfigStatus.configured);
    expect(controller.state.serverUrl, 'http://192.168.1.10:8080');
    expect(ApiConfig.defaultBaseUrl, 'http://192.168.1.10:8080');
  });

  test('save validates connection before persisting', () async {
    final store = _FakeStore();
    final calls = <String>[];
    final controller = AppConfigController(
      store: store,
      connectionTester: (url) async => calls.add(url),
    );

    await controller.saveServerUrl(' http://192.168.1.10:8080/ ');

    expect(calls, ['http://192.168.1.10:8080']);
    expect(store.serverUrl, 'http://192.168.1.10:8080');
    expect(controller.state.status, AppConfigStatus.configured);
    expect(controller.state.serverUrl, 'http://192.168.1.10:8080');
    expect(ApiConfig.defaultBaseUrl, 'http://192.168.1.10:8080');
  });

  test('save failure clears candidate runtime url and rethrows', () async {
    final store = _FakeStore();
    final controller = AppConfigController(
      store: store,
      connectionTester: (_) async => throw Exception('offline'),
    );

    await expectLater(
      controller.saveServerUrl(' http://192.168.1.10:8080/ '),
      throwsA(isA<Exception>()),
    );

    expect(store.serverUrl, isNull);
    expect(controller.state.status, AppConfigStatus.error);
    expect(controller.state.serverUrl, 'http://192.168.1.10:8080');
    expect(controller.state.error, contains('offline'));
    expect(ApiConfig.defaultBaseUrl, ApiConfig.dartDefineBaseUrl);
  });

  test('save failure preserves previous runtime url', () async {
    final store = _FakeStore(serverUrl: 'http://192.168.1.10:8080');
    final controller = AppConfigController(
      store: store,
      connectionTester: (_) async => throw Exception('offline'),
    );
    await controller.load();

    await expectLater(
      controller.saveServerUrl('http://192.168.1.11:8080'),
      throwsA(isA<Exception>()),
    );

    expect(controller.state.status, AppConfigStatus.error);
    expect(controller.state.serverUrl, 'http://192.168.1.11:8080');
    expect(ApiConfig.defaultBaseUrl, 'http://192.168.1.10:8080');
    expect(store.serverUrl, 'http://192.168.1.10:8080');
  });

  test('save can complete after controller is disposed', () async {
    final store = _FakeStore();
    final completer = Completer<void>();
    final controller = AppConfigController(
      store: store,
      connectionTester: (_) => completer.future,
    );

    final save = controller.saveServerUrl('http://192.168.1.10:8080');
    controller.dispose();
    completer.complete();

    await expectLater(save, completes);
  });
}

class _FakeStore implements AppConfigStore {
  _FakeStore({this.serverUrl});

  String? serverUrl;

  @override
  Future<String?> loadServerUrl() async => serverUrl;

  @override
  Future<void> saveServerUrl(String serverUrl) async {
    this.serverUrl = serverUrl;
  }

  @override
  Future<void> clearServerUrl() async {
    serverUrl = null;
  }
}
