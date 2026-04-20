import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/screens/library_home_screen.dart';
import 'package:mikudrome/screens/player_screen.dart';
import 'package:mikudrome/services/web_media_session_contract.dart';

class _FakeWebMediaSessionService implements WebMediaSessionService {
  WebMediaSessionVoidHandler? playHandler;
  WebMediaSessionVoidHandler? pauseHandler;
  WebMediaSessionVoidHandler? previousHandler;
  WebMediaSessionVoidHandler? nextHandler;
  WebMediaSessionSeekHandler? seekToHandler;
  String? metadataTitle;
  String? metadataArtist;

  @override
  void clear() {}

  @override
  void setActionHandlers({
    required WebMediaSessionVoidHandler onPlay,
    required WebMediaSessionVoidHandler onPause,
    WebMediaSessionVoidHandler? onPrevious,
    WebMediaSessionVoidHandler? onNext,
    WebMediaSessionSeekHandler? onSeekTo,
  }) {
    playHandler = onPlay;
    pauseHandler = onPause;
    previousHandler = onPrevious;
    nextHandler = onNext;
    seekToHandler = onSeekTo;
  }

  @override
  void setMetadata({
    required String title,
    required String artist,
    String? album,
    String? artworkUrl,
  }) {
    metadataTitle = title;
    metadataArtist = artist;
  }

  @override
  void setPlaybackState({required bool isPlaying}) {}

  @override
  void setPositionState({
    required int positionMs,
    required int durationMs,
    required double playbackRate,
  }) {}
}

Track _track(int id) => Track(
      id: id,
      title: 'Track $id',
      audioPath: '/tmp/$id.flac',
      videoPath: '',
      composer: 'Composer $id',
    );

Widget _buildPlayer({
  required _FakeWebMediaSessionService mediaSession,
  required List<Track> queue,
  required int currentIndex,
  required VoidCallback onPrevious,
  required VoidCallback onNext,
  ValueChanged<int>? onSelectTrack,
  bool Function()? mediaSessionCanSeek,
}) {
  return MaterialApp(
    home: PlayerScreen(
      track: queue[currentIndex],
      queue: queue,
      currentIndex: currentIndex,
      contextLabel: 'Queue Test',
      playbackMode: PlaybackMode.audio,
      onSelectTrack: onSelectTrack ?? (_) {},
      onPrevious: onPrevious,
      onNext: onNext,
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
      mediaSessionService: mediaSession,
      mediaSessionCanSeek: mediaSessionCanSeek,
      initializeControllerOnStart: false,
    ),
  );
}

void main() {
  group('PlayerScreen media session wiring', () {
    testWidgets('artist metadata matches vocalLine display', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mediaSession = _FakeWebMediaSessionService();
      final queue = [
        const Track(
          id: 1,
          title: 'Song',
          audioPath: '/tmp/1.flac',
          videoPath: '',
          composer: 'Producer A',
          lyricist: 'Lyricist B',
          vocal: 'Miku',
        ),
      ];

      await tester.pumpWidget(
        _buildPlayer(
          mediaSession: mediaSession,
          queue: queue,
          currentIndex: 0,
          onPrevious: () {},
          onNext: () {},
        ),
      );

      expect(mediaSession.metadataArtist, queue.first.vocalLine);
    });

    testWidgets(
      'single-item queue still registers prev/next handlers for media controls',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1920, 1080));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final mediaSession = _FakeWebMediaSessionService();
        final queue = [_track(1)];

        await tester.pumpWidget(
          _buildPlayer(
            mediaSession: mediaSession,
            queue: queue,
            currentIndex: 0,
            onPrevious: () {},
            onNext: () {},
          ),
        );

        expect(mediaSession.previousHandler, isNotNull);
        expect(mediaSession.nextHandler, isNotNull);
      },
    );

    testWidgets('seek handler is gated by seek capability', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mediaSession = _FakeWebMediaSessionService();
      final queue = [_track(1), _track(1)];

      await tester.pumpWidget(
        _buildPlayer(
          mediaSession: mediaSession,
          queue: queue,
          currentIndex: 0,
          onPrevious: () {},
          onNext: () {},
          mediaSessionCanSeek: () => false,
        ),
      );

      expect(mediaSession.seekToHandler, isNull);

      await tester.pumpWidget(
        _buildPlayer(
          mediaSession: mediaSession,
          queue: queue,
          currentIndex: 0,
          onPrevious: () {},
          onNext: () {},
          mediaSessionCanSeek: () => true,
        ),
      );

      expect(mediaSession.seekToHandler, isNotNull);
    });

    testWidgets(
      'rebind updates handlers when callback identity changes',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1920, 1080));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final mediaSession = _FakeWebMediaSessionService();
        final queue = [_track(1), _track(1)];
        var oldNextCount = 0;
        var newNextCount = 0;

        await tester.pumpWidget(
          _buildPlayer(
            mediaSession: mediaSession,
            queue: queue,
            currentIndex: 0,
            onPrevious: () {},
            onNext: () => oldNextCount++,
          ),
        );

        final staleNext = mediaSession.nextHandler!;
        await staleNext();
        expect(oldNextCount, 1);
        expect(newNextCount, 0);

        await tester.pumpWidget(
          _buildPlayer(
            mediaSession: mediaSession,
            queue: queue,
            currentIndex: 0,
            onPrevious: () {},
            onNext: () => newNextCount++,
          ),
        );

        await staleNext();
        expect(oldNextCount, 1);
        expect(newNextCount, 0);

        await mediaSession.nextHandler!();
        expect(oldNextCount, 1);
        expect(newNextCount, 1);
      },
    );

    testWidgets(
      'rebind updates prev/next handlers and suppresses stale callbacks',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1920, 1080));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final mediaSession = _FakeWebMediaSessionService();
        final queue = [_track(1), _track(1)];
        var previousCount = 0;
        var nextCount = 0;

        await tester.pumpWidget(
          _buildPlayer(
            mediaSession: mediaSession,
            queue: queue,
            currentIndex: 0,
            onPrevious: () => previousCount++,
            onNext: () => nextCount++,
          ),
        );

        expect(mediaSession.previousHandler, isNotNull);
        expect(mediaSession.nextHandler, isNotNull);

        final staleNext = mediaSession.nextHandler!;
        await staleNext();
        expect(nextCount, 1);

        await tester.pumpWidget(
          _buildPlayer(
            mediaSession: mediaSession,
            queue: queue,
            currentIndex: 1,
            onPrevious: () => previousCount++,
            onNext: () => nextCount++,
          ),
        );

        expect(mediaSession.previousHandler, isNotNull);
        expect(mediaSession.nextHandler, isNotNull);

        await staleNext();
        expect(nextCount, 1);

        await mediaSession.previousHandler!();
        expect(previousCount, 1);

        await mediaSession.nextHandler!();
        expect(nextCount, 2);
      },
    );

    testWidgets(
      'next handler updates media session metadata immediately',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1920, 1080));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final mediaSession = _FakeWebMediaSessionService();
        final queue = [_track(1), _track(2)];
        var nextCount = 0;

        await tester.pumpWidget(
          _buildPlayer(
            mediaSession: mediaSession,
            queue: queue,
            currentIndex: 0,
            onPrevious: () {},
            onNext: () => nextCount++,
          ),
        );

        expect(mediaSession.metadataTitle, queue.first.title);

        await mediaSession.nextHandler!();

        expect(nextCount, 1);
        expect(mediaSession.metadataTitle, queue[1].title);
      },
    );
  });
}
