import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/config/app_config_controller.dart';
import 'package:mikudrome/models/playback_modes.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/services/mobile_audio_playback.dart';
import 'package:mikudrome/services/playback_storage.dart';
import 'package:mikudrome/widgets/app_root.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await PlaybackStorage.ensureInitialized();
  });

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

  testWidgets(
    'configured root keeps home mounted and resets playback after delayed edit',
    (tester) async {
      final connectionRelease = Completer<void>();
      final service = _RecordingMobileAudioPlaybackService();
      final controller = AppConfigController(
        store: _FakeStore(serverUrl: 'http://192.168.1.10:8080'),
        connectionTester: (_, {serverCookie}) => connectionRelease.future,
      );
      await controller.load();
      _seedPlaybackStorage();
      addTearDown(service.dispose);
      addTearDown(controller.dispose);

      var homeInitializations = 0;
      var homeDisposals = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AppRoot(
            controller: controller,
            mobileAudioPlaybackService: service,
            homeBuilder: (_) => _TrackedHome(
              onInit: () => homeInitializations += 1,
              onDispose: () => homeDisposals += 1,
            ),
          ),
        ),
      );

      expect(find.text('Library Home'), findsOneWidget);
      expect(homeInitializations, 1);
      expect(homeDisposals, 0);

      final save = controller.saveServerConfig(
        serverUrl: 'http://192.168.1.11:8080',
        serverCookie: 'session=new',
      );
      expect(controller.state.status, AppConfigStatus.loading);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('Library Home'), findsOneWidget);
      expect(find.text('Connect to Mikudrome'), findsNothing);
      expect(homeInitializations, 1);
      expect(homeDisposals, 0);
      expect(service.clearCacheCalls, 0);
      expect(PlaybackStorage.load(), isNotNull);

      connectionRelease.complete();
      await save;
      await tester.pump();

      expect(service.clearCacheCalls, 1);
      expect(PlaybackStorage.load(), isNull);
      expect(homeInitializations, 2);
      expect(homeDisposals, 1);
      expect(service.disposeCalls, 0);

      await service.playQueue(
        queue: const [
          Track(
            id: 2,
            title: 'Still playable',
            audioPath: '/still-playable.flac',
            videoPath: '',
          ),
        ],
        index: 0,
        audioUrlForTrack: (_) => 'http://192.168.1.11:8080/audio/2',
      );

      expect(service.playQueueCalls, 1);
      expect(service.currentState.track?.id, 2);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(service.disposeCalls, 0);
    },
  );

  testWidgets('failed delayed edit keeps configured home and playback state', (
    tester,
  ) async {
    final connectionRelease = Completer<void>();
    final service = _RecordingMobileAudioPlaybackService();
    final controller = AppConfigController(
      store: _FakeStore(serverUrl: 'http://192.168.1.10:8080'),
      connectionTester: (_, {serverCookie}) => connectionRelease.future,
    );
    await controller.load();
    _seedPlaybackStorage();
    addTearDown(service.dispose);
    addTearDown(controller.dispose);

    var homeInitializations = 0;
    var homeDisposals = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AppRoot(
          controller: controller,
          mobileAudioPlaybackService: service,
          homeBuilder: (_) => _TrackedHome(
            onInit: () => homeInitializations += 1,
            onDispose: () => homeDisposals += 1,
          ),
        ),
      ),
    );

    final saveExpectation = expectLater(
      controller.saveServerUrl('http://192.168.1.11:8080'),
      throwsA(isA<StateError>()),
    );
    await tester.pump();

    expect(controller.state.status, AppConfigStatus.loading);
    expect(find.text('Library Home'), findsOneWidget);
    expect(homeInitializations, 1);
    expect(homeDisposals, 0);

    connectionRelease.completeError(StateError('offline'));
    await saveExpectation;
    await tester.pump();

    expect(controller.state.status, AppConfigStatus.error);
    expect(controller.state.serverUrl, 'http://192.168.1.10:8080');
    expect(find.text('Library Home'), findsOneWidget);
    expect(homeInitializations, 1);
    expect(homeDisposals, 0);
    expect(service.clearCacheCalls, 0);
    expect(service.disposeCalls, 0);
    expect(PlaybackStorage.load(), isNotNull);
  });

  testWidgets('reloading configured storage does not reset playback', (
    tester,
  ) async {
    final service = _RecordingMobileAudioPlaybackService();
    final controller = AppConfigController(
      store: _FakeStore(serverUrl: 'http://192.168.1.10:8080'),
    );
    await controller.load();
    _seedPlaybackStorage();
    addTearDown(service.dispose);
    addTearDown(controller.dispose);

    var homeInitializations = 0;
    var homeDisposals = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AppRoot(
          controller: controller,
          mobileAudioPlaybackService: service,
          homeBuilder: (_) => _TrackedHome(
            onInit: () => homeInitializations += 1,
            onDispose: () => homeDisposals += 1,
          ),
        ),
      ),
    );

    final reload = controller.load();
    expect(controller.state.status, AppConfigStatus.loading);
    expect(controller.state.serverUrl, isNull);
    await tester.pump();

    expect(find.text('Library Home'), findsOneWidget);
    expect(homeInitializations, 1);
    expect(homeDisposals, 0);

    await reload;
    await tester.pump();

    expect(controller.state.status, AppConfigStatus.configured);
    expect(service.clearCacheCalls, 0);
    expect(PlaybackStorage.load(), isNotNull);
    expect(homeInitializations, 1);
    expect(homeDisposals, 0);
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

class _TrackedHome extends StatefulWidget {
  const _TrackedHome({required this.onInit, required this.onDispose});

  final VoidCallback onInit;
  final VoidCallback onDispose;

  @override
  State<_TrackedHome> createState() => _TrackedHomeState();
}

class _TrackedHomeState extends State<_TrackedHome> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('Library Home');
}

class _RecordingMobileAudioPlaybackService
    extends FakeMobileAudioPlaybackService {
  int clearCacheCalls = 0;
  int playQueueCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> clearCache() async {
    clearCacheCalls += 1;
    await super.clearCache();
  }

  @override
  Future<void> playQueue({
    required List<Track> queue,
    required int index,
    required AudioUrlForTrack audioUrlForTrack,
    CoverUrlForTrack? coverUrlForTrack,
    MobilePlaybackOrderMode orderMode = MobilePlaybackOrderMode.sequential,
    Duration initialPosition = Duration.zero,
    TrackFavoriteStatus? isTrackFavorited,
    TrackFavoriteToggle? toggleTrackFavorite,
  }) async {
    playQueueCalls += 1;
    await super.playQueue(
      queue: queue,
      index: index,
      audioUrlForTrack: audioUrlForTrack,
      coverUrlForTrack: coverUrlForTrack,
      orderMode: orderMode,
      initialPosition: initialPosition,
      isTrackFavorited: isTrackFavorited,
      toggleTrackFavorite: toggleTrackFavorite,
    );
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    await super.dispose();
  }
}

void _seedPlaybackStorage() {
  PlaybackStorage.save(
    queue: const [
      Track(
        id: 1,
        title: 'Saved track',
        audioPath: '/saved.flac',
        videoPath: '',
      ),
    ],
    index: 0,
    progress: 0.5,
    mode: PlaybackMode.audio,
    orderMode: PlaybackOrderMode.sequential,
    contextLabel: 'Saved queue',
  );
}
