import '../models/playback_modes.dart';
import '../models/track.dart';

export '../models/playback_modes.dart' show PlaybackStartIntent;

PlaybackMode resolvePlaybackModeForIntent({
  required Track track,
  required bool isMobileSurface,
  required PlaybackStartIntent intent,
  required bool preferVideoOnExpand,
  required bool playerIsOpen,
}) {
  if (!isMobileSurface) {
    return track.hasVideo ? PlaybackMode.video : PlaybackMode.audio;
  }

  if (intent == PlaybackStartIntent.video) {
    return track.hasVideo ? PlaybackMode.video : PlaybackMode.audio;
  }

  if (intent == PlaybackStartIntent.preserve &&
      preferVideoOnExpand &&
      playerIsOpen &&
      track.hasVideo) {
    return PlaybackMode.video;
  }

  return PlaybackMode.audio;
}

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

int? resolveRelativePlaybackIndex({
  required PlaybackOrderMode orderMode,
  required int currentIndex,
  required int queueLength,
  required int delta,
}) {
  if (queueLength <= 0 || delta == 0) {
    return null;
  }

  final candidate = currentIndex + delta;
  if (candidate >= 0 && candidate < queueLength) {
    return candidate;
  }

  if (orderMode == PlaybackOrderMode.listLoop && queueLength > 1) {
    return delta > 0 ? 0 : queueLength - 1;
  }

  return null;
}
