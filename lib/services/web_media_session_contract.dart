typedef WebMediaSessionVoidHandler = Future<void> Function();
typedef WebMediaSessionSeekHandler = Future<void> Function(double seekMs);

abstract interface class WebMediaSessionService {
  void setMetadata({
    required String title,
    required String artist,
    String? album,
    String? artworkUrl,
  });

  void setPlaybackState({required bool isPlaying});

  void setPositionState({
    required int positionMs,
    required int durationMs,
    required double playbackRate,
  });

  void setActionHandlers({
    required WebMediaSessionVoidHandler onPlay,
    required WebMediaSessionVoidHandler onPause,
    required WebMediaSessionVoidHandler onPrevious,
    required WebMediaSessionVoidHandler onNext,
    required WebMediaSessionSeekHandler onSeekTo,
    required bool canPrevious,
    required bool canNext,
    required bool canSeek,
  });

  void clear();
}
