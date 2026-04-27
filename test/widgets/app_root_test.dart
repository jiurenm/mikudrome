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
