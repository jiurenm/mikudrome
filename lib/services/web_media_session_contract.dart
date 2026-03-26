typedef WebMediaSessionVoidHandler = Future<void> Function();
typedef WebMediaSessionSeekHandler = Future<void> Function(double seekMs);

/// Platform-safe boundary for browser Media Session integration.
///
/// Implementations must be no-op safe on non-web runtimes.
abstract interface class WebMediaSessionService {
  /// Sets media metadata displayed by system/browser controls.
  ///
  /// [artworkUrl] should be a resolvable image URL when provided.
  void setMetadata({
    required String title,
    required String artist,
    String? album,
    String? artworkUrl,
  });

  /// Updates playback state shown to the platform.
  void setPlaybackState({required bool isPlaying});

  /// Updates timing state in milliseconds.
  ///
  /// [positionMs] and [durationMs] are in milliseconds.
  /// [playbackRate] is a multiplier (for example, `1.0` for normal speed).
  void setPositionState({
    required int positionMs,
    required int durationMs,
    required double playbackRate,
  });

  /// Registers action handlers for supported controls.
  ///
  /// Capability-gated actions are nullable; pass `null` when unavailable.
  void setActionHandlers({
    required WebMediaSessionVoidHandler onPlay,
    required WebMediaSessionVoidHandler onPause,
    WebMediaSessionVoidHandler? onPrevious,
    WebMediaSessionVoidHandler? onNext,
    WebMediaSessionSeekHandler? onSeekTo,
  });

  /// Clears media session state and handlers when possible.
  void clear();
}
