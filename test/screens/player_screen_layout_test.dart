import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/screens/library_home_screen.dart';
import 'package:mikudrome/screens/player_screen.dart';

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
}) {
  final resolvedTrack = track ?? _desktopTrack();
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: surfaceSize),
      child: PlayerScreen(
        track: resolvedTrack,
        queue: [resolvedTrack],
        currentIndex: 0,
        contextLabel: 'Layout Test',
        playbackMode: PlaybackMode.audio,
        onSelectTrack: (_) {},
        onPrevious: () {},
        onNext: () {},
        onClose: () {},
        onSwitchPlaybackMode: (_) {},
        playbackOrderMode: PlaybackOrderMode.sequential,
        onCyclePlaybackOrderMode: () {},
        onPlaybackStateChanged: ({
          required bool isPlaying,
          required double progress,
          required String elapsedLabel,
          required String durationLabel,
        }) {},
        initializeControllerOnStart: false,
      ),
    ),
  );
}

Future<void> _pumpPlayer(
  WidgetTester tester, {
  required Size surfaceSize,
  Track? track,
}) async {
  await tester.pumpWidget(_buildPlayer(surfaceSize: surfaceSize, track: track));
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (!tester.binding.hasScheduledFrame) {
      break;
    }
  }
}

void main() {
  testWidgets('non-mobile audio keeps title inside the left media column',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpPlayer(tester, surfaceSize: const Size(1600, 900));

    expect(find.byKey(const ValueKey('player-audio-left-column')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('player-audio-title-block')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('player-audio-cover-block')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('player-audio-lyrics-panel')),
        findsOneWidget);

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

  testWidgets('intermediate non-mobile width uses the same moved-title layout',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpPlayer(tester, surfaceSize: const Size(1200, 900));

    expect(find.byKey(const ValueKey('player-audio-left-column')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('player-audio-title-block')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('player-audio-cover-block')),
        findsOneWidget);
  });

  testWidgets('non-mobile left media column stays vertically centered',
      (tester) async {
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

    expect(find.byKey(const ValueKey('player-audio-left-column')),
        findsNothing);
    expect(find.byKey(const ValueKey('player-audio-title-block')),
        findsNothing);
  });

  testWidgets('empty credits use dash instead of unknown credits',
      (tester) async {
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

  testWidgets('initial playback labels start at 00:00 instead of placeholders',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpPlayer(tester, surfaceSize: const Size(1600, 900));

    final elapsedFinder = find.byKey(const ValueKey('player-elapsed-label'));
    final durationFinder = find.byKey(const ValueKey('player-duration-label'));

    expect(elapsedFinder, findsOneWidget);
    expect(durationFinder, findsOneWidget);
    expect(tester.widget<Text>(elapsedFinder).data, '00:00');
    expect(tester.widget<Text>(durationFinder).data, '00:00');
  });
}
