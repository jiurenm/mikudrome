import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/services/web_media_session_web.dart';

class _FakeMediaSessionAdapter implements WebMediaSessionAdapter {
  final Map<String, Object?> handlers = <String, Object?>{};

  @override
  void clearMetadata() {}

  @override
  void clearPlaybackState() {}

  @override
  void setActionHandler(String action, Object? handler) {
    handlers[action] = handler;
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
  Future<void> noop() async {}

  group('Web media session capability registration', () {
    test('removes previous/next/seek handlers when capability is unavailable',
        () {
      final adapter = _FakeMediaSessionAdapter();
      final service = createWebMediaSessionServiceForTest(adapter: adapter);

      service.setActionHandlers(
        onPlay: noop,
        onPause: noop,
        onPrevious: null,
        onNext: null,
        onSeekTo: null,
      );

      expect(adapter.handlers['play'], isNotNull);
      expect(adapter.handlers['pause'], isNotNull);
      expect(adapter.handlers['previoustrack'], isNull);
      expect(adapter.handlers['nexttrack'], isNull);
      expect(adapter.handlers['seekto'], isNull);
    });

    test('clear removes all action handlers', () {
      final adapter = _FakeMediaSessionAdapter();
      final service = createWebMediaSessionServiceForTest(adapter: adapter);

      service.setActionHandlers(
        onPlay: noop,
        onPause: noop,
        onPrevious: noop,
        onNext: noop,
        onSeekTo: (_) async {},
      );

      service.clear();

      expect(adapter.handlers['play'], isNull);
      expect(adapter.handlers['pause'], isNull);
      expect(adapter.handlers['previoustrack'], isNull);
      expect(adapter.handlers['nexttrack'], isNull);
      expect(adapter.handlers['seekto'], isNull);
    });

    test('service is safe when adapter is unavailable', () {
      final service = createWebMediaSessionServiceForTest(adapter: null);

      expect(
        () => service.setActionHandlers(
          onPlay: noop,
          onPause: noop,
          onPrevious: null,
          onNext: null,
          onSeekTo: null,
        ),
        returnsNormally,
      );
      expect(
        () => service.setPlaybackState(isPlaying: true),
        returnsNormally,
      );
      expect(
        () => service.setPositionState(
          positionMs: 0,
          durationMs: 1000,
          playbackRate: 1,
        ),
        returnsNormally,
      );
      expect(() => service.clear(), returnsNormally);
    });
  });
}
