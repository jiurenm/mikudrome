import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/screens/player_screen.dart';

void main() {
  test('video controller does not allow background playback', () {
    final controller = createMikudromeVideoController(
      Uri.parse('http://127.0.0.1:8080/api/stream/7/video'),
    );
    addTearDown(controller.dispose);

    expect(
      controller.videoPlayerOptions?.allowBackgroundPlayback ?? false,
      isFalse,
    );
  });
}
