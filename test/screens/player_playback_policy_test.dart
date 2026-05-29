import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/screens/library_home_screen.dart';
import 'package:mikudrome/screens/player_playback_policy.dart';

const _trackWithVideo = Track(
  id: 1,
  title: 'Track with MV',
  audioPath: '/audio/1.flac',
  videoPath: '/video/1.mp4',
);

void main() {
  group('defaultPlaybackModeForTrack', () {
    test('uses audio by default on mobile even when the track has an MV', () {
      expect(
        defaultPlaybackModeForTrack(_trackWithVideo, isMobileSurface: true),
        PlaybackMode.audio,
      );
    });

    test('keeps MV as the desktop default when the track has an MV', () {
      expect(
        defaultPlaybackModeForTrack(_trackWithVideo, isMobileSurface: false),
        PlaybackMode.video,
      );
    });
  });

  group('mobile playback intent', () {
    test('normal mobile row taps stay audio-first even when track has MV', () {
      expect(
        resolvePlaybackModeForIntent(
          track: _trackWithVideo,
          isMobileSurface: true,
          intent: PlaybackStartIntent.audio,
          preferVideoOnExpand: false,
          playerIsOpen: true,
        ),
        PlaybackMode.audio,
      );
    });

    test('mobile MV affordance starts video when the track has MV', () {
      expect(
        resolvePlaybackModeForIntent(
          track: _trackWithVideo,
          isMobileSurface: true,
          intent: PlaybackStartIntent.video,
          preferVideoOnExpand: false,
          playerIsOpen: true,
        ),
        PlaybackMode.video,
      );
    });

    test('video intent degrades to audio when the track has no MV', () {
      const audioOnly = Track(
        id: 2,
        title: 'Audio only',
        audioPath: '/audio/2.flac',
        videoPath: '',
      );

      expect(
        resolvePlaybackModeForIntent(
          track: audioOnly,
          isMobileSurface: true,
          intent: PlaybackStartIntent.video,
          preferVideoOnExpand: true,
          playerIsOpen: true,
        ),
        PlaybackMode.audio,
      );
    });

    test('expanded mixed queue returns to MV when video intent is preserved', () {
      expect(
        resolvePlaybackModeForIntent(
          track: _trackWithVideo,
          isMobileSurface: true,
          intent: PlaybackStartIntent.preserve,
          preferVideoOnExpand: true,
          playerIsOpen: true,
        ),
        PlaybackMode.video,
      );
    });

    test('collapsed mixed queue remains audio-first until reopened', () {
      expect(
        resolvePlaybackModeForIntent(
          track: _trackWithVideo,
          isMobileSurface: true,
          intent: PlaybackStartIntent.preserve,
          preferVideoOnExpand: true,
          playerIsOpen: false,
        ),
        PlaybackMode.audio,
      );
    });
  });

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
