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
  }) {}

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
  bool Function()? mediaSessionCanSeek,
}) {
  return MaterialApp(
    home: PlayerScreen(
      track: queue[currentIndex],
      queue: queue,
      currentIndex: currentIndex,
      contextLabel: 'Queue Test',
      playbackMode: PlaybackMode.audio,
      onSelectTrack: (_) {},
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

        expect(mediaSession.previousHandler, isNull);
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
        expect(mediaSession.nextHandler, isNull);

        await staleNext();
        expect(nextCount, 1);

        await mediaSession.previousHandler!();
        expect(previousCount, 1);
      },
    );
  });
}
