import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/config/app_config_controller.dart';
import 'package:mikudrome/widgets/app_root.dart';

void main() {
  testWidgets('shows server setup when unconfigured', (tester) async {
    final controller = AppConfigController(store: _FakeStore());
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: AppRoot(controller: controller, requiresServerSetup: true),
      ),
    );

    expect(find.text('Connect to Mikudrome'), findsOneWidget);
    expect(find.text('Server URL'), findsOneWidget);
  });

  testWidgets(
    'unconfigured web-compatible root shows home when setup is not required',
    (tester) async {
      final controller = AppConfigController(store: _FakeStore());
      await controller.load();

      await tester.pumpWidget(
        MaterialApp(
          home: AppRoot(
            controller: controller,
            requiresServerSetup: false,
            homeBuilder: (_) => const Text('Library Home'),
          ),
        ),
      );

      expect(find.text('Library Home'), findsOneWidget);
      expect(find.text('Connect to Mikudrome'), findsNothing);
    },
  );

  testWidgets('shows app home when configured', (tester) async {
    final controller = AppConfigController(
      store: _FakeStore(serverUrl: 'http://192.168.1.10:8080'),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: AppRoot(
          controller: controller,
          homeBuilder: (_) => const Text('Library Home'),
        ),
      ),
    );

    expect(find.text('Library Home'), findsOneWidget);
    expect(find.text('Connect to Mikudrome'), findsNothing);
  });

  testWidgets('configured mobile root keeps app home when server edit fails', (
    tester,
  ) async {
    final controller = AppConfigController(
      store: _FakeStore(serverUrl: 'http://192.168.1.10:8080'),
      connectionTester: (_, {serverCookie}) async => throw Exception('offline'),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: AppRoot(
          controller: controller,
          requiresServerSetup: true,
          homeBuilder: (_) => const Text('Library Home'),
        ),
      ),
    );

    await expectLater(
      controller.saveServerUrl('http://192.168.1.11:8080'),
      throwsA(isA<Exception>()),
    );
    await tester.pump();

    expect(controller.state.status, AppConfigStatus.error);
    expect(controller.state.serverUrl, 'http://192.168.1.10:8080');
    expect(find.text('Library Home'), findsOneWidget);
    expect(find.text('Connect to Mikudrome'), findsNothing);
  });
}

class _FakeStore implements AppConfigStore {
  _FakeStore({this.serverUrl});

  String? serverUrl;
  String? _serverCookie;

  @override
  Future<String?> loadServerUrl() async => serverUrl;

  @override
  Future<String?> loadServerCookie() async => _serverCookie;

  @override
  Future<void> saveServerUrl(String serverUrl) async {
    this.serverUrl = serverUrl;
  }

  @override
  Future<void> saveServerCookie(String? serverCookie) async {
    _serverCookie = serverCookie;
  }

  @override
  Future<void> clearServerUrl() async {
    serverUrl = null;
  }

  @override
  Future<void> clearServerCookie() async {
    _serverCookie = null;
  }
}
