import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/services/web_media_session.dart';

void main() {
  test('service calls are safe on VM/non-web runtime', () {
    final service = createWebMediaSessionService();

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
