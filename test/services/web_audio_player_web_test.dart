import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/services/web_audio_player_stub.dart';
import 'package:mikudrome/services/web_audio_player_contract.dart';

class _FakeAudioAdapter implements WebAudioElementAdapter {
  final List<String> sources = <String>[];
  final _loadedMetadataController = StreamController<void>.broadcast();
  final _timeUpdateController = StreamController<void>.broadcast();
  final _playController = StreamController<void>.broadcast();
  final _pauseController = StreamController<void>.broadcast();
  final _endedController = StreamController<void>.broadcast();
  final _errorController = StreamController<String?>.broadcast();

  Duration _currentPosition = Duration.zero;
  Duration _duration = Duration.zero;
  int playCallCount = 0;

  @override
  String get src => sources.isEmpty ? '' : sources.last;

  @override
  set src(String value) {
    sources.add(value);
  }

  @override
  Duration get currentPosition => _currentPosition;

  @override
  set currentPosition(Duration value) {
    _currentPosition = value;
    _timeUpdateController.add(null);
  }

  @override
  Duration get duration => _duration;

  @override
  Future<void> play() async {
    playCallCount++;
    _playController.add(null);
  }

  @override
  void pause() {
    _pauseController.add(null);
  }

  @override
  void load() {}

  @override
  void dispose() {
    unawaited(_loadedMetadataController.close());
    unawaited(_timeUpdateController.close());
    unawaited(_playController.close());
    unawaited(_pauseController.close());
    unawaited(_endedController.close());
    unawaited(_errorController.close());
  }

  @override
  Stream<void> get onEnded => _endedController.stream;

  @override
  Stream<String?> get onError => _errorController.stream;

  @override
  Stream<void> get onLoadedMetadata => _loadedMetadataController.stream;

  @override
  Stream<void> get onPause => _pauseController.stream;

  @override
  Stream<void> get onPlay => _playController.stream;

  @override
  Stream<void> get onTimeUpdate => _timeUpdateController.stream;

  void emitLoadedMetadata({required Duration duration}) {
    _duration = duration;
    _loadedMetadataController.add(null);
  }

  void emitEnded() {
    _currentPosition = _duration;
    _endedController.add(null);
  }
}

void main() {
  test(
      'persistent web audio player reports completion and can load a new track',
      () async {
    final adapter = _FakeAudioAdapter();
    final player = createWebAudioPlayerForTest(adapter: adapter);

    await player.load(
      url: 'https://example.test/one.mp3',
      initialPosition: const Duration(seconds: 1),
      autoplay: true,
    );
    adapter.emitLoadedMetadata(duration: const Duration(seconds: 10));
    await Future<void>.delayed(Duration.zero);
    adapter.emitEnded();
    await Future<void>.delayed(Duration.zero);

    expect(player.value.isCompleted, isTrue);
    expect(player.value.position, const Duration(seconds: 10));

    await player.load(
      url: 'https://example.test/two.mp3',
      initialPosition: Duration.zero,
      autoplay: true,
    );
    adapter.emitLoadedMetadata(duration: const Duration(seconds: 8));
    await Future<void>.delayed(Duration.zero);

    expect(adapter.sources.last, 'https://example.test/two.mp3');
    expect(adapter.playCallCount, 2);
    expect(player.value.isCompleted, isFalse);
  });

  test('web audio player emits diagnostic messages for load and completion',
      () async {
    final adapter = _FakeAudioAdapter();
    final player = createWebAudioPlayerForTest(adapter: adapter);

    await player.load(
      url: 'https://example.test/diagnostic.mp3',
      initialPosition: Duration.zero,
      autoplay: true,
    );
    adapter.emitLoadedMetadata(duration: const Duration(seconds: 5));
    await Future<void>.delayed(Duration.zero);
    adapter.emitEnded();
    await Future<void>.delayed(Duration.zero);

    expect(player.value.isCompleted, isTrue);
    expect(player.value.duration, const Duration(seconds: 5));
  });

  test('loading the same url again reuses the current player state', () async {
    final adapter = _FakeAudioAdapter();
    final player = createWebAudioPlayerForTest(adapter: adapter);

    await player.load(
      url: 'https://example.test/reuse.mp3',
      initialPosition: Duration.zero,
      autoplay: true,
    );
    adapter.emitLoadedMetadata(duration: const Duration(seconds: 20));
    await Future<void>.delayed(Duration.zero);
    adapter.currentPosition = const Duration(seconds: 4);
    await Future<void>.delayed(Duration.zero);

    await player.load(
      url: 'https://example.test/reuse.mp3',
      initialPosition: Duration.zero,
      autoplay: true,
    );

    expect(adapter.sources.length, 1);
    expect(player.value.position, const Duration(seconds: 4));
  });
}
