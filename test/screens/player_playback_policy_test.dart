import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/screens/library_home_screen.dart';
import 'package:mikudrome/screens/player_playback_policy.dart';

void main() {
  group('didPlaybackReachEnd', () {
    test('treats completed state as ended even before position catches up', () {
      expect(
        didPlaybackReachEnd(
          isCompleted: true,
          isPlaying: false,
          position: const Duration(seconds: 9),
          duration: const Duration(seconds: 10),
        ),
        isTrue,
      );
    });

    test('returns false when media has no valid duration', () {
      expect(
        didPlaybackReachEnd(
          isCompleted: true,
          isPlaying: false,
          position: Duration.zero,
          duration: Duration.zero,
        ),
        isFalse,
      );
    });
  });

  group('resolvePlaybackCompletionCommand', () {
    test('sequential mode advances when another track exists', () {
      expect(
        resolvePlaybackCompletionCommand(
          orderMode: PlaybackOrderMode.sequential,
          hasNext: true,
        ),
        PlaybackCompletionCommand.playNext,
      );
    });

    test('sequential mode stops at the last track', () {
      expect(
        resolvePlaybackCompletionCommand(
          orderMode: PlaybackOrderMode.sequential,
          hasNext: false,
        ),
        PlaybackCompletionCommand.none,
      );
    });

    test('list loop wraps to the first track when no next track exists', () {
      expect(
        resolvePlaybackCompletionCommand(
          orderMode: PlaybackOrderMode.listLoop,
          hasNext: false,
        ),
        PlaybackCompletionCommand.restartTrack,
      );
    });

    test('single loop always restarts the current track', () {
      expect(
        resolvePlaybackCompletionCommand(
          orderMode: PlaybackOrderMode.singleLoop,
          hasNext: true,
        ),
        PlaybackCompletionCommand.restartTrack,
      );
    });
  });

  group('resolveRelativePlaybackIndex', () {
    test('sequential mode does not move before the first track', () {
      expect(
        resolveRelativePlaybackIndex(
          orderMode: PlaybackOrderMode.sequential,
          currentIndex: 0,
          queueLength: 3,
          delta: -1,
        ),
        isNull,
      );
    });

    test('sequential mode does not move after the last track', () {
      expect(
        resolveRelativePlaybackIndex(
          orderMode: PlaybackOrderMode.sequential,
          currentIndex: 2,
          queueLength: 3,
          delta: 1,
        ),
        isNull,
      );
    });

    test('list loop wraps previous from first track to last track', () {
      expect(
        resolveRelativePlaybackIndex(
          orderMode: PlaybackOrderMode.listLoop,
          currentIndex: 0,
          queueLength: 3,
          delta: -1,
        ),
        2,
      );
    });

    test('list loop wraps next from last track to first track', () {
      expect(
        resolveRelativePlaybackIndex(
          orderMode: PlaybackOrderMode.listLoop,
          currentIndex: 2,
          queueLength: 3,
          delta: 1,
        ),
        0,
      );
    });

    test('single loop manual navigation still moves within queue bounds', () {
      expect(
        resolveRelativePlaybackIndex(
          orderMode: PlaybackOrderMode.singleLoop,
          currentIndex: 1,
          queueLength: 3,
          delta: 1,
        ),
        2,
      );
    });
  });

  group('PlaybackCompletionGate', () {
    test(
      'emits completion command only once until playback leaves end state',
      () {
        final gate = PlaybackCompletionGate();

        expect(
          gate.take(
            reachedEnd: true,
            command: PlaybackCompletionCommand.playNext,
          ),
          PlaybackCompletionCommand.playNext,
        );
        expect(
          gate.take(
            reachedEnd: true,
            command: PlaybackCompletionCommand.playNext,
          ),
          isNull,
        );
        expect(
          gate.take(
            reachedEnd: false,
            command: PlaybackCompletionCommand.playNext,
          ),
          isNull,
        );
        expect(
          gate.take(
            reachedEnd: true,
            command: PlaybackCompletionCommand.playNext,
          ),
          PlaybackCompletionCommand.playNext,
        );
      },
    );
  });
}
