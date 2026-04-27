import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/services/mobile_audio_playback.dart';
import 'package:mikudrome/services/mobile_audio_playback_stub.dart' as stub;

void main() {
  test('fake service publishes play and pause state', () async {
    final service = FakeMobileAudioPlaybackService();
    final states = <MobileAudioPlaybackState>[];
    final sub = service.states.listen(states.add);

    await service.playQueue(
      queue: [_track(1)],
      index: 0,
      audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
    );
    await service.pause();

    expect(states.map((s) => s.isPlaying), containsAllInOrder([true, false]));
    expect(service.currentState.track?.id, 1);

    await sub.cancel();
    await service.dispose();
  });

  test('fake service selects next track', () async {
    final service = FakeMobileAudioPlaybackService();

    await service.playQueue(
      queue: [_track(1), _track(2)],
      index: 0,
      audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
    );
    await service.next();

    expect(service.currentState.track?.id, 2);
    expect(service.currentState.index, 1);

    await service.dispose();
  });

  test('fake service keeps empty queue stopped', () async {
    final service = FakeMobileAudioPlaybackService();
    final states = <MobileAudioPlaybackState>[];
    final sub = service.states.listen(states.add);

    await service.playQueue(
      queue: const [],
      index: 4,
      audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
    );

    expect(service.currentState.queue, isEmpty);
    expect(service.currentState.track, isNull);
    expect(service.currentState.index, 0);
    expect(service.currentState.isPlaying, isFalse);
    expect(states.single.isPlaying, isFalse);

    await sub.cancel();
    await service.dispose();
  });

  test('fake service clamps selected queue index', () async {
    final service = FakeMobileAudioPlaybackService();
    final queue = [_track(1), _track(2), _track(3)];

    await service.playQueue(
      queue: queue,
      index: -2,
      audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
    );

    expect(service.currentState.index, 0);
    expect(service.currentState.track?.id, 1);

    await service.playQueue(
      queue: queue,
      index: 99,
      audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
    );

    expect(service.currentState.index, 2);
    expect(service.currentState.track?.id, 3);

    await service.dispose();
  });

  test('fake service previous and next stay within queue bounds', () async {
    final service = FakeMobileAudioPlaybackService();

    await service.playQueue(
      queue: [_track(1), _track(2)],
      index: 0,
      audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
    );
    await service.previous();

    expect(service.currentState.index, 0);
    expect(service.currentState.track?.id, 1);

    await service.next();
    await service.next();

    expect(service.currentState.index, 1);
    expect(service.currentState.track?.id, 2);

    await service.dispose();
  });

  test('fake service ignores playback commands after dispose', () async {
    final service = FakeMobileAudioPlaybackService();

    await service.playQueue(
      queue: [_track(1)],
      index: 0,
      audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
    );
    final stateBeforeDispose = service.currentState;

    await service.dispose();
    await service.pause();
    await service.playQueue(
      queue: [_track(2)],
      index: 0,
      audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
    );

    expect(service.currentState, same(stateBeforeDispose));
  });

  test('unsupported-platform stub service does not pretend to play', () async {
    final service = stub.createMobileAudioPlaybackService();

    await service.playQueue(
      queue: [_track(1)],
      index: 0,
      audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
    );

    expect(service.currentState.queue, isEmpty);
    expect(service.currentState.track, isNull);
    expect(service.currentState.isPlaying, isFalse);

    await service.dispose();
  });
}

Track _track(int id) => Track(
  id: id,
  title: 'Track $id',
  audioPath: '/audio/$id.flac',
  videoPath: '',
  albumId: id,
);
