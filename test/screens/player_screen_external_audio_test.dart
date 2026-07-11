import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/screens/library_home_screen.dart';
import 'package:mikudrome/screens/player_screen.dart';
import 'package:mikudrome/theme/vocal_theme.dart';
import 'package:mikudrome/widgets/player/asset_slider_thumb_shape.dart';

const _track = Track(
  id: 1,
  title: 'External audio track',
  audioPath: '/tmp/1.flac',
  videoPath: '',
  durationSeconds: 120,
  composer: 'Composer',
);

const _timedLyricTrack = Track(
  id: 2,
  title: 'External audio timed lyrics',
  audioPath: '/tmp/2.flac',
  videoPath: '',
  durationSeconds: 100,
  composer: 'Composer',
  lyrics: '[00:00.00]first line\n[00:30.00]second line',
);

const _darkAccent = Color(0xFF0000FF);
const _darkAccentTrack = Track(
  id: 3,
  title: 'Dark accent external audio',
  audioPath: '/tmp/3.flac',
  videoPath: '',
  durationSeconds: 120,
  vocal: 'KAITO',
);

const _brightAccent = Color(0xFFFFE211);
const _brightAccentTrack = Track(
  id: 4,
  title: 'Bright accent external audio',
  audioPath: '/tmp/4.flac',
  videoPath: '',
  durationSeconds: 120,
  vocal: '鏡音レン',
);

const _midtoneAccent = Color(0xFF60A6C3);
const _midtoneAccentTrack = Track(
  id: 5,
  title: 'Multi-vocal midtone external audio',
  audioPath: '/tmp/5.flac',
  videoPath: '',
  durationSeconds: 120,
  vocal: '初音ミク;朝比奈まふゆ',
);

const _videoTrack = Track(
  id: 6,
  title: 'Video track',
  audioPath: '/tmp/6.flac',
  videoPath: '/tmp/6.mp4',
  durationSeconds: 120,
);

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void _expectLoadingControlContrast(
  WidgetTester tester, {
  required Color accentColor,
  Color? expectedForegroundColor,
}) {
  final indicatorFinder = find.byKey(
    const ValueKey('player-external-audio-loading-indicator'),
  );
  final buttonFinder = find.ancestor(
    of: indicatorFinder,
    matching: find.byType(IconButton),
  );
  final indicator = tester.widget<CircularProgressIndicator>(indicatorFinder);
  final button = tester.widget<IconButton>(buttonFinder);
  final disabledBackground = button.style?.backgroundColor?.resolve({
    WidgetState.disabled,
  });

  expect(disabledBackground, accentColor);
  expect(indicator.semanticsLabel, '音频加载中');
  if (expectedForegroundColor != null) {
    expect(indicator.color, expectedForegroundColor);
    expect(
      _contrastRatio(indicator.color!, disabledBackground!),
      closeTo(_contrastRatio(expectedForegroundColor, accentColor), 0.001),
    );
  }
  expect(
    _contrastRatio(indicator.color!, disabledBackground!),
    greaterThanOrEqualTo(4.5),
  );
}

Widget _buildLoadingPlayer({
  required Track track,
  Size surfaceSize = const Size(430, 900),
}) {
  return _buildPlayer(
    track: track,
    surfaceSize: surfaceSize,
    externalProgress: 0.25,
    externalIsPlaying: false,
    externalIsLoading: true,
    onExternalPause: () async {},
    onExternalSeekToFraction: (_) async {},
    onControlsReady: ({required togglePlayback, required seekToFraction}) {},
    onPlaybackStateChanged:
        ({
          required bool isPlaying,
          required double progress,
          required String elapsedLabel,
          required String durationLabel,
        }) {},
  );
}

Widget _buildPlayer({
  Track track = _track,
  Size surfaceSize = const Size(430, 900),
  PlaybackMode playbackMode = PlaybackMode.audio,
  required double externalProgress,
  required bool externalIsPlaying,
  bool externalIsLoading = false,
  Future<void> Function()? onExternalPlay,
  required Future<void> Function() onExternalPause,
  required PlayerSeekToFraction onExternalSeekToFraction,
  required PlayerControlsReady onControlsReady,
  required void Function({
    required bool isPlaying,
    required double progress,
    required String elapsedLabel,
    required String durationLabel,
  })
  onPlaybackStateChanged,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: surfaceSize),
      child: VocalThemeProvider(
        track: track,
        child: PlayerScreen(
          track: track,
          queue: [track],
          currentIndex: 0,
          contextLabel: 'External Audio Test',
          playbackMode: playbackMode,
          onSelectTrack: (_) {},
          onPrevious: () {},
          onNext: () {},
          onClose: () {},
          onSwitchPlaybackMode: (_) {},
          playbackOrderMode: PlaybackOrderMode.sequential,
          onCyclePlaybackOrderMode: () {},
          onPlaybackStateChanged: onPlaybackStateChanged,
          onControlsReady: onControlsReady,
          initializeControllerOnStart: false,
          useExternalAudioPlayback: true,
          externalIsPlaying: externalIsPlaying,
          externalIsLoading: externalIsLoading,
          externalProgress: externalProgress,
          onExternalPlay: onExternalPlay,
          onExternalPause: onExternalPause,
          onExternalSeekToFraction: onExternalSeekToFraction,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('loading external audio disables mobile portrait play control', (
    tester,
  ) async {
    var playCalls = 0;
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayer(
        track: _darkAccentTrack,
        externalProgress: 0.25,
        externalIsPlaying: false,
        externalIsLoading: true,
        onExternalPlay: () async => playCalls += 1,
        onExternalPause: () async {},
        onExternalSeekToFraction: (_) async {},
        onControlsReady:
            ({required togglePlayback, required seekToFraction}) {},
        onPlaybackStateChanged:
            ({
              required bool isPlaying,
              required double progress,
              required String elapsedLabel,
              required String durationLabel,
            }) {},
      ),
    );

    final indicator = find.byKey(
      const ValueKey('player-external-audio-loading-indicator'),
    );
    final centralButton = find.ancestor(
      of: indicator,
      matching: find.byType(IconButton),
    );

    expect(indicator, findsOneWidget);
    expect(centralButton, findsOneWidget);
    expect(tester.widget<IconButton>(centralButton).onPressed, isNull);
    _expectLoadingControlContrast(tester, accentColor: _darkAccent);

    await tester.tap(centralButton);
    await tester.pump();

    expect(playCalls, 0);
  });

  testWidgets(
    'loading external audio disables native phone landscape play control',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.binding.setSurfaceSize(const Size(844, 390));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var playCalls = 0;

      try {
        await tester.pumpWidget(
          _buildPlayer(
            track: _darkAccentTrack,
            surfaceSize: const Size(844, 390),
            externalProgress: 0.25,
            externalIsPlaying: false,
            externalIsLoading: true,
            onExternalPlay: () async => playCalls += 1,
            onExternalPause: () async {},
            onExternalSeekToFraction: (_) async {},
            onControlsReady:
                ({required togglePlayback, required seekToFraction}) {},
            onPlaybackStateChanged:
                ({
                  required bool isPlaying,
                  required double progress,
                  required String elapsedLabel,
                  required String durationLabel,
                }) {},
          ),
        );

        final indicator = find.byKey(
          const ValueKey('player-external-audio-loading-indicator'),
        );
        final centralButton = find.ancestor(
          of: indicator,
          matching: find.byType(IconButton),
        );

        expect(
          find.byKey(const ValueKey('mobile-landscape-player')),
          findsOneWidget,
        );
        expect(indicator, findsOneWidget);
        expect(tester.widget<IconButton>(centralButton).onPressed, isNull);
        _expectLoadingControlContrast(tester, accentColor: _darkAccent);

        await tester.tap(centralButton);
        await tester.pump();

        expect(playCalls, 0);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('multi-vocal midtone uses maximum contrast in mobile portrait', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final resolvedAccent = VocalColors.resolveColor(_midtoneAccentTrack);

    expect(resolvedAccent, _midtoneAccent);
    await tester.pumpWidget(_buildLoadingPlayer(track: _midtoneAccentTrack));

    _expectLoadingControlContrast(
      tester,
      accentColor: resolvedAccent,
      expectedForegroundColor: Colors.black,
    );
  });

  testWidgets(
    'multi-vocal midtone uses maximum contrast in native phone landscape',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.binding.setSurfaceSize(const Size(844, 390));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final resolvedAccent = VocalColors.resolveColor(_midtoneAccentTrack);

      try {
        expect(resolvedAccent, _midtoneAccent);
        await tester.pumpWidget(
          _buildLoadingPlayer(
            track: _midtoneAccentTrack,
            surfaceSize: const Size(844, 390),
          ),
        );

        expect(
          find.byKey(const ValueKey('mobile-landscape-player')),
          findsOneWidget,
        );
        _expectLoadingControlContrast(
          tester,
          accentColor: resolvedAccent,
          expectedForegroundColor: Colors.black,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('bright external accent uses a dark loading foreground', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayer(
        track: _brightAccentTrack,
        externalProgress: 0.25,
        externalIsPlaying: false,
        externalIsLoading: true,
        onExternalPause: () async {},
        onExternalSeekToFraction: (_) async {},
        onControlsReady:
            ({required togglePlayback, required seekToFraction}) {},
        onPlaybackStateChanged:
            ({
              required bool isPlaying,
              required double progress,
              required String elapsedLabel,
              required String durationLabel,
            }) {},
      ),
    );

    _expectLoadingControlContrast(tester, accentColor: _brightAccent);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byKey(
              const ValueKey('player-external-audio-loading-indicator'),
            ),
          )
          .color,
      Colors.black,
    );
  });

  testWidgets(
    'non-loading external audio keeps mobile play and pause actions',
    (tester) async {
      var playCalls = 0;
      var pauseCalls = 0;
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Widget buildPlayer({required bool isPlaying}) => _buildPlayer(
        externalProgress: 0.25,
        externalIsPlaying: isPlaying,
        onExternalPlay: () async => playCalls += 1,
        onExternalPause: () async => pauseCalls += 1,
        onExternalSeekToFraction: (_) async {},
        onControlsReady:
            ({required togglePlayback, required seekToFraction}) {},
        onPlaybackStateChanged:
            ({
              required bool isPlaying,
              required double progress,
              required String elapsedLabel,
              required String durationLabel,
            }) {},
      );

      await tester.pumpWidget(buildPlayer(isPlaying: false));
      expect(
        find.byKey(const ValueKey('player-external-audio-loading-indicator')),
        findsNothing,
      );
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      await tester.pumpWidget(buildPlayer(isPlaying: true));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();

      expect(playCalls, 1);
      expect(pauseCalls, 1);
    },
  );

  testWidgets('external loading does not disable desktop audio controls', (
    tester,
  ) async {
    var playCalls = 0;
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayer(
        surfaceSize: const Size(1280, 1000),
        externalProgress: 0.25,
        externalIsPlaying: false,
        externalIsLoading: true,
        onExternalPlay: () async => playCalls += 1,
        onExternalPause: () async {},
        onExternalSeekToFraction: (_) async {},
        onControlsReady:
            ({required togglePlayback, required seekToFraction}) {},
        onPlaybackStateChanged:
            ({
              required bool isPlaying,
              required double progress,
              required String elapsedLabel,
              required String durationLabel,
            }) {},
      ),
    );

    expect(
      find.byKey(const ValueKey('player-external-audio-loading-indicator')),
      findsNothing,
    );
    final playButton = find.ancestor(
      of: find.byIcon(Icons.play_circle_fill),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(playButton).onPressed, isNotNull);

    await tester.tap(playButton);
    await tester.pump();

    expect(playCalls, 1);
  });

  testWidgets('external loading does not disable mobile video controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayer(
        track: _videoTrack,
        playbackMode: PlaybackMode.video,
        externalProgress: 0.25,
        externalIsPlaying: false,
        externalIsLoading: true,
        onExternalPause: () async {},
        onExternalSeekToFraction: (_) async {},
        onControlsReady:
            ({required togglePlayback, required seekToFraction}) {},
        onPlaybackStateChanged:
            ({
              required bool isPlaying,
              required double progress,
              required String elapsedLabel,
              required String durationLabel,
            }) {},
      ),
    );

    expect(
      find.byKey(const ValueKey('player-external-audio-loading-indicator')),
      findsNothing,
    );
    final playButton = find.ancestor(
      of: find.byIcon(Icons.play_circle),
      matching: find.byType(IconButton),
    );
    expect(playButton, findsOneWidget);
    expect(tester.widget<IconButton>(playButton).onPressed, isNotNull);
  });

  testWidgets('external audio pause does not emit stale zero progress', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var parentProgress = 0.4;
    final emittedProgresses = <double>[];
    PlayerTogglePlayback? capturedTogglePlayback;

    await tester.pumpWidget(
      _buildPlayer(
        externalProgress: parentProgress,
        externalIsPlaying: true,
        onExternalPause: () async {},
        onExternalSeekToFraction: (_) async {},
        onControlsReady: ({required togglePlayback, required seekToFraction}) {
          capturedTogglePlayback = togglePlayback;
        },
        onPlaybackStateChanged:
            ({
              required bool isPlaying,
              required double progress,
              required String elapsedLabel,
              required String durationLabel,
            }) {
              emittedProgresses.add(progress);
              parentProgress = progress;
            },
      ),
    );

    emittedProgresses.clear();
    final togglePlayback = capturedTogglePlayback;
    expect(togglePlayback, isNotNull);
    await togglePlayback!();

    expect(parentProgress, 0.4);
    expect(emittedProgresses, isNot(contains(0.0)));
  });

  testWidgets('external audio seek does not emit stale zero progress', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var parentProgress = 0.0;
    final emittedProgresses = <double>[];
    PlayerSeekToFraction? capturedSeekToFraction;

    await tester.pumpWidget(
      _buildPlayer(
        externalProgress: parentProgress,
        externalIsPlaying: false,
        onExternalPause: () async {},
        onExternalSeekToFraction: (value) async {
          parentProgress = value;
        },
        onControlsReady: ({required togglePlayback, required seekToFraction}) {
          capturedSeekToFraction = seekToFraction;
        },
        onPlaybackStateChanged:
            ({
              required bool isPlaying,
              required double progress,
              required String elapsedLabel,
              required String durationLabel,
            }) {
              emittedProgresses.add(progress);
              parentProgress = progress;
            },
      ),
    );

    emittedProgresses.clear();
    final seekToFraction = capturedSeekToFraction;
    expect(seekToFraction, isNotNull);
    await seekToFraction!(0.5);

    expect(parentProgress, 0.5);
    expect(emittedProgresses, isNot(contains(0.0)));
  });

  testWidgets('external audio progress updates active mobile lyrics', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayer(
        track: _timedLyricTrack,
        externalProgress: 0,
        externalIsPlaying: true,
        onExternalPause: () async {},
        onExternalSeekToFraction: (_) async {},
        onControlsReady:
            ({required togglePlayback, required seekToFraction}) {},
        onPlaybackStateChanged:
            ({
              required bool isPlaying,
              required double progress,
              required String elapsedLabel,
              required String durationLabel,
            }) {},
      ),
    );
    await tester.pump();
    await tester.tap(find.text('歌词'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('lyrics-line-active-0')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _buildPlayer(
        track: _timedLyricTrack,
        externalProgress: 0.35,
        externalIsPlaying: true,
        onExternalPause: () async {},
        onExternalSeekToFraction: (_) async {},
        onControlsReady:
            ({required togglePlayback, required seekToFraction}) {},
        onPlaybackStateChanged:
            ({
              required bool isPlaying,
              required double progress,
              required String elapsedLabel,
              required String durationLabel,
            }) {},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey<String>('lyrics-line-active-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('lyrics-line-active-0')),
      findsNothing,
    );
  });

  testWidgets('external audio advances active mobile lyrics between updates', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayer(
        track: _timedLyricTrack,
        externalProgress: 0.299,
        externalIsPlaying: true,
        onExternalPause: () async {},
        onExternalSeekToFraction: (_) async {},
        onControlsReady:
            ({required togglePlayback, required seekToFraction}) {},
        onPlaybackStateChanged:
            ({
              required bool isPlaying,
              required double progress,
              required String elapsedLabel,
              required String durationLabel,
            }) {},
      ),
    );
    await tester.pump();
    await tester.tap(find.text('歌词'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('lyrics-line-active-0')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('lyrics-line-active-1')),
      findsOneWidget,
    );
  });

  testWidgets('mobile player timeline uses the asset thumb', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayer(
        externalProgress: 0.25,
        externalIsPlaying: true,
        onExternalPause: () async {},
        onExternalSeekToFraction: (_) async {},
        onControlsReady:
            ({required togglePlayback, required seekToFraction}) {},
        onPlaybackStateChanged:
            ({
              required bool isPlaying,
              required double progress,
              required String elapsedLabel,
              required String durationLabel,
            }) {},
      ),
    );

    final sliderTheme = tester.widget<SliderTheme>(
      find.ancestor(
        of: find.byType(Slider),
        matching: find.byType(SliderTheme),
      ),
    );

    expect(sliderTheme.data.thumbShape, isA<AssetSliderThumbShape>());
  });
}
