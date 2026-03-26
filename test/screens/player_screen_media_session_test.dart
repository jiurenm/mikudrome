import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/services/media_session_handler_binding.dart';
import 'package:mikudrome/services/web_media_session_contract.dart';

/// Task 3 PlayerScreen media-session behavior contract tests.
///
/// PlayerScreen wires callbacks through MediaSessionHandlerBinding. These tests
/// validate the behavior PlayerScreen depends on: active handlers execute, while
/// stale handlers are suppressed after rebind/dispose invalidation.
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
  group('PlayerScreen media session binding contract', () {
    test('current handlers invoke expected callbacks', () async {
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
      await service.seekToHandler!(3200);

      expect(playCount, 1);
      expect(pauseCount, 1);
      expect(previousCount, 1);
      expect(nextCount, 1);
      expect(seekMs, 3200);
    });

    test('stale handlers are suppressed after rebind', () async {
      final service = _FakeWebMediaSessionService();
      final binding = MediaSessionHandlerBinding();
      var staleNextCount = 0;
      var currentNextCount = 0;

      binding.rebind(
        service: service,
        onPlay: () async {},
        onPause: () async {},
        onNext: () async => staleNextCount++,
      );
      final staleNext = service.nextHandler!;

      binding.rebind(
        service: service,
        onPlay: () async {},
        onPause: () async {},
        onNext: () async => currentNextCount++,
      );
      final currentNext = service.nextHandler!;

      await staleNext();
      await currentNext();

      expect(staleNextCount, 0);
      expect(currentNextCount, 1);
    });

    test('stale handlers are suppressed after invalidate (dispose path)', () async {
      final service = _FakeWebMediaSessionService();
      final binding = MediaSessionHandlerBinding();
      var previousCount = 0;

      binding.rebind(
        service: service,
        onPlay: () async {},
        onPause: () async {},
        onPrevious: () async => previousCount++,
      );
      final stalePrevious = service.previousHandler!;

      binding.invalidate();
      await stalePrevious();

      expect(previousCount, 0);
    });
  });
}
