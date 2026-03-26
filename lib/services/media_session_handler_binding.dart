import 'web_media_session_contract.dart';

final class MediaSessionHandlerBinding {
  int _generation = 0;

  void rebind({
    required WebMediaSessionService service,
    required WebMediaSessionVoidHandler onPlay,
    required WebMediaSessionVoidHandler onPause,
    WebMediaSessionVoidHandler? onPrevious,
    WebMediaSessionVoidHandler? onNext,
    WebMediaSessionSeekHandler? onSeekTo,
  }) {
    final generation = ++_generation;
    service.setActionHandlers(
      onPlay: _guardVoid(generation, onPlay),
      onPause: _guardVoid(generation, onPause),
      onPrevious: onPrevious == null ? null : _guardVoid(generation, onPrevious),
      onNext: onNext == null ? null : _guardVoid(generation, onNext),
      onSeekTo: onSeekTo == null ? null : _guardSeek(generation, onSeekTo),
    );
  }

  void invalidate() {
    _generation++;
  }

  WebMediaSessionVoidHandler _guardVoid(
    int generation,
    WebMediaSessionVoidHandler handler,
  ) {
    return () async {
      if (!_isCurrent(generation)) return;
      await handler();
    };
  }

  WebMediaSessionSeekHandler _guardSeek(
    int generation,
    WebMediaSessionSeekHandler handler,
  ) {
    return (seekMs) async {
      if (!_isCurrent(generation)) return;
      await handler(seekMs);
    };
  }

  bool _isCurrent(int generation) => generation == _generation;
}
