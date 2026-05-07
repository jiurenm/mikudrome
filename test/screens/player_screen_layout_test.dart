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
  String? currentCoverUrl,
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
}
