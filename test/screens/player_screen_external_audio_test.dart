import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/screens/library_home_screen.dart';
import 'package:mikudrome/screens/player_screen.dart';
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

Widget _buildPlayer({
  Track track = _track,
  required double externalProgress,
  required bool externalIsPlaying,
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
      data: const MediaQueryData(size: Size(430, 900)),
      child: PlayerScreen(
        track: track,
        queue: [track],
        currentIndex: 0,
        contextLabel: 'External Audio Test',
        playbackMode: PlaybackMode.audio,
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
        externalProgress: externalProgress,
        onExternalPause: onExternalPause,
        onExternalSeekToFraction: onExternalSeekToFraction,
      ),
    ),
  );
}

void main() {
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
