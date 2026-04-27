import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../models/track.dart';
import 'mobile_audio_playback.dart';

MobileAudioPlaybackService createMobileAudioPlaybackService() {
  return JustAudioMobileAudioPlaybackService();
}

abstract class MobileAudioPlayerAdapter {
  Stream<bool> get playingStream;
  Stream<int?> get currentIndexStream;
  Stream<ProcessingState> get processingStateStream;
  bool get playing;
  int? get currentIndex;

  Future<void> setAudioSources(
    List<UriAudioSource> sources, {
    required int initialIndex,
    required Duration initialPosition,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> seekToNext();
  Future<void> seekToPrevious();
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioMobileAudioPlaybackService
    implements MobileAudioPlaybackService {
  JustAudioMobileAudioPlaybackService({MobileAudioPlayerAdapter? player})
    : _player = player ?? JustAudioPlayerAdapter(),
      _states = StreamController<MobileAudioPlaybackState>.broadcast(
        sync: true,
      ) {
    _subscriptions.add(_player.playingStream.listen(_handlePlayingChanged));
    _subscriptions.add(
      _player.currentIndexStream.listen(_handleCurrentIndexChanged),
    );
    _subscriptions.add(
      _player.processingStateStream.listen(_handleProcessingStateChanged),
    );
  }

  final MobileAudioPlayerAdapter _player;
  final StreamController<MobileAudioPlaybackState> _states;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  List<Track> _queue = const [];
  List<String> _audioUrls = const [];
  MobileAudioPlaybackState _currentState = MobileAudioPlaybackState.empty();
  bool _disposed = false;

  @override
  Stream<MobileAudioPlaybackState> get states => _states.stream;

  @override
  MobileAudioPlaybackState get currentState => _currentState;

  @override
  Future<void> playQueue({
    required List<Track> queue,
    required int index,
    required AudioUrlForTrack audioUrlForTrack,
  }) async {
    if (_disposed) return;

    if (queue.isEmpty) {
      _queue = const [];
      _audioUrls = const [];
      await _player.stop();
      _emit(MobileAudioPlaybackState.empty());
      return;
    }

    final nextQueue = List<Track>.unmodifiable(queue);
    final nextAudioUrls = List<String>.unmodifiable(
      nextQueue.map(audioUrlForTrack),
    );
    final clampedIndex = index.clamp(0, nextQueue.length - 1);
    final sources = nextAudioUrls
        .map((url) => AudioSource.uri(Uri.parse(url)))
        .toList(growable: false);

    await _player.setAudioSources(
      sources,
      initialIndex: clampedIndex,
      initialPosition: Duration.zero,
    );
    _queue = nextQueue;
    _audioUrls = nextAudioUrls;
    _emitState(index: clampedIndex, isPlaying: _player.playing);
    unawaited(_startPlaybackSafely(clampedIndex));
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed) return;
    await _player.seek(position);
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    await _player.stop();
    _queue = const [];
    _audioUrls = const [];
    _emit(MobileAudioPlaybackState.empty());
  }

  @override
  Future<void> next() async {
    if (_disposed || _queue.isEmpty) return;
    await _player.seekToNext();
  }

  @override
  Future<void> previous() async {
    if (_disposed || _queue.isEmpty) return;
    await _player.seekToPrevious();
  }

  Future<void> _startPlaybackSafely(int index) async {
    try {
      await _player.play();
    } catch (_) {
      if (!_disposed) {
        _emitState(index: index, isPlaying: false);
      }
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _states.close();
  }

  void _handlePlayingChanged(bool isPlaying) {
    if (_queue.isEmpty) return;
    _emitState(isPlaying: isPlaying);
  }

  void _handleCurrentIndexChanged(int? index) {
    if (index == null || _queue.isEmpty) return;
    _emitState(index: index);
  }

  void _handleProcessingStateChanged(ProcessingState state) {
    if (state == ProcessingState.completed && _queue.isNotEmpty) {
      _emitState(isPlaying: false);
    }
  }

  void _emitState({int? index, bool? isPlaying}) {
    if (_queue.isEmpty) {
      _emit(MobileAudioPlaybackState.empty());
      return;
    }

    final effectiveIndex =
        (index ?? _player.currentIndex ?? _currentState.index).clamp(
          0,
          _queue.length - 1,
        );
    _emit(
      MobileAudioPlaybackState(
        queue: _queue,
        index: effectiveIndex,
        isPlaying: isPlaying ?? _player.playing,
        audioUrl: _audioUrls[effectiveIndex],
      ),
    );
  }

  void _emit(MobileAudioPlaybackState state) {
    if (_disposed) return;
    _currentState = state;
    _states.add(state);
  }
}

class JustAudioPlayerAdapter implements MobileAudioPlayerAdapter {
  JustAudioPlayerAdapter({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  @override
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  @override
  bool get playing => _player.playing;

  @override
  int? get currentIndex => _player.currentIndex;

  @override
  Future<void> setAudioSources(
    List<UriAudioSource> sources, {
    required int initialIndex,
    required Duration initialPosition,
  }) async {
    await _player.setAudioSources(
      sources,
      initialIndex: initialIndex,
      initialPosition: initialPosition,
      preload: false,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> seekToNext() => _player.seekToNext();

  @override
  Future<void> seekToPrevious() => _player.seekToPrevious();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
