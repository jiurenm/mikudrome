import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/services/media_session_action_mapper.dart';

void main() {
  test('play command resolves to no-op when already playing', () {
    expect(resolvePlaybackCommand(isPlaying: true, action: 'play'),
        PlaybackCommand.noop);
  });

  test('pause command resolves to no-op when already paused', () {
    expect(resolvePlaybackCommand(isPlaying: false, action: 'pause'),
        PlaybackCommand.noop);
  });

  test('seek fraction clamps to [0,1]', () {
    expect(computeSeekFraction(seekMs: 5000, durationMs: 1000), 1.0);
  });
}
