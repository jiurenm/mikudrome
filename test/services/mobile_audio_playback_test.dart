// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart'
    show AudioProcessingState, MediaControl;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mikudrome/api/config.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/screens/library_home_screen.dart';
import 'package:mikudrome/services/mobile_audio_playback.dart';
import 'package:mikudrome/services/mobile_audio_playback_audio_service.dart'
    as audio_service;
import 'package:mikudrome/services/mobile_audio_playback_stub.dart' as stub;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getTemporaryDirectory') {
            return Directory.systemTemp.path;
          }
          return null;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  tearDown(ApiConfig.resetRuntimeConfigForTests);

  test('audio service factory creates audio-service-backed service', () async {
    final service = audio_service.createMobileAudioPlaybackService();

    expect(service, isA<audio_service.JustAudioMobileAudioPlaybackService>());
    expect(
      (service as audio_service.JustAudioMobileAudioPlaybackService)
          .usesAudioService,
      isTrue,
    );

    await service.dispose();
  });

  test('audio handler publishes media queue and current media item', () async {
    final player = FakeJustAudioPlayer();
    final handler = audio_service.MikudromeAudioHandler(player: player);
    ApiConfig.setRuntimeCookie('session=abc');

    await handler.setMikudromeQueue(
      tracks: [_track(1), _track(2)],
      audioUrls: const ['http://server/audio/1', 'http://server/audio/2'],
      initialIndex: 1,
      coverUrlForTrack: (track) => 'http://server/cover/${track.albumId}',
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
    expect(handler.mediaItem.value?.artUri, Uri.parse('http://server/cover/2'));
    expect(handler.mediaItem.value?.artHeaders, {'Cookie': 'session=abc'});

    await handler.dispose();
  });

  test('audio handler publishes playback queue index', () async {
    final player = FakeJustAudioPlayer();
    final handler = audio_service.MikudromeAudioHandler(player: player);

    await handler.setMikudromeQueue(
      tracks: [_track(1), _track(2)],
      audioUrls: const ['http://server/audio/1', 'http://server/audio/2'],
      initialIndex: 1,
    );

    expect(handler.playbackState.value.queueIndex, 1);

    player.setCurrentIndex(0);

    expect(handler.playbackState.value.queueIndex, 0);

    await handler.stop();

    expect(handler.playbackState.value.queueIndex, isNull);

    await handler.dispose();
  });

  test(
    'audio handler publishes favorite custom control for current track',
    () async {
      final player = FakeJustAudioPlayer();
      final favorites = <int>{};
      final handler = audio_service.MikudromeAudioHandler(player: player);

      await handler.setMikudromeQueue(
        tracks: [_track(1)],
        audioUrls: const ['http://server/audio/1'],
        initialIndex: 0,
        isTrackFavorited: favorites.contains,
        toggleTrackFavorite: (track) async {
          favorites.contains(track.id)
              ? favorites.remove(track.id)
              : favorites.add(track.id);
        },
      );

      final favoriteControl = _favoriteControl(handler);
      expect(favoriteControl.label, 'Add to favorites');
      expect(favoriteControl.androidIcon, 'drawable/ic_favorite_border');
      expect(favoriteControl.customAction?.name, 'toggleFavorite');
      expect(handler.playbackState.value.androidCompactActionIndices, [
        0,
        1,
        2,
      ]);

      await handler.dispose();
    },
  );

  test(
    'audio handler refreshes favorite control after custom action',
    () async {
      final player = FakeJustAudioPlayer();
      final favorites = <int>{};
      final toggledTrackIds = <int>[];
      final handler = audio_service.MikudromeAudioHandler(player: player);

      await handler.setMikudromeQueue(
        tracks: [_track(1)],
        audioUrls: const ['http://server/audio/1'],
        initialIndex: 0,
        isTrackFavorited: favorites.contains,
        toggleTrackFavorite: (track) async {
          toggledTrackIds.add(track.id);
          favorites.contains(track.id)
              ? favorites.remove(track.id)
              : favorites.add(track.id);
        },
      );

      await handler.customAction('toggleFavorite');

      expect(toggledTrackIds, [1]);
      final favoriteControl = _favoriteControl(handler);
      expect(favoriteControl.label, 'Remove from favorites');
      expect(favoriteControl.androidIcon, 'drawable/ic_favorite');

      await handler.dispose();
    },
  );

  test('audio handler updates favorite control when track changes', () async {
    final player = FakeJustAudioPlayer();
    final favorites = <int>{2};
    final handler = audio_service.MikudromeAudioHandler(player: player);

    await handler.setMikudromeQueue(
      tracks: [_track(1), _track(2)],
      audioUrls: const ['http://server/audio/1', 'http://server/audio/2'],
      initialIndex: 0,
      isTrackFavorited: favorites.contains,
      toggleTrackFavorite: (track) async {},
    );

    expect(_favoriteControl(handler).label, 'Add to favorites');

    player.setCurrentIndex(1);

    expect(handler.mediaItem.value?.title, 'Track 2');
    expect(_favoriteControl(handler).label, 'Remove from favorites');
    expect(_favoriteControl(handler).androidIcon, 'drawable/ic_favorite');

    await handler.dispose();
  });

  test(
    'audio handler favorite custom action is safe without callback or queue',
    () async {
      final player = FakeJustAudioPlayer();
      final handler = audio_service.MikudromeAudioHandler(player: player);

      await handler.customAction('toggleFavorite');

      await handler.setMikudromeQueue(
        tracks: [_track(1)],
        audioUrls: const ['http://server/audio/1'],
        initialIndex: 0,
      );
      await handler.customAction('toggleFavorite');

      expect(_favoriteControl(handler).label, 'Add to favorites');

      await handler.dispose();
    },
  );

  test('audio-service-backed service exposes handler queue state', () async {
    final player = FakeJustAudioPlayer();
    final handler = audio_service.MikudromeAudioHandler(player: player);
    final service = audio_service.JustAudioMobileAudioPlaybackService(
      handler: handler,
    );

    await service.playQueue(
      queue: [_track(1), _track(2)],
      index: 1,
      audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
      coverUrlForTrack: (track) => 'http://server/cover/${track.albumId}',
    );

    expect(handler.queue.value.length, 2);
    expect(handler.mediaItem.value?.title, 'Track 2');
    expect(handler.mediaItem.value?.artUri, Uri.parse('http://server/cover/2'));
    expect(player.playCalls, 1);
    expect(service.currentState.track?.id, 2);
    expect(service.currentState.isPlaying, isTrue);

    await service.dispose();
  });

  test('audio-service-backed service forwards favorite callbacks', () async {
    final player = FakeJustAudioPlayer();
    final handler = audio_service.MikudromeAudioHandler(player: player);
    final service = audio_service.JustAudioMobileAudioPlaybackService(
      handler: handler,
    );

    await service.playQueue(
      queue: [_track(1)],
      index: 0,
      audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
      isTrackFavorited: (trackId) => trackId == 1,
      toggleTrackFavorite: (track) async {},
    );

    final favoriteControl = _favoriteControl(handler);
    expect(favoriteControl.label, 'Remove from favorites');
    expect(favoriteControl.androidIcon, 'drawable/ic_favorite');

    await service.dispose();
  });

  test('just_audio service queues tracks and publishes player state', () async {
    final player = FakeJustAudioPlayer();
    final service = audio_service.JustAudioMobileAudioPlaybackService(
      player: player,
    );
    final states = <MobileAudioPlaybackState>[];
    final sub = service.states.listen(states.add);
    ApiConfig.setRuntimeCookie('session=abc');

    await service.playQueue(
      queue: [_track(1), _track(2)],
      index: 1,
      audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
    );

    expect(player.sources, everyElement(isA<LockCachingAudioSource>()));
    final cachingSources = player.sources.cast<LockCachingAudioSource>();
    expect(cachingSources.map((source) => source.uri.toString()), [
      'http://server/audio/1',
      'http://server/audio/2',
    ]);
    expect(
      cachingSources.map((source) => source.headers),
      everyElement({'Cookie': 'session=abc'}),
    );
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
    'queue loads are serialized and only the latest state is published',
    () async {
      final player = DelayedSetAudioSourcesFakeJustAudioPlayer();
      final service = audio_service.JustAudioMobileAudioPlaybackService(
        player: player,
      );
      final states = <MobileAudioPlaybackState>[];
      final sub = service.states.listen(states.add);

      final firstLoad = service.playQueue(
        queue: [_track(1)],
        index: 0,
        audioUrlForTrack: (_) => 'http://server/audio/first',
      );
      await player.firstSetStarted;

      final secondLoad = service.playQueue(
        queue: [_track(2)],
        index: 0,
        audioUrlForTrack: (_) => 'http://server/audio/second',
      );
      addTearDown(() async {
        player.completeFirstSet();
        await Future.wait([firstLoad, secondLoad]);
        await sub.cancel();
        await service.dispose();
      });

      await pumpEventQueue();

      expect(player.maxConcurrentSetAudioSourcesCalls, 1);

      player.completeFirstSet();
      await Future.wait([firstLoad, secondLoad]);

      expect(player.maxConcurrentSetAudioSourcesCalls, 1);
      expect(player.setAudioSourcesCalls, 2);
      expect(player.appliedSourceUrls, [
        ['http://server/audio/first'],
        ['http://server/audio/second'],
      ]);
      expect(_sourceUri(player.sources.single).path, endsWith('/second'));
      final nonEmptyStates = states
          .where((state) => state.queue.isNotEmpty)
          .toList();
      expect(nonEmptyStates, hasLength(1));
      expect(nonEmptyStates.map((state) => state.track?.id).toSet(), {2});
      expect(service.currentState.track?.id, 2);
    },
  );

  test(
    'queue loads skip superseded URL work while the handler loads',
    () async {
      final player = FakeJustAudioPlayer();
      final handlerCompleter = Completer<audio_service.MikudromeAudioHandler>();
      final loaderStarted = Completer<void>();
      final generatedTrackIds = <int>[];
      var loaderCalls = 0;
      final service = audio_service.JustAudioMobileAudioPlaybackService(
        handlerLoader: () {
          loaderCalls += 1;
          if (!loaderStarted.isCompleted) {
            loaderStarted.complete();
          }
          return handlerCompleter.future;
        },
      );

      Future<void> loadTrack(int id) {
        return service.playQueue(
          queue: [_track(id)],
          index: 0,
          audioUrlForTrack: (track) {
            generatedTrackIds.add(track.id);
            return 'http://server/audio/${track.id}';
          },
        );
      }

      final firstLoad = loadTrack(1);
      await loaderStarted.future;
      final loads = [firstLoad, loadTrack(2), loadTrack(3)];
      handlerCompleter.complete(
        audio_service.MikudromeAudioHandler(player: player),
      );
      await Future.wait(loads);

      expect(loaderCalls, 1);
      expect(generatedTrackIds, [3]);
      expect(player.setAudioSourcesCalls, 1);
      expect(service.currentState.track?.id, 3);

      await service.dispose();
    },
  );

  test(
    'same track and index still accept the latest queue URL and state',
    () async {
      final player = DelayedSetAudioSourcesFakeJustAudioPlayer();
      final service = audio_service.JustAudioMobileAudioPlaybackService(
        player: player,
      );
      final states = <MobileAudioPlaybackState>[];
      final sub = service.states.listen(states.add);

      final firstLoad = service.playQueue(
        queue: [_track(1)],
        index: 0,
        audioUrlForTrack: (_) => 'http://server/audio/first',
      );
      await player.firstSetStarted;
      final secondLoad = service.playQueue(
        queue: [_track(1)],
        index: 0,
        audioUrlForTrack: (_) => 'http://server/audio/second',
      );
      addTearDown(() async {
        player.completeFirstSet();
        await Future.wait([firstLoad, secondLoad]);
        await sub.cancel();
        await service.dispose();
      });

      player.completeFirstSet();
      await Future.wait([firstLoad, secondLoad]);

      expect(player.appliedSourceUrls, [
        ['http://server/audio/first'],
        ['http://server/audio/second'],
      ]);
      expect(_sourceUri(player.sources.single).path, endsWith('/second'));
      expect(service.currentState.track?.id, 1);
      expect(service.currentState.index, 0);
      expect(service.currentState.audioUrl, endsWith('/second'));
      final nonEmptyStates = states
          .where((state) => state.queue.isNotEmpty)
          .toList();
      expect(nonEmptyStates, hasLength(1));
      expect(
        nonEmptyStates.map((state) => state.audioUrl),
        everyElement(endsWith('/second')),
      );
    },
  );

  test(
    'just_audio service starts restored queue at requested initial position',
    () async {
      final player = FakeJustAudioPlayer();
      final service = audio_service.JustAudioMobileAudioPlaybackService(
        player: player,
      );

      await service.playQueue(
        queue: [_track(1), _track(2)],
        index: 1,
        audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
        initialPosition: const Duration(seconds: 75),
      );

      expect(player.initialIndex, 1);
      expect(player.initialPosition, const Duration(seconds: 75));
      expect(service.currentState.track?.id, 2);
      expect(service.currentState.index, 1);
      expect(service.currentState.position, const Duration(seconds: 75));

      await service.dispose();
    },
  );

  test(
    'just_audio service applies list loop mode to the player queue',
    () async {
      final player = FakeJustAudioPlayer();
      final service = audio_service.JustAudioMobileAudioPlaybackService(
        player: player,
      );

      await service.playQueue(
        queue: [_track(1), _track(2)],
        index: 0,
        audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
        orderMode: MobilePlaybackOrderMode.listLoop,
      );

      expect(player.loopMode, LoopMode.all);

      await service.dispose();
    },
  );

  test(
    'just_audio service updates loop mode without resetting queue',
    () async {
      final player = FakeJustAudioPlayer();
      final service = audio_service.JustAudioMobileAudioPlaybackService(
        player: player,
      );

      await service.playQueue(
        queue: [_track(1), _track(2)],
        index: 0,
        audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
      );

      await service.setPlaybackOrderMode(MobilePlaybackOrderMode.singleLoop);

      expect(player.loopMode, LoopMode.one);
      expect(player.sources.map((source) => _sourceUri(source).toString()), [
        'http://server/audio/1',
        'http://server/audio/2',
      ]);
      expect(player.playCalls, 1);

      await service.dispose();
    },
  );

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

  test(
    'audio handler syncs player streams to playback state and app state',
    () async {
      final player = FakeJustAudioPlayer();
      final handler = audio_service.MikudromeAudioHandler(player: player);
      final states = <MobileAudioPlaybackState>[];
      final sub = handler.mikudromeState.listen(states.add);

      await handler.setMikudromeQueue(
        tracks: [_track(1), _track(2)],
        audioUrls: const ['http://server/audio/1', 'http://server/audio/2'],
        initialIndex: 0,
      );

      player.setCurrentIndex(1);
      player.setDuration(const Duration(seconds: 90));
      player.setPosition(const Duration(seconds: 12));
      player.setProcessingState(ProcessingState.completed);

      expect(handler.mediaItem.value?.title, 'Track 2');
      expect(states.last.track?.id, 2);
      expect(states.last.duration, const Duration(seconds: 90));
      expect(states.last.position, const Duration(seconds: 12));
      expect(states.last.isCompleted, isTrue);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.completed,
      );

      await sub.cancel();
      await handler.dispose();
    },
  );

  test('audio handler maps buffering to audio service state', () async {
    final player = FakeJustAudioPlayer();
    final handler = audio_service.MikudromeAudioHandler(player: player);

    await handler.setMikudromeQueue(
      tracks: [_track(1)],
      audioUrls: const ['http://server/audio/1'],
      initialIndex: 0,
    );

    player.setProcessingState(ProcessingState.buffering);

    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.buffering,
    );
    expect(handler.playbackState.value.playing, isTrue);
    expect(handler.playbackState.value.speed, 0.0);

    await handler.dispose();
  });

  test(
    'audio handler keeps restored source and position while buffering',
    () async {
      final player = FakeJustAudioPlayer();
      final handler = audio_service.MikudromeAudioHandler(player: player);
      final states = <MobileAudioPlaybackState>[];
      final sub = handler.mikudromeState.listen(states.add);

      await handler.setMikudromeQueue(
        tracks: [_track(1), _track(2)],
        audioUrls: const [
          'http://server/api/stream/1/audio',
          'http://server/api/stream/2/audio',
        ],
        initialIndex: 1,
        initialPosition: const Duration(seconds: 75),
      );

      player.setProcessingState(ProcessingState.buffering);
      player.setProcessingState(ProcessingState.buffering);
      await pumpEventQueue();

      expect(player.setAudioSourcesCalls, 1);
      expect(player.initialIndex, 1);
      expect(player.initialPosition, const Duration(seconds: 75));
      expect(player.sources.map((source) => _sourceUri(source).toString()), [
        'http://server/api/stream/1/audio',
        'http://server/api/stream/2/audio',
      ]);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.buffering,
      );
      expect(states.last.index, 1);
      expect(states.last.position, const Duration(seconds: 75));

      await sub.cancel();
      await handler.dispose();
    },
  );

  test('audio handler retries current item after playback error', () async {
    final player = FakeJustAudioPlayer();
    final handler = audio_service.MikudromeAudioHandler(player: player);

    await handler.setMikudromeQueue(
      tracks: [_track(1)],
      audioUrls: const ['http://server/audio/1'],
      initialIndex: 0,
    );
    player.setPosition(const Duration(seconds: 42));

    player.emitError(PlayerException(1, 'connection lost', 0));
    await pumpEventQueue();

    expect(player.seekPositions, [const Duration(seconds: 42)]);
    expect(player.playCalls, 2);

    await handler.dispose();
  });

  test(
    'audio handler switches current item to low quality after error',
    () async {
      final player = FakeJustAudioPlayer();
      final handler = audio_service.MikudromeAudioHandler(player: player);
      final states = <MobileAudioPlaybackState>[];
      final sub = handler.mikudromeState.listen(states.add);

      await handler.setMikudromeQueue(
        tracks: [_track(1)],
        audioUrls: const ['http://server/api/stream/1/audio'],
        initialIndex: 0,
      );
      player.setPosition(const Duration(seconds: 42));

      player.emitError(PlayerException(1, 'connection lost', 0));
      await pumpEventQueue();

      expect(player.setAudioSourcesCalls, 2);
      expect(player.sources.single, isA<LockCachingAudioSource>());
      expect(
        _sourceUri(player.sources.single).toString(),
        contains('quality=low'),
      );
      expect(player.initialIndex, 0);
      expect(player.initialPosition, const Duration(seconds: 42));
      expect(handler.mediaItem.value?.id, contains('quality=low'));
      expect(states.last.audioUrl, contains('quality=low'));
      expect(player.playCalls, 2);

      await sub.cancel();
      await handler.dispose();
    },
  );

  test(
    'queue replacement ignores recovery errors while setting sources',
    () async {
      final player = DelayedSetAudioSourcesFakeJustAudioPlayer(
        delayedInvocation: 2,
      );
      final service = audio_service.JustAudioMobileAudioPlaybackService(
        player: player,
      );

      await service.playQueue(
        queue: [_track(1)],
        index: 0,
        audioUrlForTrack: (_) => 'http://server/audio/first',
      );

      final replacement = service.playQueue(
        queue: [_track(2)],
        index: 0,
        audioUrlForTrack: (_) => 'http://server/audio/second',
      );
      await player.delayedSetStarted;
      addTearDown(() async {
        player.completeDelayedSet();
        await replacement;
        await service.dispose();
      });

      player.emitError(PlayerException(1, 'replacement failed', 0));
      await pumpEventQueue();

      expect(player.maxConcurrentSetAudioSourcesCalls, 1);

      player.completeDelayedSet();
      await replacement;
      await pumpEventQueue();

      expect(player.maxConcurrentSetAudioSourcesCalls, 1);
      expect(player.setAudioSourcesCalls, 2);
      expect(player.appliedSourceUrls, [
        ['http://server/audio/first'],
        ['http://server/audio/second'],
      ]);
      expect(_sourceUri(player.sources.single).toString(), endsWith('/second'));
      expect(service.currentState.track?.id, 2);
      expect(service.currentState.audioUrl, endsWith('/second'));
    },
  );

  test(
    'queue replacement waits for running recovery and remains final',
    () async {
      final player = DelayedSetAudioSourcesFakeJustAudioPlayer(
        delayedInvocation: 2,
      );
      final service = audio_service.JustAudioMobileAudioPlaybackService(
        player: player,
      );

      await service.playQueue(
        queue: [_track(1)],
        index: 0,
        audioUrlForTrack: (_) => 'http://server/audio/first',
      );

      player.emitError(PlayerException(1, 'connection lost', 0));
      await player.delayedSetStarted;
      final replacement = service.playQueue(
        queue: [_track(2)],
        index: 0,
        audioUrlForTrack: (_) => 'http://server/audio/second',
      );
      addTearDown(() async {
        player.completeDelayedSet();
        await replacement;
        await service.dispose();
      });

      await pumpEventQueue();
      final maxConcurrencyBeforeRelease =
          player.maxConcurrentSetAudioSourcesCalls;

      player.completeDelayedSet();
      await replacement;
      await pumpEventQueue();

      expect(player.setAudioSourcesCalls, 3);
      expect(_sourceUri(player.sources.single).toString(), endsWith('/second'));
      expect(player.appliedSourceUrls[1].single, contains('quality=low'));
      expect(player.appliedSourceUrls.last, ['http://server/audio/second']);
      expect(maxConcurrencyBeforeRelease, 1);
      expect(player.maxConcurrentSetAudioSourcesCalls, 1);
      expect(service.currentState.track?.id, 2);
      expect(service.currentState.audioUrl, endsWith('/second'));
    },
  );

  test(
    'queue replacement waits for recovery seek and keeps initial position',
    () async {
      final player = DelayedRecoverySeekFakeJustAudioPlayer();
      final service = audio_service.JustAudioMobileAudioPlaybackService(
        player: player,
      );

      await service.playQueue(
        queue: [_track(1)],
        index: 0,
        audioUrlForTrack: (_) => 'http://server/audio/first',
      );
      player.setPosition(const Duration(seconds: 42));

      player.emitError(PlayerException(1, 'connection lost', 0));
      await player.recoverySeekStarted;
      final replacement = service.playQueue(
        queue: [_track(2)],
        index: 0,
        audioUrlForTrack: (_) => 'http://server/audio/second',
        initialPosition: const Duration(seconds: 37),
      );
      addTearDown(() async {
        player.completeRecoverySeek();
        await replacement;
        await service.dispose();
      });

      await pumpEventQueue();
      final sourceCallsBeforeSeekCompleted = player.setAudioSourcesCalls;

      player.completeRecoverySeek();
      await replacement;
      await pumpEventQueue();

      expect(sourceCallsBeforeSeekCompleted, 2);
      expect(player.setAudioSourcesCalls, 3);
      expect(_sourceUri(player.sources.single).toString(), endsWith('/second'));
      expect(player.initialPosition, const Duration(seconds: 37));
      expect(service.currentState.track?.id, 2);
      expect(service.currentState.position, const Duration(seconds: 37));
    },
  );

  test('late recovery play error does not pause replacement queue', () async {
    final player = DelayedRecoveryPlayErrorFakeJustAudioPlayer();
    final service = audio_service.JustAudioMobileAudioPlaybackService(
      player: player,
    );
    final states = <MobileAudioPlaybackState>[];
    final sub = service.states.listen(states.add);

    await service.playQueue(
      queue: [_track(1)],
      index: 0,
      audioUrlForTrack: (_) => 'http://server/audio/first',
    );
    player.setPosition(const Duration(seconds: 24));

    player.emitError(PlayerException(1, 'connection lost', 0));
    await player.recoveryPlayStarted;
    await service.playQueue(
      queue: [_track(2)],
      index: 0,
      audioUrlForTrack: (_) => 'http://server/audio/second',
      initialPosition: const Duration(seconds: 31),
    );
    addTearDown(() async {
      player.failRecoveryPlay();
      await pumpEventQueue();
      await sub.cancel();
      await service.dispose();
    });
    states.clear();

    player.failRecoveryPlay();
    await pumpEventQueue();

    expect(states, isEmpty);
    expect(service.currentState.track?.id, 2);
    expect(service.currentState.position, const Duration(seconds: 31));
    expect(service.currentState.isPlaying, isTrue);
  });

  test(
    'audio handler throttles position-only app state updates within same second',
    () async {
      final player = FakeJustAudioPlayer();
      final handler = audio_service.MikudromeAudioHandler(player: player);
      final states = <MobileAudioPlaybackState>[];
      final sub = handler.mikudromeState.listen(states.add);

      await handler.setMikudromeQueue(
        tracks: [_track(1)],
        audioUrls: const ['http://server/audio/1'],
        initialIndex: 0,
      );
      final stateCountAfterStart = states.length;

      player.setPosition(const Duration(milliseconds: 200));
      player.setPosition(const Duration(milliseconds: 800));

      expect(states.length, stateCountAfterStart);

      player.setPosition(const Duration(seconds: 1));

      expect(states.length, stateCountAfterStart + 1);
      expect(states.last.position, const Duration(seconds: 1));

      await sub.cancel();
      await handler.dispose();
    },
  );

  test('audio handler publishes paused playback state immediately', () async {
    final player = LaggyPauseFakeJustAudioPlayer();
    final handler = audio_service.MikudromeAudioHandler(player: player);
    final states = <MobileAudioPlaybackState>[];
    final sub = handler.mikudromeState.listen(states.add);

    await handler.setMikudromeQueue(
      tracks: [_track(1)],
      audioUrls: const ['http://server/audio/1'],
      initialIndex: 0,
    );
    player.setPosition(const Duration(seconds: 12));

    await handler.pause();

    expect(handler.playbackState.value.playing, isFalse);
    expect(handler.playbackState.value.speed, 0.0);
    expect(handler.playbackState.value.position, const Duration(seconds: 12));
    expect(states.last.isPlaying, isFalse);
    expect(states.last.position, const Duration(seconds: 12));

    await sub.cancel();
    await handler.dispose();
  });

  test(
    'audio handler does not re-emit playing when initial play completes on pause',
    () async {
      final player = PlayCompletesOnPauseFakeJustAudioPlayer();
      final handler = audio_service.MikudromeAudioHandler(player: player);
      final states = <MobileAudioPlaybackState>[];
      final sub = handler.mikudromeState.listen(states.add);

      final queueFuture = handler.setMikudromeQueue(
        tracks: [_track(1)],
        audioUrls: const ['http://server/audio/1'],
        initialIndex: 0,
      );
      await pumpEventQueue();
      expect(player.playCalls, 1);
      expect(states.last.isPlaying, isTrue);
      player.setPosition(const Duration(seconds: 12));

      await handler.pause();
      await pumpEventQueue();
      await queueFuture;

      expect(handler.playbackState.value.playing, isFalse);
      expect(handler.playbackState.value.speed, 0.0);
      expect(handler.playbackState.value.position, const Duration(seconds: 12));
      expect(states.last.isPlaying, isFalse);
      expect(states.last.position, const Duration(seconds: 12));

      await sub.cancel();
      await handler.dispose();
    },
  );

  test(
    'audio handler freezes paused playback position at the latest player position',
    () async {
      final player = SilentPositionFakeJustAudioPlayer();
      final handler = audio_service.MikudromeAudioHandler(player: player);
      final states = <MobileAudioPlaybackState>[];
      final sub = handler.mikudromeState.listen(states.add);

      await handler.setMikudromeQueue(
        tracks: [_track(1)],
        audioUrls: const ['http://server/audio/1'],
        initialIndex: 0,
      );
      player.setPositionSilently(const Duration(seconds: 18));

      await handler.pause();

      expect(handler.playbackState.value.playing, isFalse);
      expect(handler.playbackState.value.speed, 0.0);
      expect(handler.playbackState.value.position, const Duration(seconds: 18));
      expect(states.last.position, const Duration(seconds: 18));
      expect(states.last.isPlaying, isFalse);

      player.emitPosition(Duration.zero);
      player.emitPosition(const Duration(seconds: 21));

      expect(handler.playbackState.value.position, const Duration(seconds: 18));
      expect(states.last.position, const Duration(seconds: 18));
      expect(states.last.isPlaying, isFalse);

      await sub.cancel();
      await handler.dispose();
    },
  );

  test(
    'audio handler keeps paused position frozen while the player still emits updates',
    () async {
      final player = FakeJustAudioPlayer();
      final handler = audio_service.MikudromeAudioHandler(player: player);
      final states = <MobileAudioPlaybackState>[];
      final sub = handler.mikudromeState.listen(states.add);

      await handler.setMikudromeQueue(
        tracks: [_track(1)],
        audioUrls: const ['http://server/audio/1'],
        initialIndex: 0,
      );
      player.setPosition(const Duration(seconds: 12));

      await handler.pause();
      player.setPosition(const Duration(seconds: 13));
      player.setPosition(const Duration(seconds: 0));

      expect(handler.playbackState.value.playing, isFalse);
      expect(handler.playbackState.value.speed, 0.0);
      expect(handler.playbackState.value.position, const Duration(seconds: 12));
      expect(states.last.position, const Duration(seconds: 12));
      expect(states.last.isPlaying, isFalse);

      await sub.cancel();
      await handler.dispose();
    },
  );

  test(
    'audio handler treats seek as paused while player playing flag is stale',
    () async {
      final player = LaggyPauseAndSeekFakeJustAudioPlayer();
      final handler = audio_service.MikudromeAudioHandler(player: player);
      final states = <MobileAudioPlaybackState>[];
      final sub = handler.mikudromeState.listen(states.add);

      await handler.setMikudromeQueue(
        tracks: [_track(1)],
        audioUrls: const ['http://server/audio/1'],
        initialIndex: 0,
      );
      player.setPosition(const Duration(seconds: 12));

      await handler.pause();
      await handler.seek(const Duration(seconds: 30));

      expect(handler.playbackState.value.playing, isFalse);
      expect(handler.playbackState.value.speed, 0.0);
      expect(handler.playbackState.value.position, const Duration(seconds: 30));
      expect(states.last.isPlaying, isFalse);
      expect(states.last.position, const Duration(seconds: 30));

      await sub.cancel();
      await handler.dispose();
    },
  );

  test(
    'audio handler keeps paused seek when player re-emits the same index',
    () async {
      final player = SameIndexAfterSeekFakeJustAudioPlayer();
      final handler = audio_service.MikudromeAudioHandler(player: player);
      final states = <MobileAudioPlaybackState>[];
      final sub = handler.mikudromeState.listen(states.add);

      await handler.setMikudromeQueue(
        tracks: [_track(1)],
        audioUrls: const ['http://server/audio/1'],
        initialIndex: 0,
      );
      player.setPosition(const Duration(seconds: 12));

      await handler.pause();
      await handler.seek(const Duration(seconds: 30));
      await pumpEventQueue();

      expect(handler.playbackState.value.playing, isFalse);
      expect(handler.playbackState.value.speed, 0.0);
      expect(handler.playbackState.value.position, const Duration(seconds: 30));
      expect(states.last.isPlaying, isFalse);
      expect(states.last.position, const Duration(seconds: 30));

      await sub.cancel();
      await handler.dispose();
    },
  );

  test('audio handler clears paused freeze lock when pause fails', () async {
    final player = FailingPauseFakeJustAudioPlayer();
    final handler = audio_service.MikudromeAudioHandler(player: player);
    final states = <MobileAudioPlaybackState>[];
    final sub = handler.mikudromeState.listen(states.add);

    await handler.setMikudromeQueue(
      tracks: [_track(1)],
      audioUrls: const ['http://server/audio/1'],
      initialIndex: 0,
    );
    player.setPosition(const Duration(seconds: 14));

    await expectLater(handler.pause(), throwsStateError);

    player.setPosition(const Duration(seconds: 15));

    expect(handler.playbackState.value.playing, isTrue);
    expect(states.last.isPlaying, isTrue);
    expect(states.last.position, const Duration(seconds: 15));

    await sub.cancel();
    await handler.dispose();
  });

  test('audio handler keeps paused seek position stable during seek', () async {
    final player = LaggySeekFakeJustAudioPlayer();
    final handler = audio_service.MikudromeAudioHandler(player: player);
    final states = <MobileAudioPlaybackState>[];
    final sub = handler.mikudromeState.listen(states.add);

    await handler.setMikudromeQueue(
      tracks: [_track(1)],
      audioUrls: const ['http://server/audio/1'],
      initialIndex: 0,
    );
    await handler.pause();
    expect(handler.playbackState.value.playing, isFalse);
    expect(handler.playbackState.value.speed, 0.0);
    final stateCountBeforeSeek = states.length;

    await handler.seek(const Duration(seconds: 30));

    expect(handler.playbackState.value.playing, isFalse);
    expect(handler.playbackState.value.speed, 0.0);
    expect(handler.playbackState.value.position, const Duration(seconds: 30));
    expect(states.length, greaterThan(stateCountBeforeSeek));
    expect(
      states.skip(stateCountBeforeSeek).first.position,
      const Duration(seconds: 30),
    );
    expect(states.last.position, const Duration(seconds: 30));
    expect(states.last.isPlaying, isFalse);

    await sub.cancel();
    await handler.dispose();
  });

  test(
    'audio handler ignores delayed stale paused position updates after seek',
    () async {
      final player = SilentSeekFakeJustAudioPlayer();
      final handler = audio_service.MikudromeAudioHandler(player: player);
      final states = <MobileAudioPlaybackState>[];
      final sub = handler.mikudromeState.listen(states.add);

      await handler.setMikudromeQueue(
        tracks: [_track(1)],
        audioUrls: const ['http://server/audio/1'],
        initialIndex: 0,
      );
      await handler.pause();
      await handler.seek(const Duration(seconds: 30));

      player.setPosition(Duration.zero);

      expect(handler.playbackState.value.playing, isFalse);
      expect(handler.playbackState.value.speed, 0.0);
      expect(handler.playbackState.value.position, const Duration(seconds: 30));
      expect(states.last.position, const Duration(seconds: 30));
      expect(states.last.isPlaying, isFalse);

      await sub.cancel();
      await handler.dispose();
    },
  );

  test(
    'audio handler keeps paused position when player emits zero after pause',
    () async {
      final player = FakeJustAudioPlayer();
      final handler = audio_service.MikudromeAudioHandler(player: player);
      final states = <MobileAudioPlaybackState>[];
      final sub = handler.mikudromeState.listen(states.add);

      await handler.setMikudromeQueue(
        tracks: [_track(1)],
        audioUrls: const ['http://server/audio/1'],
        initialIndex: 0,
      );
      player.setPosition(const Duration(seconds: 18));

      await handler.pause();
      player.setPosition(Duration.zero);

      expect(handler.playbackState.value.playing, isFalse);
      expect(handler.playbackState.value.speed, 0.0);
      expect(handler.playbackState.value.position, const Duration(seconds: 18));
      expect(states.last.position, const Duration(seconds: 18));
      expect(states.last.isPlaying, isFalse);

      await sub.cancel();
      await handler.dispose();
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

  test('just_audio service stops playback before clearing cache', () async {
    final player = FakeJustAudioPlayer();
    var stopCallsObservedByClearer = -1;
    var clearCalls = 0;
    final service = audio_service.JustAudioMobileAudioPlaybackService(
      player: player,
      cacheClearer: () async {
        clearCalls += 1;
        stopCallsObservedByClearer = player.stopCalls;
      },
    );

    await service.playQueue(
      queue: [_track(1)],
      index: 0,
      audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
    );

    await service.clearCache();

    expect(clearCalls, 1);
    expect(stopCallsObservedByClearer, 1);
    expect(service.currentState.queue, isEmpty);

    await service.dispose();
  });

  test('just_audio service ignores temporary cache clear failures', () async {
    final player = FakeJustAudioPlayer();
    final service = audio_service.JustAudioMobileAudioPlaybackService(
      player: player,
      cacheClearer: () async => throw const FileSystemException('cache busy'),
    );

    await service.playQueue(
      queue: [_track(1)],
      index: 0,
      audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
    );

    await expectLater(service.clearCache(), completes);
    expect(service.currentState.queue, isEmpty);

    await service.dispose();
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

  test('queue load failure does not poison later queue mutations', () async {
    final player = DelayedSetAudioSourcesFakeJustAudioPlayer(
      delayedError: StateError('load failed'),
    );
    final service = audio_service.JustAudioMobileAudioPlaybackService(
      player: player,
    );
    final unhandledErrors = <Object>[];

    await runZonedGuarded(() async {
      final failingLoad = service.playQueue(
        queue: [_track(1)],
        index: 0,
        audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
      );
      await player.delayedSetStarted;
      final successfulLoad = service.playQueue(
        queue: [_track(2)],
        index: 0,
        audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
      );

      final failingExpectation = expectLater(failingLoad, throwsStateError);
      final successfulExpectation = expectLater(successfulLoad, completes);
      player.completeDelayedSet();
      await Future.wait([failingExpectation, successfulExpectation]);
      await pumpEventQueue();
    }, (error, stackTrace) => unhandledErrors.add(error));

    expect(unhandledErrors, isEmpty);
    expect(player.setAudioSourcesCalls, 2);
    expect(service.currentState.track?.id, 2);

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
    expect(
      File(
        'android/app/src/main/res/drawable/ic_notification.xml',
      ).existsSync(),
      isTrue,
    );
  });

  test('android favorite notification icons exist', () {
    expect(
      File('android/app/src/main/res/drawable/ic_favorite.xml').existsSync(),
      isTrue,
    );
    expect(
      File(
        'android/app/src/main/res/drawable/ic_favorite_border.xml',
      ).existsSync(),
      isTrue,
    );
  });

  test('audio service config uses dedicated android notification icon', () {
    final source = File(
      'lib/services/mobile_audio_playback_audio_service.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("androidNotificationIcon: 'drawable/ic_notification'"),
    );
  });

  test('audio handler stops playback when Android task is removed', () async {
    final player = FakeJustAudioPlayer();
    final handler = audio_service.MikudromeAudioHandler(player: player);

    await handler.setMikudromeQueue(
      tracks: [_track(1)],
      audioUrls: const ['http://server/audio/1'],
      initialIndex: 0,
    );

    await handler.onTaskRemoved();

    expect(player.stopCalls, 1);
    await handler.dispose();
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

  test(
    'mobile audio lifecycle keeps service playing when app backgrounds',
    () async {
      final service = RecordingMobileAudioPlaybackService();

      await pauseMobileAudioPlaybackForLifecycle(
        lifecycleState: AppLifecycleState.inactive,
        isMobile: true,
        playbackMode: PlaybackMode.audio,
        service: service,
      );
      await pauseMobileAudioPlaybackForLifecycle(
        lifecycleState: AppLifecycleState.paused,
        isMobile: false,
        playbackMode: PlaybackMode.audio,
        service: service,
      );
      await pauseMobileAudioPlaybackForLifecycle(
        lifecycleState: AppLifecycleState.paused,
        isMobile: true,
        playbackMode: PlaybackMode.video,
        service: service,
      );
      await pauseMobileAudioPlaybackForLifecycle(
        lifecycleState: AppLifecycleState.paused,
        isMobile: true,
        playbackMode: PlaybackMode.audio,
        service: service,
      );

      expect(service.pauseCalls, 0);
    },
  );
}

Track _track(int id) => Track(
  id: id,
  title: 'Track $id',
  audioPath: '/audio/$id.flac',
  videoPath: '',
  albumId: id,
  durationSeconds: 120,
);

MediaControl _favoriteControl(audio_service.MikudromeAudioHandler handler) {
  return handler.playbackState.value.controls.singleWhere(
    (control) => control.customAction?.name == 'toggleFavorite',
  );
}

Uri _sourceUri(AudioSource source) {
  if (source is LockCachingAudioSource) return source.uri;
  if (source is UriAudioSource) return source.uri;
  throw StateError('Unsupported test audio source: ${source.runtimeType}');
}

class FakeJustAudioPlayer implements audio_service.MobileAudioPlayerAdapter {
  final _playing = StreamController<bool>.broadcast(sync: true);
  final _currentIndex = StreamController<int?>.broadcast(sync: true);
  final _processingState = StreamController<ProcessingState>.broadcast(
    sync: true,
  );
  final _position = StreamController<Duration>.broadcast(sync: true);
  final _duration = StreamController<Duration?>.broadcast(sync: true);
  final _errors = StreamController<PlayerException>.broadcast(sync: true);

  List<AudioSource> sources = [];
  int setAudioSourcesCalls = 0;
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
  LoopMode loopMode = LoopMode.off;
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
  Stream<PlayerException> get errorStream => _errors.stream;

  @override
  Future<void> setAudioSources(
    List<AudioSource> sources, {
    required int initialIndex,
    required Duration initialPosition,
  }) async {
    setAudioSourcesCalls += 1;
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
  Future<void> setLoopMode(LoopMode loopMode) async {
    this.loopMode = loopMode;
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
    await _errors.close();
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

  void emitError(PlayerException error) {
    _errors.add(error);
  }
}

class DelayedSetAudioSourcesFakeJustAudioPlayer extends FakeJustAudioPlayer {
  DelayedSetAudioSourcesFakeJustAudioPlayer({
    this.delayedInvocation = 1,
    this.delayedError,
  });

  final int delayedInvocation;
  final Object? delayedError;
  final _delayedSetStarted = Completer<void>();
  final _releaseDelayedSet = Completer<void>();
  int _setAudioSourcesInvocations = 0;
  int activeSetAudioSourcesCalls = 0;
  int maxConcurrentSetAudioSourcesCalls = 0;
  final appliedSourceUrls = <List<String>>[];

  Future<void> get firstSetStarted => delayedSetStarted;

  Future<void> get delayedSetStarted => _delayedSetStarted.future;

  void completeFirstSet() => completeDelayedSet();

  void completeDelayedSet() {
    if (!_releaseDelayedSet.isCompleted) {
      _releaseDelayedSet.complete();
    }
  }

  @override
  Future<void> setAudioSources(
    List<AudioSource> sources, {
    required int initialIndex,
    required Duration initialPosition,
  }) async {
    final invocation = ++_setAudioSourcesInvocations;
    activeSetAudioSourcesCalls += 1;
    maxConcurrentSetAudioSourcesCalls = max(
      maxConcurrentSetAudioSourcesCalls,
      activeSetAudioSourcesCalls,
    );
    try {
      if (invocation == delayedInvocation) {
        _delayedSetStarted.complete();
        await _releaseDelayedSet.future;
        final error = delayedError;
        if (error != null) {
          setAudioSourcesCalls += 1;
          throw error;
        }
      }
      await super.setAudioSources(
        sources,
        initialIndex: initialIndex,
        initialPosition: initialPosition,
      );
      appliedSourceUrls.add(
        sources.map((source) => _sourceUri(source).toString()).toList(),
      );
    } finally {
      activeSetAudioSourcesCalls -= 1;
    }
  }

  @override
  Future<void> dispose() async {
    completeDelayedSet();
    await super.dispose();
  }
}

class DelayedRecoverySeekFakeJustAudioPlayer extends FakeJustAudioPlayer {
  final _recoverySeekStarted = Completer<void>();
  final _releaseRecoverySeek = Completer<void>();

  Future<void> get recoverySeekStarted => _recoverySeekStarted.future;

  void completeRecoverySeek() {
    if (!_releaseRecoverySeek.isCompleted) {
      _releaseRecoverySeek.complete();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (!_recoverySeekStarted.isCompleted) {
      _recoverySeekStarted.complete();
    }
    await _releaseRecoverySeek.future;
    seekPositions.add(position);
    setPosition(position);
  }

  @override
  Future<void> dispose() async {
    completeRecoverySeek();
    await super.dispose();
  }
}

class DelayedRecoveryPlayErrorFakeJustAudioPlayer extends FakeJustAudioPlayer {
  final _recoveryPlayStarted = Completer<void>();
  final _recoveryPlay = Completer<void>();

  Future<void> get recoveryPlayStarted => _recoveryPlayStarted.future;

  void failRecoveryPlay() {
    if (!_recoveryPlay.isCompleted) {
      _recoveryPlay.completeError(StateError('recovery play failed'));
    }
  }

  @override
  Future<void> play() {
    playCalls += 1;
    setPlaying(true);
    if (playCalls == 2) {
      _recoveryPlayStarted.complete();
      return _recoveryPlay.future;
    }
    return Future<void>.value();
  }

  @override
  Future<void> dispose() async {
    failRecoveryPlay();
    await super.dispose();
  }
}

class LaggySeekFakeJustAudioPlayer extends FakeJustAudioPlayer {
  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
    setPosition(Duration.zero);
  }
}

class LaggyPauseFakeJustAudioPlayer extends FakeJustAudioPlayer {
  @override
  Future<void> pause() async {
    pauseCalls += 1;
  }
}

class PlayCompletesOnPauseFakeJustAudioPlayer extends FakeJustAudioPlayer {
  Completer<void>? _playCompleter;

  @override
  Future<void> play() {
    playCalls += 1;
    setPlaying(true);
    final completer = Completer<void>();
    _playCompleter = completer;
    return completer.future;
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
    setPlaying(false);
    _playCompleter?.complete();
    _playCompleter = null;
  }
}

class LaggyPauseAndSeekFakeJustAudioPlayer
    extends LaggyPauseFakeJustAudioPlayer {
  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
    setPosition(Duration.zero);
  }
}

class SameIndexAfterSeekFakeJustAudioPlayer extends FakeJustAudioPlayer {
  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
    Timer.run(() {
      setCurrentIndex(currentIndex);
      setPosition(Duration.zero);
    });
  }
}

class SilentSeekFakeJustAudioPlayer extends FakeJustAudioPlayer {
  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
  }
}

class FailingPauseFakeJustAudioPlayer extends FakeJustAudioPlayer {
  @override
  Future<void> pause() async {
    pauseCalls += 1;
    throw StateError('pause failed');
  }
}

class SilentPositionFakeJustAudioPlayer extends FakeJustAudioPlayer {
  void setPositionSilently(Duration value) {
    position = value;
  }

  void emitPosition(Duration value) {
    position = value;
    _position.add(value);
  }
}

class RecordingMobileAudioPlaybackService
    extends NoopMobileAudioPlaybackService {
  int stopCalls = 0;
  int pauseCalls = 0;

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
  }
}
