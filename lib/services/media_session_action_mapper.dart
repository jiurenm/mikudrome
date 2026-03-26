enum PlaybackAction { play, pause, unknown }

enum PlaybackCommand { play, pause, noop }

PlaybackCommand resolvePlaybackCommand({
  required bool isPlaying,
  required PlaybackAction action,
}) {
  switch (action) {
    case PlaybackAction.play:
      return isPlaying ? PlaybackCommand.noop : PlaybackCommand.play;
    case PlaybackAction.pause:
      return isPlaying ? PlaybackCommand.pause : PlaybackCommand.noop;
    case PlaybackAction.unknown:
      return PlaybackCommand.noop;
  }
}

double computeSeekFraction({
  required double seekMs,
  required int durationMs,
}) {
  if (!seekMs.isFinite || durationMs <= 0) {
    return 0;
  }
  return (seekMs / durationMs).clamp(0.0, 1.0);
}
