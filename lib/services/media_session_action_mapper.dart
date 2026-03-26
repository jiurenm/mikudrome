enum PlaybackCommand { play, pause, noop }

PlaybackCommand resolvePlaybackCommand({
  required bool isPlaying,
  required String action,
}) {
  if (action == 'play') {
    return isPlaying ? PlaybackCommand.noop : PlaybackCommand.play;
  }
  if (action == 'pause') {
    return isPlaying ? PlaybackCommand.pause : PlaybackCommand.noop;
  }
  return PlaybackCommand.noop;
}

double computeSeekFraction({
  required double seekMs,
  required int durationMs,
}) {
  if (durationMs <= 0) {
    return 0;
  }
  return (seekMs / durationMs).clamp(0.0, 1.0);
}
