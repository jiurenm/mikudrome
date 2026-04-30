import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/screens/library_home_screen.dart';
import 'package:mikudrome/services/mobile_audio_playback.dart';
import 'package:mikudrome/services/mobile_audio_playback_audio_service.dart'
    as audio_service;
import 'package:mikudrome/services/mobile_audio_playback_stub.dart' as stub;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('audio service factory creates just_audio-backed service', () async {
    final service = audio_service.createMobileAudioPlaybackService();

    expect(service, isA<audio_service.JustAudioMobileAudioPlaybackService>());

    await service.dispose();
  });

  test('audio handler publishes media queue and current media item', () async {
    final player = FakeJustAudioPlayer();
    final handler = audio_service.MikudromeAudioHandler(player: player);

    await handler.setMikudromeQueue(
      tracks: [_track(1), _track(2)],
      audioUrls: const ['http://server/audio/1', 'http://server/audio/2'],
      initialIndex: 1,
    );

    expect(handler.queue.value.map((item) => item.id), [
      'http://server/audio/1',
      'http://server/audio/2',
    ]);
    expect(handler.queue.value.map((item) => item.title), [
      'Track 1',
      'Track 2',
    ]);
    expect(handler.mediaItem.value?.id, 'http://server/audio/2');
    expect(handler.mediaItem.value?.title, 'Track 2');
    expect(handler.mediaItem.value?.duration, const Duration(seconds: 120));

    await handler.dispose();
  });

  test('just_audio service queues tracks and publishes player state', () async {
    final player = FakeJustAudioPlayer();
    final service = audio_service.JustAudioMobileAudioPlaybackService(
      player: player,
    );
    final states = <MobileAudioPlaybackState>[];
    final sub = service.states.listen(states.add);

    await service.playQueue(
      queue: [_track(1), _track(2)],
      index: 1,
      audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
    );

    expect(player.sources.map((source) => source.uri.toString()), [
      'http://server/audio/1',
      'http://server/audio/2',
    ]);
    expect(player.initialIndex, 1);
    expect(player.playCalls, 1);
    expect(service.currentState.track?.id, 2);
    expect(service.currentState.index, 1);
    expect(service.currentState.isPlaying, isTrue);
    expect(service.currentState.position, Duration.zero);
    expect(service.currentState.duration, const Duration(seconds: 120));
    expect(service.currentState.isCompleted, isFalse);
    expect(states.map((state) => state.isPlaying), contains(true));

    await sub.cancel();
    await service.dispose();
  });

  test(
    'just_audio service follows current index and playback streams',
    () async {
      final player = FakeJustAudioPlayer();
      final service = audio_service.JustAudioMobileAudioPlaybackService(
        player: player,
      );

      await service.playQueue(
        queue: [_track(1), _track(2), _track(3)],
        index: 0,
        audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
      );

      player.setCurrentIndex(2);
      player.setPlaying(false);

      expect(service.currentState.index, 2);
      expect(service.currentState.track?.id, 3);
      expect(service.currentState.isPlaying, isFalse);

      await service.dispose();
    },
  );

  test('just_audio service publishes timeline and completion state', () async {
    final player = FakeJustAudioPlayer();
    final service = audio_service.JustAudioMobileAudioPlaybackService(
      player: player,
    );

    await service.playQueue(
      queue: [_track(1)],
      index: 0,
      audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
    );

    player.setDuration(const Duration(seconds: 90));
    player.setPosition(const Duration(seconds: 12));
    player.setProcessingState(ProcessingState.completed);

    expect(service.currentState.duration, const Duration(seconds: 90));
    expect(service.currentState.position, const Duration(seconds: 12));
    expect(service.currentState.isCompleted, isTrue);
    expect(service.currentState.isPlaying, isFalse);

    await service.dispose();
  });

  test('just_audio service delegates playback commands', () async {
    final player = FakeJustAudioPlayer();
    final MobileAudioPlaybackService service =
        audio_service.JustAudioMobileAudioPlaybackService(player: player);

    await service.playQueue(
      queue: [_track(1), _track(2)],
      index: 0,
      audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
    );
    await service.pause();
    await service.play();
    await service.seek(const Duration(seconds: 12));
    await service.next();
    await service.previous();
    await service.stop();
    await service.dispose();

    expect(player.pauseCalls, 1);
    expect(player.playCalls, 2);
    expect(player.seekPositions, [const Duration(seconds: 12)]);
    expect(player.nextCalls, 1);
    expect(player.previousCalls, 1);
    expect(player.stopCalls, 1);
    expect(player.disposeCalls, 1);
    expect(service.currentState.queue, isEmpty);
  });

  test('setAudioSources failure leaves service stopped', () async {
    final player = FakeJustAudioPlayer()
      ..setAudioSourcesError = StateError('load failed');
    final service = audio_service.JustAudioMobileAudioPlaybackService(
      player: player,
    );

    await expectLater(
      service.playQueue(
        queue: [_track(1), _track(2)],
        index: 1,
        audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
      ),
      throwsStateError,
    );
    player.setCurrentIndex(1);

    expect(player.playCalls, 0);
    expect(service.currentState.queue, isEmpty);
    expect(service.currentState.track, isNull);
    expect(service.currentState.isPlaying, isFalse);

    await service.dispose();
  });

  test('play failure is handled and leaves selected track paused', () async {
    final player = FakeJustAudioPlayer()..playError = StateError('play failed');
    final service = audio_service.JustAudioMobileAudioPlaybackService(
      player: player,
    );
    final unhandledErrors = <Object>[];

    await runZonedGuarded(() async {
      await service.playQueue(
        queue: [_track(1), _track(2)],
        index: 1,
        audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
      );
      await pumpEventQueue();
    }, (error, stack) => unhandledErrors.add(error));

    expect(unhandledErrors, isEmpty);
    expect(player.playCalls, 1);
    expect(service.currentState.track?.id, 2);
    expect(service.currentState.index, 1);
    expect(service.currentState.isPlaying, isFalse);

    await service.dispose();
  });

  test('android manifest and network security allow media playback', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final networkSecurityConfig = File(
      'android/app/src/main/res/xml/network_security_config.xml',
    ).readAsStringSync();
    final mainActivity = File(
      'android/app/src/main/kotlin/com/miku39/mikudrome/MainActivity.kt',
    ).readAsStringSync();

    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK'),
    );
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('android.permission.WAKE_LOCK'));
    expect(manifest, contains('android.permission.FOREGROUND_SERVICE'));
    expect(manifest, contains('android:usesCleartextTraffic="true"'));
    expect(
      manifest,
      contains('android:networkSecurityConfig="@xml/network_security_config"'),
    );
    expect(networkSecurityConfig, contains('cleartextTrafficPermitted="true"'));
    expect(mainActivity, contains('AudioServiceActivity'));
  });

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
    await service.play();

    expect(
      states.map((s) => s.isPlaying),
      containsAllInOrder([true, false, true]),
    );
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

  test('mobile audio routing stops service when entering video mode', () async {
    final service = RecordingMobileAudioPlaybackService();
    var playQueueCalls = 0;

    await routeMobileAudioPlaybackForMode(
      isMobile: true,
      playbackMode: PlaybackMode.video,
      service: service,
      playAudioQueue: () async {
        playQueueCalls += 1;
      },
    );

    expect(service.stopCalls, 1);
    expect(playQueueCalls, 0);
  });
}

Track _track(int id) => Track(
  id: id,
  title: 'Track $id',
  audioPath: '/audio/$id.flac',
  videoPath: '',
  albumId: id,
  durationSeconds: 120,
);

class FakeJustAudioPlayer implements audio_service.MobileAudioPlayerAdapter {
  final _playing = StreamController<bool>.broadcast(sync: true);
  final _currentIndex = StreamController<int?>.broadcast(sync: true);
  final _processingState = StreamController<ProcessingState>.broadcast(
    sync: true,
  );
  final _position = StreamController<Duration>.broadcast(sync: true);
  final _duration = StreamController<Duration?>.broadcast(sync: true);

  List<UriAudioSource> sources = [];
  int? initialIndex;
  Duration? initialPosition;
  @override
  bool playing = false;
  @override
  int? currentIndex;
  @override
  Duration position = Duration.zero;
  @override
  Duration? duration;
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  int nextCalls = 0;
  int previousCalls = 0;
  int disposeCalls = 0;
  Object? setAudioSourcesError;
  Object? playError;
  final seekPositions = <Duration>[];

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Stream<int?> get currentIndexStream => _currentIndex.stream;

  @override
  Stream<ProcessingState> get processingStateStream => _processingState.stream;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<Duration?> get durationStream => _duration.stream;

  @override
  Future<void> setAudioSources(
    List<UriAudioSource> sources, {
    required int initialIndex,
    required Duration initialPosition,
  }) async {
    final error = setAudioSourcesError;
    if (error != null) {
      throw error;
    }
    this.sources = sources;
    this.initialIndex = initialIndex;
    this.initialPosition = initialPosition;
    setCurrentIndex(initialIndex);
  }

  @override
  Future<void> play() async {
    playCalls += 1;
    final error = playError;
    if (error != null) {
      throw error;
    }
    setPlaying(true);
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
    setPlaying(false);
  }

  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
  }

  @override
  Future<void> seekToNext() async {
    nextCalls += 1;
    final next = ((currentIndex ?? 0) + 1).clamp(0, sources.length - 1);
    setCurrentIndex(next);
  }

  @override
  Future<void> seekToPrevious() async {
    previousCalls += 1;
    final previous = ((currentIndex ?? 0) - 1).clamp(0, sources.length - 1);
    setCurrentIndex(previous);
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    setPlaying(false);
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    await _playing.close();
    await _currentIndex.close();
    await _processingState.close();
    await _position.close();
    await _duration.close();
  }

  void setPlaying(bool value) {
    playing = value;
    _playing.add(value);
  }

  void setCurrentIndex(int? value) {
    currentIndex = value;
    _currentIndex.add(value);
  }

  void setPosition(Duration value) {
    position = value;
    _position.add(value);
  }

  void setDuration(Duration? value) {
    duration = value;
    _duration.add(value);
  }

  void setProcessingState(ProcessingState value) {
    _processingState.add(value);
  }
}

class RecordingMobileAudioPlaybackService
    extends NoopMobileAudioPlaybackService {
  int stopCalls = 0;

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }
}
