import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/services/web_media_session.dart';

void main() {
  test('service calls are safe on VM/non-web runtime', () {
    final service = createWebMediaSessionService();

    expect(
      () => service.setMetadata(
        title: 'World is Mine',
        artist: 'ryo',
        album: 'supercell',
        artworkUrl: 'https://example.com/cover.jpg',
      ),
      returnsNormally,
    );

    Future<void> onPlay() async {}

    Future<void> onPause() async {}

    Future<void> onPrevious() async {}

    Future<void> onNext() async {}

    Future<void> onSeekTo(double seekMs) async {}

    expect(
      () => service.setActionHandlers(
        onPlay: onPlay,
        onPause: onPause,
        onPrevious: onPrevious,
        onNext: onNext,
        onSeekTo: onSeekTo,
      ),
      returnsNormally,
    );

    expect(
      () => service.setActionHandlers(
        onPlay: onPlay,
        onPause: onPause,
        onPrevious: null,
        onNext: null,
        onSeekTo: null,
      ),
      returnsNormally,
    );

    expect(() => service.setPlaybackState(isPlaying: true), returnsNormally);
    expect(
      () => service.setPositionState(
        positionMs: 100,
        durationMs: 1000,
        playbackRate: 1.0,
      ),
      returnsNormally,
    );
    expect(() => service.clear(), returnsNormally);
  });
}
