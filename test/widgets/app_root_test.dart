import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('native phone landscape hides only the status overlay', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    var mediaSize = const Size(844, 390);
    await tester.binding.setSurfaceSize(mediaSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final platformCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final controller = AppConfigController(
      store: _FakeStore(serverUrl: 'http://192.168.1.10:8080'),
    );
    await controller.load();

    try {
      Widget buildRoot() {
        return MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: mediaSize),
            child: AppRoot(
              controller: controller,
              homeBuilder: (_) => const Text('Library Home'),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildRoot());
      await tester.pump();

      expect(
        platformCalls
            .where(
              (call) =>
                  call.method == 'SystemChrome.setEnabledSystemUIOverlays',
            )
            .map((call) => call.arguments),
        contains(equals([SystemUiOverlay.bottom.toString()])),
      );

      platformCalls.clear();
      mediaSize = const Size(390, 844);
      await tester.binding.setSurfaceSize(mediaSize);
      await tester.pumpWidget(buildRoot());
      await tester.pump();

      expect(
        platformCalls
            .where(
              (call) =>
                  call.method == 'SystemChrome.setEnabledSystemUIOverlays',
            )
            .map((call) => call.arguments),
        contains(
          equals(
            SystemUiOverlay.values.map((value) => value.toString()).toList(),
          ),
        ),
      );

      platformCalls.clear();
      mediaSize = const Size(844, 390);
      await tester.binding.setSurfaceSize(mediaSize);
      await tester.pumpWidget(buildRoot());
      await tester.pump();
      platformCalls.clear();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(
        platformCalls
            .where(
              (call) =>
                  call.method == 'SystemChrome.setEnabledSystemUIOverlays',
            )
            .map((call) => call.arguments),
        contains(
          equals(
            SystemUiOverlay.values.map((value) => value.toString()).toList(),
          ),
        ),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
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
