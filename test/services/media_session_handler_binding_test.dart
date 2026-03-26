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
  group('MediaSessionHandlerBinding', () {
    test('current bound handlers invoke expected callbacks', () async {
      final service = _FakeWebMediaSessionService();
      final binding = MediaSessionHandlerBinding();
      var playCount = 0;
      var pauseCount = 0;
      var previousCount = 0;
      var nextCount = 0;
      double? seekMs;

      binding.rebind(
        service: service,
        onPlay: () async => playCount++,
        onPause: () async => pauseCount++,
        onPrevious: () async => previousCount++,
        onNext: () async => nextCount++,
        onSeekTo: (value) async => seekMs = value,
      );

      await service.playHandler!();
      await service.pauseHandler!();
      await service.previousHandler!();
      await service.nextHandler!();
      await service.seekToHandler!(4200);

      expect(playCount, 1);
      expect(pauseCount, 1);
      expect(previousCount, 1);
      expect(nextCount, 1);
      expect(seekMs, 4200);
    });

    test('stale handlers are ignored after rebind', () async {
      final service = _FakeWebMediaSessionService();
      final binding = MediaSessionHandlerBinding();
      var stalePlayCount = 0;
      var currentPlayCount = 0;

      binding.rebind(
        service: service,
        onPlay: () async => stalePlayCount++,
        onPause: () async {},
      );
      final stalePlay = service.playHandler!;

      binding.rebind(
        service: service,
        onPlay: () async => currentPlayCount++,
        onPause: () async {},
      );
      final currentPlay = service.playHandler!;

      await stalePlay();
      await currentPlay();

      expect(stalePlayCount, 0);
      expect(currentPlayCount, 1);
    });

    test('stale handlers are ignored after invalidate', () async {
      final service = _FakeWebMediaSessionService();
      final binding = MediaSessionHandlerBinding();
      var playCount = 0;

      binding.rebind(
        service: service,
        onPlay: () async => playCount++,
        onPause: () async {},
      );
      final capturedPlay = service.playHandler!;

      binding.invalidate();
      await capturedPlay();

      expect(playCount, 0);
    });
  });
}
