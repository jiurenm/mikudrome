import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/screens/library_home_screen.dart';
import 'package:mikudrome/screens/player_screen.dart';
import 'package:mikudrome/services/playlist_repository.dart';
import 'package:mikudrome/widgets/player/asset_slider_thumb_shape.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

Track _desktopTrack() => const Track(
  id: 7,
  title: 'ぽかぽかの星',
  audioPath: '/tmp/7.flac',
  videoPath: '',
  composer: 'はるまきごはん',
  lyricist: 'はるまきごはん',
  vocal: 'Miku',
  lyrics: 'line 1\nline 2\nline 3',
);

Track _creditlessTrack() => const Track(
  id: 8,
  title: 'creditless',
  audioPath: '/tmp/8.flac',
  videoPath: '',
  lyrics: 'line 1\nline 2\nline 3',
);

Widget _buildPlayer({
  required Size surfaceSize,
  Track? track,
  List<Track>? queue,
  String? currentCoverUrl,
  PlaybackMode playbackMode = PlaybackMode.audio,
  bool shuffleEnabled = false,
  VoidCallback? onToggleShuffle,
  String Function(Track track)? coverUrlForTrack,
}) {
  final resolvedTrack = track ?? _desktopTrack();
  final resolvedQueue = queue ?? [resolvedTrack];
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: surfaceSize),
      child: PlayerScreen(
        track: resolvedTrack,
        queue: resolvedQueue,
        currentIndex: 0,
        contextLabel: 'Layout Test',
        playbackMode: playbackMode,
        onSelectTrack: (_) {},
        onPrevious: () {},
        onNext: () {},
        onClose: () {},
        onSwitchPlaybackMode: (_) {},
        playbackOrderMode: PlaybackOrderMode.sequential,
        onCyclePlaybackOrderMode: () {},
        onPlaybackStateChanged:
            ({
              required bool isPlaying,
              required double progress,
              required String elapsedLabel,
              required String durationLabel,
            }) {},
        initializeControllerOnStart: false,
        currentCoverUrl: currentCoverUrl,
        shuffleEnabled: shuffleEnabled,
        onToggleShuffle: onToggleShuffle,
        coverUrlForTrack: coverUrlForTrack,
      ),
    ),
  );
}

Future<void> _pumpPlayer(
  WidgetTester tester, {
  required Size surfaceSize,
  Track? track,
  List<Track>? queue,
  String? currentCoverUrl,
  PlaybackMode playbackMode = PlaybackMode.audio,
  bool shuffleEnabled = false,
  VoidCallback? onToggleShuffle,
  String Function(Track track)? coverUrlForTrack,
}) async {
  await tester.pumpWidget(
    _buildPlayer(
      surfaceSize: surfaceSize,
      track: track,
      queue: queue,
      currentCoverUrl: currentCoverUrl,
      playbackMode: playbackMode,
      shuffleEnabled: shuffleEnabled,
      onToggleShuffle: onToggleShuffle,
      coverUrlForTrack: coverUrlForTrack,
    ),
  );
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (!tester.binding.hasScheduledFrame) {
      break;
    }
  }
}

void main() {
  testWidgets('non-mobile audio keeps title inside the left media column', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpPlayer(tester, surfaceSize: const Size(1600, 900));

    expect(
      find.byKey(const ValueKey('player-audio-left-column')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player-audio-title-block')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player-audio-cover-block')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player-audio-lyrics-panel')),
      findsOneWidget,
    );

    final titleBottom = tester.getBottomLeft(
      find.byKey(const ValueKey('player-audio-title-block')),
    );
    final coverTop = tester.getTopLeft(
      find.byKey(const ValueKey('player-audio-cover-block')),
    );
    final titleLeft = tester.getTopLeft(
      find.byKey(const ValueKey('player-audio-title-block')),
    );
    final lyricsLeft = tester.getTopLeft(
      find.byKey(const ValueKey('player-audio-lyrics-panel')),
    );

    expect(coverTop.dy, greaterThanOrEqualTo(titleBottom.dy));
    expect(titleLeft.dx, lessThan(lyricsLeft.dx));
  });

  testWidgets(
    'intermediate non-mobile width uses the same moved-title layout',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpPlayer(tester, surfaceSize: const Size(1200, 900));

      expect(
        find.byKey(const ValueKey('player-audio-left-column')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('player-audio-title-block')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('player-audio-cover-block')),
        findsOneWidget,
      );
    },
  );

  testWidgets('non-mobile left media column stays vertically centered', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpPlayer(tester, surfaceSize: const Size(1600, 900));

    final rowRect = tester.getRect(
      find.byKey(const ValueKey('player-audio-layout')),
    );
    final leftColumnRect = tester.getRect(
      find.byKey(const ValueKey('player-audio-left-column')),
    );

    final topGap = leftColumnRect.top - rowRect.top;
    final bottomGap = rowRect.bottom - leftColumnRect.bottom;

    expect((topGap - bottomGap).abs(), lessThan(24));
  });

  testWidgets('mobile layout remains unchanged', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpPlayer(tester, surfaceSize: const Size(430, 900));

    expect(
      find.byKey(const ValueKey('player-audio-left-column')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('player-audio-title-block')),
      findsNothing,
    );
  });

  testWidgets('width-mobile desktop surface keeps mobile player layout', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    try {
      await _pumpPlayer(tester, surfaceSize: const Size(430, 900));

      expect(
        find.byKey(const ValueKey('mobile-player-immersive')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('player-audio-left-column')),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('mobile player uses compact controls with title actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const current = Track(
      id: 7,
      title: 'ぽかぽかの星',
      audioPath: '/tmp/7.flac',
      videoPath: '/tmp/7.mp4',
      composer: 'はるまきごはん',
      lyricist: 'はるまきごはん',
      vocal: 'Miku',
      lyrics: 'line 1\nline 2\nline 3',
    );
    final queue = [
      current,
      const Track(
        id: 9,
        title: 'ヒバナ',
        audioPath: '/tmp/9.flac',
        videoPath: '',
        vocal: 'DECO*27 feat. 初音ミク',
        coverOverrideUrl: 'http://127.0.0.1:8080/api/covers/9',
      ),
      const Track(
        id: 10,
        title: 'ゴーストルール',
        audioPath: '/tmp/10.flac',
        videoPath: '',
        vocal: 'DECO*27 feat. 初音ミク',
      ),
      const Track(
        id: 11,
        title: 'アンチビート',
        audioPath: '/tmp/11.flac',
        videoPath: '',
        vocal: 'DECO*27 feat. 初音ミク',
      ),
    ];

    await _pumpPlayer(
      tester,
      surfaceSize: const Size(430, 900),
      track: current,
      queue: queue,
      currentCoverUrl: 'http://127.0.0.1:8080/api/covers/7',
      coverUrlForTrack: (track) =>
          'http://127.0.0.1:8080/api/covers/${track.id}',
    );

    expect(
      find.byKey(const ValueKey('mobile-player-immersive')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-player-media-pager')),
      findsOneWidget,
    );
    expect(find.text('播放'), findsOneWidget);
    expect(find.text('歌词'), findsOneWidget);
    expect(find.text('Layout Test'), findsNothing);
    expect(find.byIcon(Icons.movie), findsNothing);
    expect(find.text('HQ'), findsNothing);
    expect(find.text('已收藏'), findsNothing);
    expect(find.text('加入歌单'), findsNothing);
    expect(find.text('下载'), findsNothing);
    expect(find.text('音效'), findsNothing);
    expect(find.text('队列'), findsNothing);
    expect(find.text('更多'), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.byIcon(Icons.shuffle), findsOneWidget);
    expect(find.byIcon(Icons.arrow_right_alt), findsOneWidget);
    expect(find.text('接下来播放'), findsNothing);
    expect(find.text('清空'), findsNothing);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(
      find.byKey(const ValueKey('mobile-player-queue-peek')),
      findsOneWidget,
    );
    expect(find.text('上滑查看队列'), findsOneWidget);
    expect(find.text('ヒバナ'), findsNothing);
    expect(find.text('ゴーストルール'), findsNothing);
    expect(find.text('アンチビート'), findsNothing);

    await tester.drag(
      find.byKey(const ValueKey('mobile-player-queue-peek')),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();

    expect(find.text('播放的音乐来自'), findsOneWidget);
    expect(find.text('Layout Test'), findsOneWidget);
    expect(find.text('ぽかぽかの星'), findsWidgets);
    expect(find.text('ヒバナ'), findsOneWidget);
    expect(find.text('ゴーストルール'), findsOneWidget);
    expect(find.text('アンチビート'), findsOneWidget);
    expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('mobile-player-media-pager')))
          .bottom,
      lessThanOrEqualTo(
        tester
            .getRect(find.byKey(const ValueKey('mobile-player-queue-panel')))
            .top,
      ),
    );

    final imageUrls = tester
        .widgetList<Image>(
          find.byWidgetPredicate(
            (widget) => widget is Image && widget.image is NetworkImage,
          ),
        )
        .map((image) => image.image)
        .whereType<NetworkImage>()
        .map((image) => image.url);

    expect(imageUrls, contains('http://127.0.0.1:8080/api/covers/7'));
    expect(imageUrls, contains('http://127.0.0.1:8080/api/covers/9'));

    await tester.tap(
      find.byKey(const ValueKey('mobile-player-queue-collapse-handle')),
    );
    await tester.pumpAndSettle();

    expect(find.text('播放的音乐来自'), findsNothing);
    expect(
      find.byKey(const ValueKey('mobile-player-queue-peek')),
      findsOneWidget,
    );
  });

  testWidgets('mobile reopen forwards the latest initial progress to video', (
    tester,
  ) async {
    final previousPlatform = VideoPlayerPlatform.instance;
    final platform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = previousPlatform);

    const track = Track(
      id: 77,
      title: 'Immersive MV',
      audioPath: '/tmp/77.flac',
      videoPath: '/tmp/77.mp4',
      vocal: 'Miku',
      lyrics: '[00:00.00]lyrics should not be shown',
    );

    var playbackMode = PlaybackMode.video;
    var useExternalAudioPlayback = false;
    double? initialProgress;
    double? externalProgress;
    var externalIsPlaying = false;
    late StateSetter setState;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(430, 900)),
          child: StatefulBuilder(
            builder: (context, stateSetter) {
              setState = stateSetter;
              return PlayerScreen(
                track: track,
                queue: const [track],
                currentIndex: 0,
                contextLabel: 'MV Test',
                playbackMode: playbackMode,
                onSelectTrack: (_) {},
                onPrevious: () {},
                onNext: () {},
                onClose: () {},
                onSwitchPlaybackMode: (_) {},
                playbackOrderMode: PlaybackOrderMode.sequential,
                onCyclePlaybackOrderMode: () {},
                onPlaybackStateChanged:
                    ({
                      required bool isPlaying,
                      required double progress,
                      required String elapsedLabel,
                      required String durationLabel,
                    }) {},
                initializeControllerOnStart: true,
                initialProgress: initialProgress,
                renderVideo: false,
                useExternalAudioPlayback: useExternalAudioPlayback,
                externalIsPlaying: externalIsPlaying,
                externalProgress: externalProgress,
                onExternalPlay: () async {},
                onExternalPause: () async {},
                onExternalSeekToFraction: (_) async {},
              );
            },
          ),
        ),
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (!tester.binding.hasScheduledFrame) {
        break;
      }
    }

    setState(() {
      playbackMode = PlaybackMode.audio;
      useExternalAudioPlayback = true;
      externalIsPlaying = true;
      externalProgress = 0.42;
      initialProgress = null;
    });
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (!tester.binding.hasScheduledFrame) {
        break;
      }
    }

    setState(() {
      playbackMode = PlaybackMode.video;
      useExternalAudioPlayback = false;
      externalIsPlaying = false;
      externalProgress = null;
      initialProgress = 0.42;
    });
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (!tester.binding.hasScheduledFrame) {
        break;
      }
    }

    expect(platform.seekPositions, [const Duration(milliseconds: 420)]);
  });

  testWidgets(
    'mobile video mode uses immersive MV surface without lyrics tabs',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const track = Track(
        id: 77,
        title: 'Immersive MV',
        audioPath: '/tmp/77.flac',
        videoPath: '/tmp/77.mp4',
        vocal: 'Miku',
        lyrics: '[00:00.00]lyrics should not be shown',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(430, 900)),
            child: PlayerScreen(
              track: track,
              queue: const [track],
              currentIndex: 0,
              contextLabel: 'MV Test',
              playbackMode: PlaybackMode.video,
              onSelectTrack: (_) {},
              onPrevious: () {},
              onNext: () {},
              onClose: () {},
              onSwitchPlaybackMode: (_) {},
              playbackOrderMode: PlaybackOrderMode.sequential,
              onCyclePlaybackOrderMode: () {},
              onPlaybackStateChanged:
                  ({
                    required bool isPlaying,
                    required double progress,
                    required String elapsedLabel,
                    required String durationLabel,
                  }) {},
              initializeControllerOnStart: false,
              renderVideo: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('mobile-mv-player-surface')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mobile-mv-video-frame')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mobile-player-artwork-frame')),
        findsNothing,
      );
      expect(find.text('歌词'), findsNothing);
      expect(find.text('lyrics should not be shown'), findsNothing);
      expect(
        find.byKey(const ValueKey('mobile-mv-queue-button')),
        findsOneWidget,
      );
    },
  );

  testWidgets('mobile MV fullscreen locks and restores orientation', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    try {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var mediaSize = const Size(430, 900);
      var mediaPadding = EdgeInsets.zero;

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

      const track = Track(
        id: 78,
        title: 'Fullscreen MV',
        audioPath: '/tmp/78.flac',
        videoPath: '/tmp/78.mp4',
      );

      Widget buildPlayer() {
        return MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: mediaSize, padding: mediaPadding),
            child: PlayerScreen(
              track: track,
              queue: const [track],
              currentIndex: 0,
              contextLabel: 'MV Test',
              playbackMode: PlaybackMode.video,
              onSelectTrack: (_) {},
              onPrevious: () {},
              onNext: () {},
              onClose: () {},
              onSwitchPlaybackMode: (_) {},
              playbackOrderMode: PlaybackOrderMode.sequential,
              onCyclePlaybackOrderMode: () {},
              onPlaybackStateChanged:
                  ({
                    required bool isPlaying,
                    required double progress,
                    required String elapsedLabel,
                    required String durationLabel,
                  }) {},
              initializeControllerOnStart: false,
              renderVideo: false,
            ),
          ),
        );
      }

      await tester.pumpWidget(buildPlayer());
      await tester.pump();

      expect(find.byTooltip('全屏'), findsOneWidget);
      await tester.tap(find.byTooltip('全屏'));
      await tester.pump();

      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
      expect(
        platformCalls
            .where(
              (call) => call.method == 'SystemChrome.setEnabledSystemUIMode',
            )
            .map((call) => call.arguments),
        contains(equals('SystemUiMode.immersiveSticky')),
      );
      expect(
        platformCalls
            .where(
              (call) => call.method == 'SystemChrome.setPreferredOrientations',
            )
            .map((call) => call.arguments),
        contains(
          equals([
            'DeviceOrientation.landscapeLeft',
            'DeviceOrientation.landscapeRight',
          ]),
        ),
      );

      mediaSize = const Size(900, 430);
      mediaPadding = const EdgeInsets.only(right: 48);
      await tester.binding.setSurfaceSize(mediaSize);
      await tester.pumpWidget(buildPlayer());
      await tester.pump();

      final exitButtonRect = tester.getRect(
        find
            .ancestor(
              of: find.byIcon(Icons.fullscreen_exit),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(exitButtonRect.right, lessThanOrEqualTo(mediaSize.width - 48));

      final exitControl = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byIcon(Icons.fullscreen_exit),
              matching: find.byType(IconButton),
            )
            .first,
      );
      exitControl.onPressed!();
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

      expect(
        platformCalls
            .where(
              (call) => call.method == 'SystemChrome.setPreferredOrientations',
            )
            .map((call) => call.arguments),
        contains(
          equals(
            DeviceOrientation.values.map((value) => value.toString()).toList(),
          ),
        ),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('mobile MV fullscreen restores orientation on dispose', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
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

    const track = Track(
      id: 79,
      title: 'Disposable MV',
      audioPath: '/tmp/79.flac',
      videoPath: '/tmp/79.mp4',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(430, 900)),
          child: PlayerScreen(
            track: track,
            queue: const [track],
            currentIndex: 0,
            contextLabel: 'MV Test',
            playbackMode: PlaybackMode.video,
            onSelectTrack: (_) {},
            onPrevious: () {},
            onNext: () {},
            onClose: () {},
            onSwitchPlaybackMode: (_) {},
            playbackOrderMode: PlaybackOrderMode.sequential,
            onCyclePlaybackOrderMode: () {},
            onPlaybackStateChanged:
                ({
                  required bool isPlaying,
                  required double progress,
                  required String elapsedLabel,
                  required String durationLabel,
                }) {},
            initializeControllerOnStart: false,
            renderVideo: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('全屏'));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(
      platformCalls
          .where(
            (call) => call.method == 'SystemChrome.setPreferredOrientations',
          )
          .map((call) => call.arguments),
      contains(
        equals(
          DeviceOrientation.values.map((value) => value.toString()).toList(),
        ),
      ),
    );
  });

  testWidgets('mobile title favorite button toggles favorite state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    PlaylistRepository.instance.favoriteTrackIds.clear();
    addTearDown(() => PlaylistRepository.instance.favoriteTrackIds.clear());
    final httpClient = _FavoriteRecordingHttpClient();

    await HttpOverrides.runZoned(() async {
      await _pumpPlayer(tester, surfaceSize: const Size(430, 900));

      expect(find.byTooltip('Add to favorites'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      await tester.tap(find.byTooltip('Add to favorites'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    }, createHttpClient: (_) => httpClient);

    expect(httpClient.requests, contains('POST /api/favorites/7'));
    expect(PlaylistRepository.instance.isFavorite(7), isTrue);
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('mobile cover backdrop blends into the control area', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const track = Track(
      id: 31,
      title: 'Backdrop blend',
      audioPath: '/tmp/31.flac',
      videoPath: '',
      vocal: 'Miku',
    );

    await _pumpPlayer(
      tester,
      surfaceSize: const Size(430, 900),
      track: track,
      currentCoverUrl: 'http://127.0.0.1:8080/api/covers/31',
    );

    final gradientFinder = find.byKey(
      const ValueKey('mobile-player-backdrop-gradient'),
    );
    expect(gradientFinder, findsOneWidget);

    final gradientBox = tester.widget<DecoratedBox>(gradientFinder);
    final decoration = gradientBox.decoration as BoxDecoration;
    final gradient = decoration.gradient as LinearGradient;

    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);
    expect(gradient.stops, const [0.0, 0.24, 0.52, 0.76, 1.0]);
    expect(gradient.colors, hasLength(5));
    expect(gradient.colors.last, const Color(0xFF071015));
    expect(
      find.byKey(const ValueKey('mobile-player-cover-wash')),
      findsOneWidget,
    );
  });

  testWidgets(
    'mobile artwork frame uses a softened border and layered shadow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const track = Track(
        id: 32,
        title: 'Soft artwork',
        audioPath: '/tmp/32.flac',
        videoPath: '',
        vocal: 'Miku',
      );

      await _pumpPlayer(
        tester,
        surfaceSize: const Size(430, 900),
        track: track,
        currentCoverUrl: 'http://127.0.0.1:8080/api/covers/32',
      );

      final artworkFinder = find.byKey(
        const ValueKey('mobile-player-artwork-frame'),
      );
      expect(artworkFinder, findsOneWidget);

      final artworkFrame = tester.widget<Container>(artworkFinder);
      final decoration = artworkFrame.decoration as BoxDecoration;
      final border = decoration.border as Border;
      final shadows = decoration.boxShadow!;

      expect(border.top.color, Colors.white.withValues(alpha: 0.045));
      expect(shadows, hasLength(2));
      expect(shadows.first.color, Colors.black.withValues(alpha: 0.38));
      expect(shadows.first.blurRadius, 40);
      expect(shadows.first.offset, const Offset(0, 22));
      expect(shadows.last.blurRadius, 56);
      expect(shadows.last.spreadRadius, -10);
    },
  );

  testWidgets(
    'mobile cover area swipes left into lyrics while controls stay fixed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const track = Track(
        id: 18,
        title: 'Swipe lyrics',
        audioPath: '/tmp/18.flac',
        videoPath: '',
        vocal: 'Miku',
        lyrics: '[00:00.00]first timed line\n[00:05.00]second timed line',
      );

      await _pumpPlayer(
        tester,
        surfaceSize: const Size(430, 900),
        track: track,
        currentCoverUrl: 'http://127.0.0.1:8080/api/covers/18',
      );

      expect(
        find.byKey(const ValueKey('mobile-player-media-pager')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mobile-player-artwork-page')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mobile-player-lyrics-page')),
        findsNothing,
      );
      expect(find.text('播放'), findsOneWidget);
      expect(find.text('歌词'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mobile-player-title-box')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('player-elapsed-label')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.shuffle), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mobile-player-queue-peek')),
        findsOneWidget,
      );

      final pagerRect = tester.getRect(
        find.byKey(const ValueKey('mobile-player-media-pager')),
      );
      expect(pagerRect.height, greaterThanOrEqualTo(370));

      await tester.tap(find.text('歌词'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const ValueKey('mobile-player-lyrics-page')),
        findsOneWidget,
      );
      expect(find.text('first timed line'), findsOneWidget);
      expect(find.text('second timed line'), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey('mobile-player-media-pager')),
        const Offset(-360, 0),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const ValueKey('mobile-player-lyrics-page')),
        findsOneWidget,
      );
      expect(find.text('first timed line'), findsOneWidget);
      expect(find.text('second timed line'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mobile-player-title-box')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('player-elapsed-label')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.shuffle), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mobile-player-queue-peek')),
        findsOneWidget,
      );
    },
  );

  testWidgets('mobile title is fixed-width single-line auto scrolling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const longTitle =
        'This is a very very long mobile player title that should scroll';
    const track = Track(
      id: 12,
      title: longTitle,
      audioPath: '/tmp/12.flac',
      videoPath: '',
      vocal: 'Miku',
    );

    await _pumpPlayer(tester, surfaceSize: const Size(430, 900), track: track);

    final titleBox = tester.widget<SizedBox>(
      find.byKey(const ValueKey('mobile-player-title-box')),
    );
    final titleText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('mobile-player-title-box')),
        matching: find.text(longTitle),
      ),
    );

    expect(titleBox.width, 254);
    expect(titleText.maxLines, 1);
    expect(titleText.softWrap, isFalse);
  });

  testWidgets('mobile shuffle button calls toggle callback', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var toggles = 0;

    await _pumpPlayer(
      tester,
      surfaceSize: const Size(430, 900),
      onToggleShuffle: () => toggles++,
    );

    await tester.tap(find.byIcon(Icons.shuffle));
    await tester.pump();

    expect(toggles, 1);
  });

  testWidgets('mobile player uses externally resolved current cover url', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const coverUrl = 'http://127.0.0.1:8080/api/videos/7/thumb';
    const track = Track(
      id: 7,
      title: 'MV only cover',
      audioPath: '/tmp/7.flac',
      videoPath: '',
      vocal: 'Miku',
    );

    await _pumpPlayer(
      tester,
      surfaceSize: const Size(430, 900),
      track: track,
      currentCoverUrl: coverUrl,
    );

    final images = tester.widgetList<Image>(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is NetworkImage,
      ),
    );

    expect(
      images
          .map((image) => image.image)
          .whereType<NetworkImage>()
          .map((image) => image.url),
      contains(coverUrl),
    );
  });

  testWidgets('empty credits use dash instead of unknown credits', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpPlayer(
      tester,
      surfaceSize: const Size(1600, 900),
      track: _creditlessTrack(),
    );

    expect(find.text('Unknown credits'), findsNothing);
    expect(find.text('-'), findsWidgets);
  });

  testWidgets(
    'initial playback labels start at 00:00 instead of placeholders',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpPlayer(tester, surfaceSize: const Size(1600, 900));

      final elapsedFinder = find.byKey(const ValueKey('player-elapsed-label'));
      final durationFinder = find.byKey(
        const ValueKey('player-duration-label'),
      );

      expect(elapsedFinder, findsOneWidget);
      expect(durationFinder, findsOneWidget);
      expect(tester.widget<Text>(elapsedFinder).data, '00:00');
      expect(tester.widget<Text>(durationFinder).data, '00:00');
    },
  );

  testWidgets('mobile landscape audio player hides side panel by default', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    try {
      await _pumpPlayer(tester, surfaceSize: const Size(844, 390));

      expect(
        find.byKey(const ValueKey('mobile-landscape-player')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mobile-landscape-player-side-panel')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('mobile-player-queue-peek')),
        findsNothing,
      );
      expect(find.byTooltip('收起'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('mobile landscape audio keeps favorite inside more menu', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    try {
      await _pumpPlayer(tester, surfaceSize: const Size(844, 390));

      final sliderRect = tester.getRect(find.byType(Slider));
      final moreRect = tester.getRect(find.byTooltip('更多'));

      expect(find.byTooltip('Add to favorites'), findsNothing);
      expect(moreRect.top, greaterThan(sliderRect.bottom));

      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();

      expect(find.text('收藏'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('mobile landscape audio play control is the primary button', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    try {
      await _pumpPlayer(tester, surfaceSize: const Size(844, 390));

      final playIcon = tester.widget<Icon>(find.byIcon(Icons.play_arrow));
      final playButtonFinder = find.ancestor(
        of: find.byIcon(Icons.play_arrow),
        matching: find.byType(IconButton),
      );
      final playButton = tester.widget<IconButton>(playButtonFinder);

      expect(playIcon.size ?? 0, greaterThanOrEqualTo(40));
      expect(playButton.style?.fixedSize?.resolve({}), const Size(64, 64));
      expect(playButton.style?.backgroundColor?.resolve({}), isNotNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('mobile landscape audio player uses mobile slider styling', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    try {
      await _pumpPlayer(tester, surfaceSize: const Size(844, 390));

      final sliderThemeFinder = find.descendant(
        of: find.byKey(const ValueKey('mobile-landscape-player')),
        matching: find.byType(SliderTheme),
      );
      expect(sliderThemeFinder, findsOneWidget);

      final sliderTheme = tester.widget<SliderTheme>(sliderThemeFinder);
      final activeTrackColor = sliderTheme.data.activeTrackColor!;
      expect(
        sliderTheme.data.overlayColor,
        activeTrackColor.withValues(alpha: 0.15),
      );
      expect(sliderTheme.data.trackHeight, 5);
      expect(sliderTheme.data.thumbShape, isA<AssetSliderThumbShape>());
      expect(
        sliderTheme.data.thumbShape!.getPreferredSize(true, false),
        const Size(18, 18),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'mobile landscape audio player stacks artwork metadata and controls',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.binding.setSurfaceSize(const Size(844, 390));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      try {
        await _pumpPlayer(tester, surfaceSize: const Size(844, 390));

        final artworkRect = tester.getRect(
          find.byKey(const ValueKey('mobile-player-artwork-frame')),
        );
        final titleRect = tester.getRect(find.text('ぽかぽかの星'));
        final subtitleRect = tester.getRect(find.text('はるまきごはん feat. Miku'));
        final sliderRect = tester.getRect(
          find.descendant(
            of: find.byKey(const ValueKey('mobile-landscape-player')),
            matching: find.byType(Slider),
          ),
        );
        final playButtonRect = tester.getRect(
          find.ancestor(
            of: find.byIcon(Icons.play_arrow),
            matching: find.byType(IconButton),
          ),
        );

        expect(
          (artworkRect.center.dx - titleRect.center.dx).abs(),
          lessThan(4),
        );
        expect(
          (artworkRect.center.dx - subtitleRect.center.dx).abs(),
          lessThan(4),
        );
        expect(artworkRect.bottom, lessThan(titleRect.top));
        expect(titleRect.bottom, lessThan(subtitleRect.top));
        expect(subtitleRect.bottom, lessThan(sliderRect.top));
        expect(sliderRect.bottom, lessThan(playButtonRect.top));
        expect(find.text('00:00'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('mobile landscape audio player opens lyrics and queue panel', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    try {
      const timedTrack = Track(
        id: 87,
        title: 'Landscape Lyrics',
        audioPath: '/tmp/87.flac',
        videoPath: '',
        lyrics: '[00:00.00]Line 0\n[00:05.00]Line 1\n[00:10.00]Line 2',
      );

      await _pumpPlayer(
        tester,
        surfaceSize: const Size(844, 390),
        track: timedTrack,
        queue: const [timedTrack],
        currentCoverUrl: 'https://example.test/cover.png',
      );

      await tester.tap(find.byTooltip('显示歌词和队列'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('mobile-landscape-player-side-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mobile-landscape-cover-atmosphere')),
        findsOneWidget,
      );
      expect(find.text('歌词'), findsNothing);
      expect(find.text('队列'), findsNothing);

      final panelRect = tester.getRect(
        find.byKey(const ValueKey('mobile-landscape-player-side-panel')),
      );
      final lyricsRect = tester.getRect(
        find.byKey(const ValueKey<String>('mobile-lyrics-follow-scroll')),
      );
      expect(lyricsRect.top - panelRect.top, lessThan(24));
      expect(lyricsRect.top - panelRect.top, greaterThanOrEqualTo(12));
      expect(panelRect.bottom - lyricsRect.bottom, greaterThanOrEqualTo(12));
      expect(lyricsRect.height, greaterThan(panelRect.height - 48));

      expect(
        find.byKey(const ValueKey('mobile-landscape-side-panel-surface')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('mobile-landscape-side-panel-content')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('mobile-landscape-side-panel-cover-atmosphere'),
        ),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey('mobile-landscape-player-side-panel')),
      );
      await tester.pumpAndSettle();
      expect(find.text('歌词'), findsOneWidget);
      expect(find.text('队列'), findsOneWidget);
      await tester.tap(find.text('队列'));
      await tester.pumpAndSettle();
      expect(find.text('Layout Test'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('mobile landscape hide panel control stays in panel header', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(640, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    try {
      await _pumpPlayer(tester, surfaceSize: const Size(640, 360));

      await tester.tap(find.byTooltip('显示歌词和队列'));
      await tester.pumpAndSettle();

      final sidePanel = find.byKey(
        const ValueKey('mobile-landscape-player-side-panel'),
      );
      expect(find.byTooltip('隐藏歌词和队列'), findsNothing);

      await tester.tap(sidePanel);
      await tester.pumpAndSettle();

      final panelRect = tester.getRect(sidePanel);
      final hideRect = tester.getRect(find.byTooltip('隐藏歌词和队列'));

      expect(hideRect.top - panelRect.top, lessThan(56));

      await tester.tap(find.byTooltip('隐藏歌词和队列'));
      await tester.pumpAndSettle();
      expect(sidePanel, findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('mobile landscape panel chrome auto hides after idle', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    try {
      await _pumpPlayer(tester, surfaceSize: const Size(844, 390));

      await tester.tap(find.byTooltip('显示歌词和队列'));
      await tester.pumpAndSettle();

      final sidePanel = find.byKey(
        const ValueKey('mobile-landscape-player-side-panel'),
      );
      await tester.tap(sidePanel);
      await tester.pumpAndSettle();
      expect(find.text('歌词'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('歌词'), findsNothing);
      expect(find.text('队列'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'mobile landscape audio player adapts side panel on small phones',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.binding.setSurfaceSize(const Size(640, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      try {
        await _pumpPlayer(tester, surfaceSize: const Size(640, 360));

        await tester.tap(find.byTooltip('显示歌词和队列'));
        await tester.pumpAndSettle();

        final sidePanel = find.byKey(
          const ValueKey('mobile-landscape-player-side-panel'),
        );
        expect(sidePanel, findsOneWidget);
        expect(tester.getRect(sidePanel).width, lessThan(320));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('mobile landscape panel tabs expose selected semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    try {
      await _pumpPlayer(tester, surfaceSize: const Size(844, 390));

      await tester.tap(find.byTooltip('显示歌词和队列'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('mobile-landscape-player-side-panel')),
      );
      await tester.pumpAndSettle();

      final lyricsSemantics = find.byKey(
        const ValueKey('mobile-landscape-panel-tab-lyrics'),
      );
      expect(lyricsSemantics, findsOneWidget);
      expect(
        tester.getSemantics(lyricsSemantics).flagsCollection.isSelected,
        ui.Tristate.isTrue,
      );

      await tester.tap(find.text('队列'));
      await tester.pumpAndSettle();

      final queueSemantics = find.byKey(
        const ValueKey('mobile-landscape-panel-tab-queue'),
      );
      expect(queueSemantics, findsOneWidget);
      expect(
        tester.getSemantics(queueSemantics).flagsCollection.isSelected,
        ui.Tristate.isTrue,
      );
    } finally {
      semantics.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('mobile landscape video queue button opens mobile queue modal', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const current = Track(
      id: 77,
      title: 'Landscape MV',
      audioPath: '/tmp/77.flac',
      videoPath: '/tmp/77.mp4',
      vocal: 'Miku',
    );
    const next = Track(
      id: 78,
      title: 'Next Landscape MV',
      audioPath: '/tmp/78.flac',
      videoPath: '/tmp/78.mp4',
      vocal: 'Miku',
    );

    try {
      await _pumpPlayer(
        tester,
        surfaceSize: const Size(844, 390),
        track: current,
        queue: const [current, next],
        playbackMode: PlaybackMode.video,
      );

      expect(
        find.byKey(const ValueKey('mobile-mv-player-surface')),
        findsOneWidget,
      );
      final queueButton = find.byKey(const ValueKey('mobile-mv-queue-button'));
      expect(queueButton, findsOneWidget);

      await tester.ensureVisible(queueButton);
      await tester.pumpAndSettle();
      await tester.tap(queueButton);
      await tester.pumpAndSettle();

      expect(find.text('Next Landscape MV'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

class _FavoriteRecordingHttpClient implements HttpClient {
  final requests = <String>[];

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => openUrl('GET', url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    requests.add('$method ${url.path}');
    return _FavoriteRecordingHttpClientRequest(method, url);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FavoriteRecordingHttpClientRequest implements HttpClientRequest {
  _FavoriteRecordingHttpClientRequest(this.method, this.url);

  @override
  final String method;
  final Uri url;
  bool _followRedirects = true;
  int _maxRedirects = 5;
  int _contentLength = 0;
  bool _persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async =>
      _FavoriteRecordingHttpClientResponse(method, url);

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding _) {}

  @override
  bool get followRedirects => _followRedirects;

  @override
  set followRedirects(bool value) {
    _followRedirects = value;
  }

  @override
  int get maxRedirects => _maxRedirects;

  @override
  set maxRedirects(int value) {
    _maxRedirects = value;
  }

  @override
  int get contentLength => _contentLength;

  @override
  set contentLength(int value) {
    _contentLength = value;
  }

  @override
  bool get persistentConnection => _persistentConnection;

  @override
  set persistentConnection(bool value) {
    _persistentConnection = value;
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FavoriteRecordingHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FavoriteRecordingHttpClientResponse(String method, Uri url)
    : statusCode = method == 'POST' && url.path == '/api/favorites/7'
          ? HttpStatus.noContent
          : HttpStatus.ok,
      _bytes = utf8.encode(
        method == 'POST' ? '' : '<svg xmlns="http://www.w3.org/2000/svg" />',
      );

  final List<int> _bytes;

  @override
  final int statusCode;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpHeaders get headers => _FavoriteRecordingHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<Cookie> get cookies => const [];

  @override
  Future<Socket> detachSocket() {
    throw UnimplementedError();
  }

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  String get reasonPhrase =>
      statusCode == HttpStatus.noContent ? 'No Content' : 'OK';

  @override
  bool get persistentConnection => false;

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) {
    throw UnimplementedError();
  }

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> data)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FavoriteRecordingHttpHeaders implements HttpHeaders {
  static const Map<String, List<String>> _values = {
    HttpHeaders.contentTypeHeader: ['image/svg+xml'],
  };

  @override
  List<String>? operator [](String name) => _values[name.toLowerCase()];

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final List<Duration> seekPositions = [];
  final Map<int, StreamController<VideoEvent>> _streams = {};
  final Map<int, Duration> _positions = {};
  var _nextPlayerId = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final playerId = _nextPlayerId++;
    final stream = StreamController<VideoEvent>();
    _streams[playerId] = stream;
    stream.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        size: const Size(100, 100),
        duration: const Duration(seconds: 1),
      ),
    );
    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _streams[playerId]!.stream;

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    seekPositions.add(position);
    _positions[playerId] = position;
  }

  @override
  Future<void> dispose(int playerId) async {
    await _streams.remove(playerId)?.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async =>
      _positions[playerId] ?? Duration.zero;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) {
    return const ColoredBox(color: Colors.black);
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setAllowBackgroundPlayback(bool allowBackgroundPlayback) async {}

  @override
  Future<void> setWebOptions(
    int playerId,
    VideoPlayerWebOptions options,
  ) async {}
}
