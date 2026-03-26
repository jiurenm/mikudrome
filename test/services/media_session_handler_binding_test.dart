import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/services/media_session_handler_binding.dart';
import 'package:mikudrome/services/web_media_session_contract.dart';

class _FakeWebMediaSessionService implements WebMediaSessionService {
  WebMediaSessionVoidHandler? playHandler;
  WebMediaSessionVoidHandler? pauseHandler;
  WebMediaSessionVoidHandler? previousHandler;
  WebMediaSessionVoidHandler? nextHandler;
  WebMediaSessionSeekHandler? seekToHandler;

  @override
  void clear() {}

  @override
  void setActionHandlers({
    required WebMediaSessionVoidHandler onPlay,
    required WebMediaSessionVoidHandler onPause,
    WebMediaSessionVoidHandler? onPrevious,
    WebMediaSessionVoidHandler? onNext,
    WebMediaSessionSeekHandler? onSeekTo,
  }) {
    playHandler = onPlay;
    pauseHandler = onPause;
    previousHandler = onPrevious;
    nextHandler = onNext;
    seekToHandler = onSeekTo;
  }

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

void main() {
  group('MediaSessionHandlerBinding utility', () {
    test('rebind keeps optional handlers null when callbacks are absent', () {
      final service = _FakeWebMediaSessionService();
      final binding = MediaSessionHandlerBinding();

      binding.rebind(
        service: service,
        onPlay: () async {},
        onPause: () async {},
      );

      expect(service.playHandler, isNotNull);
      expect(service.pauseHandler, isNotNull);
      expect(service.previousHandler, isNull);
      expect(service.nextHandler, isNull);
      expect(service.seekToHandler, isNull);
    });

    test('rebind replaces exposed handler instances', () {
      final service = _FakeWebMediaSessionService();
      final binding = MediaSessionHandlerBinding();

      binding.rebind(
        service: service,
        onPlay: () async {},
        onPause: () async {},
      );
      final firstPlayHandler = service.playHandler;

      binding.rebind(
        service: service,
        onPlay: () async {},
        onPause: () async {},
      );

      expect(firstPlayHandler, isNot(same(service.playHandler)));
    });
  });
}
