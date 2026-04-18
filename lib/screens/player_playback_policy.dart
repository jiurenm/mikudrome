import 'library_home_screen.dart';

enum PlaybackCompletionCommand { none, restartTrack, playNext }

final class PlaybackCompletionGate {
  bool _handledCurrentCompletion = false;

  PlaybackCompletionCommand? take({
    required bool reachedEnd,
    required PlaybackCompletionCommand command,
  }) {
    if (!reachedEnd) {
      _handledCurrentCompletion = false;
      return null;
    }
    if (_handledCurrentCompletion) {
      return null;
    }
    _handledCurrentCompletion = true;
    return command;
  }

  void reset() {
    _handledCurrentCompletion = false;
  }
}

bool didPlaybackReachEnd({
  required bool isCompleted,
  required bool isPlaying,
  required Duration position,
  required Duration duration,
}) {
  if (duration <= Duration.zero) {
    return false;
  }
  if (isCompleted) {
    return true;
  }
  return !isPlaying && position >= duration;
}

PlaybackCompletionCommand resolvePlaybackCompletionCommand({
  required PlaybackOrderMode orderMode,
  required bool hasNext,
}) {
  switch (orderMode) {
    case PlaybackOrderMode.sequential:
      return hasNext
          ? PlaybackCompletionCommand.playNext
          : PlaybackCompletionCommand.none;
    case PlaybackOrderMode.listLoop:
      return hasNext
          ? PlaybackCompletionCommand.playNext
          : PlaybackCompletionCommand.restartTrack;
    case PlaybackOrderMode.singleLoop:
      return PlaybackCompletionCommand.restartTrack;
  }
}
