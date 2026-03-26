import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/services/media_session_action_mapper.dart';

void main() {
  test('play command resolves to no-op when already playing', () {
    expect(
      resolvePlaybackCommand(isPlaying: true, action: PlaybackAction.play),
      PlaybackCommand.noop,
    );
  });

  test('play command resolves to play when paused', () {
    expect(
      resolvePlaybackCommand(isPlaying: false, action: PlaybackAction.play),
      PlaybackCommand.play,
    );
  });

  test('pause command resolves to no-op when already paused', () {
    expect(
      resolvePlaybackCommand(isPlaying: false, action: PlaybackAction.pause),
      PlaybackCommand.noop,
    );
  });

  test('pause command resolves to pause when playing', () {
    expect(
      resolvePlaybackCommand(isPlaying: true, action: PlaybackAction.pause),
      PlaybackCommand.pause,
    );
  });

  test('unknown action resolves to noop', () {
    expect(
      resolvePlaybackCommand(isPlaying: true, action: PlaybackAction.unknown),
      PlaybackCommand.noop,
    );
  });

  test('seek fraction clamps to [0,1]', () {
    expect(computeSeekFraction(seekMs: 5000, durationMs: 1000), 1.0);
  });

  test('seek fraction returns 0 when duration is 0', () {
    expect(computeSeekFraction(seekMs: 500, durationMs: 0), 0.0);
  });

  test('seek fraction returns 0 when duration is negative', () {
    expect(computeSeekFraction(seekMs: 500, durationMs: -1), 0.0);
  });

  test('negative seek clamps to 0', () {
    expect(computeSeekFraction(seekMs: -100, durationMs: 1000), 0.0);
  });

  test('non-finite seek (NaN) returns 0', () {
    expect(computeSeekFraction(seekMs: double.nan, durationMs: 1000), 0.0);
  });

  test('non-finite seek (infinity) returns 0', () {
    expect(
      computeSeekFraction(seekMs: double.infinity, durationMs: 1000),
      0.0,
    );
  });
}
