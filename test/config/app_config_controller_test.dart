import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/api/config.dart';
import 'package:mikudrome/config/app_config_controller.dart';

void main() {
  tearDown(ApiConfig.resetRuntimeConfigForTests);

  test('load reports unconfigured when store is empty', () async {
    ApiConfig.setRuntimeBaseUrl('http://stale.example.test');
    final store = _FakeStore();
    final controller = AppConfigController(store: store);

    await controller.load();

    expect(controller.state.status, AppConfigStatus.unconfigured);
    expect(controller.state.serverUrl, isNull);
    expect(controller.state.serverCookie, isNull);
    expect(ApiConfig.defaultBaseUrl, ApiConfig.dartDefineBaseUrl);
    expect(ApiConfig.defaultHeaders, isEmpty);
  });

  test('load applies saved server url and cookie', () async {
    final store = _FakeStore(
      serverUrl: 'http://192.168.1.10:8080',
      serverCookie: 'session=abc',
    );
    final controller = AppConfigController(store: store);

    await controller.load();

    expect(controller.state.status, AppConfigStatus.configured);
    expect(controller.state.serverUrl, 'http://192.168.1.10:8080');
    expect(controller.state.serverCookie, 'session=abc');
    expect(ApiConfig.defaultBaseUrl, 'http://192.168.1.10:8080');
    expect(ApiConfig.defaultHeaders, {'Cookie': 'session=abc'});
  });

  test('save validates connection before persisting url and cookie', () async {
    final store = _FakeStore();
    final calls = <({String url, String? cookie})>[];
    final controller = AppConfigController(
      store: store,
      connectionTester: (url, {serverCookie}) async =>
          calls.add((url: url, cookie: serverCookie)),
    );

    await controller.saveServerConfig(
      serverUrl: ' http://192.168.1.10:8080/ ',
      serverCookie: ' session=abc ',
    );

    expect(calls, [(url: 'http://192.168.1.10:8080', cookie: 'session=abc')]);
    expect(store.serverUrl, 'http://192.168.1.10:8080');
    expect(store.serverCookie, 'session=abc');
    expect(controller.state.status, AppConfigStatus.configured);
    expect(controller.state.serverUrl, 'http://192.168.1.10:8080');
    expect(controller.state.serverCookie, 'session=abc');
    expect(ApiConfig.defaultBaseUrl, 'http://192.168.1.10:8080');
    expect(ApiConfig.defaultHeaders, {'Cookie': 'session=abc'});
  });

  test('save failure clears candidate runtime url and rethrows', () async {
    final store = _FakeStore();
    final controller = AppConfigController(
      store: store,
      connectionTester: (_, {serverCookie}) async => throw Exception('offline'),
    );

    await expectLater(
      controller.saveServerConfig(
        serverUrl: ' http://192.168.1.10:8080/ ',
        serverCookie: 'session=abc',
      ),
      throwsA(isA<Exception>()),
    );

    expect(store.serverUrl, isNull);
    expect(store.serverCookie, isNull);
    expect(controller.state.status, AppConfigStatus.error);
    expect(controller.state.serverUrl, 'http://192.168.1.10:8080');
    expect(controller.state.serverCookie, 'session=abc');
    expect(controller.state.error, contains('offline'));
    expect(ApiConfig.defaultBaseUrl, ApiConfig.dartDefineBaseUrl);
    expect(ApiConfig.defaultHeaders, isEmpty);
  });

  test('save failure preserves previous server url', () async {
    final store = _FakeStore(
      serverUrl: 'http://192.168.1.10:8080',
      serverCookie: 'session=abc',
    );
    final controller = AppConfigController(
      store: store,
      connectionTester: (_, {serverCookie}) async => throw Exception('offline'),
    );
    await controller.load();

    await expectLater(
      controller.saveServerConfig(
        serverUrl: 'http://192.168.1.11:8080',
        serverCookie: 'session=xyz',
      ),
      throwsA(isA<Exception>()),
    );

    expect(controller.state.status, AppConfigStatus.error);
    expect(controller.state.serverUrl, 'http://192.168.1.10:8080');
    expect(controller.state.serverCookie, 'session=abc');
    expect(ApiConfig.defaultBaseUrl, 'http://192.168.1.10:8080');
    expect(ApiConfig.defaultHeaders, {'Cookie': 'session=abc'});
    expect(store.serverUrl, 'http://192.168.1.10:8080');
    expect(store.serverCookie, 'session=abc');
  });

  test('save can complete after controller is disposed', () async {
    final store = _FakeStore();
    final completer = Completer<void>();
    final controller = AppConfigController(
      store: store,
      connectionTester: (_, {serverCookie}) => completer.future,
    );

    final save = controller.saveServerUrl('http://192.168.1.10:8080');
    controller.dispose();
    completer.complete();

    await expectLater(save, completes);
  });
}

class _FakeStore implements AppConfigStore {
  _FakeStore({this.serverUrl, this.serverCookie});

  String? serverUrl;
  String? serverCookie;

  @override
  Future<String?> loadServerUrl() async => serverUrl;

  @override
  Future<String?> loadServerCookie() async => serverCookie;

  @override
  Future<void> saveServerUrl(String serverUrl) async {
    this.serverUrl = serverUrl;
  }

  @override
  Future<void> saveServerCookie(String? serverCookie) async {
    this.serverCookie = serverCookie;
  }

  @override
  Future<void> clearServerUrl() async {
    serverUrl = null;
  }

  @override
  Future<void> clearServerCookie() async {
    serverCookie = null;
  }
}
