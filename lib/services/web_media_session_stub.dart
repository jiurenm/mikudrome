import 'web_media_session_contract.dart';

WebMediaSessionService createWebMediaSessionService() =>
    _NoopWebMediaSessionService();

final class _NoopWebMediaSessionService implements WebMediaSessionService {
  @override
  void clear() {}

  @override
  void setActionHandlers({
    required WebMediaSessionVoidHandler onPlay,
    required WebMediaSessionVoidHandler onPause,
    required WebMediaSessionVoidHandler onPrevious,
    required WebMediaSessionVoidHandler onNext,
    required WebMediaSessionSeekHandler onSeekTo,
    required bool canPrevious,
    required bool canNext,
    required bool canSeek,
  }) {}

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
