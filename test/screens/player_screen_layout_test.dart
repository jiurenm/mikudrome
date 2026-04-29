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
  List<Track>? queue,
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
        playbackMode: PlaybackMode.audio,
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
      ),
    ),
  );
}

Future<void> _pumpPlayer(
  WidgetTester tester, {
  required Size surfaceSize,
  Track? track,
  List<Track>? queue,
}) async {
  await tester.pumpWidget(
    _buildPlayer(surfaceSize: surfaceSize, track: track, queue: queue),
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

  testWidgets('mobile player uses immersive playback layout with queue', (
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
    );

    expect(
      find.byKey(const ValueKey('mobile-player-immersive')),
      findsOneWidget,
    );
    expect(find.text('播放'), findsOneWidget);
    expect(find.text('歌词'), findsOneWidget);
    expect(find.text('Layout Test'), findsNothing);
    expect(find.byIcon(Icons.movie), findsNothing);
    expect(find.text('已收藏'), findsOneWidget);
    expect(find.text('加入歌单'), findsOneWidget);
    expect(find.text('下载'), findsOneWidget);
    expect(find.text('音效'), findsOneWidget);
    expect(find.text('更多'), findsOneWidget);
    expect(find.text('接下来播放'), findsOneWidget);
    expect(find.text('清空'), findsOneWidget);
    expect(find.text('ヒバナ'), findsOneWidget);
    expect(find.text('ゴーストルール'), findsOneWidget);
    expect(find.text('アンチビート'), findsOneWidget);
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
}
