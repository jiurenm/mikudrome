import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../api/config.dart';
import '../models/track.dart';
import 'mobile_audio_playback.dart';

MobileAudioPlaybackService createMobileAudioPlaybackService() {
  return JustAudioMobileAudioPlaybackService();
}

abstract class MobileAudioPlayerAdapter {
  Stream<bool> get playingStream;
  Stream<int?> get currentIndexStream;
  Stream<ProcessingState> get processingStateStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  bool get playing;
  int? get currentIndex;
  Duration get position;
  Duration? get duration;

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

class MikudromeAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  MikudromeAudioHandler({MobileAudioPlayerAdapter? player})
    : _player = player ?? JustAudioPlayerAdapter() {
    _subscriptions.add(
      _player.currentIndexStream.listen(_handleCurrentIndexChanged),
    );
  }

  final MobileAudioPlayerAdapter _player;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  List<Track> _tracks = const [];
  List<String> _audioUrls = const [];
  bool _disposed = false;

  Future<void> setMikudromeQueue({
    required List<Track> tracks,
    required List<String> audioUrls,
    required int initialIndex,
  }) async {
    if (_disposed) return;
    if (tracks.isEmpty) {
      _tracks = const [];
      _audioUrls = const [];
      queue.add(const []);
      mediaItem.add(null);
      await _player.stop();
      return;
    }

    _tracks = List<Track>.unmodifiable(tracks);
    _audioUrls = List<String>.unmodifiable(audioUrls);
    final clampedIndex = initialIndex.clamp(0, _tracks.length - 1);
    final items = [
      for (var i = 0; i < _tracks.length; i++)
        MediaItem(
          id: _audioUrls[i],
          title: _tracks[i].title,
          artist: _tracks[i].vocalLine,
          duration: Duration(seconds: _tracks[i].durationSeconds),
        ),
    ];

    queue.add(items);
    mediaItem.add(items[clampedIndex]);
    await _player.setAudioSources(
      _audioUrls
          .map(
            (url) => AudioSource.uri(
              Uri.parse(url),
              headers: ApiConfig.defaultHeaders,
            ),
          )
          .toList(growable: false),
      initialIndex: clampedIndex,
      initialPosition: Duration.zero,
    );
  }

  void _handleCurrentIndexChanged(int? index) {
    if (index == null || queue.value.isEmpty) return;
    final clampedIndex = index.clamp(0, queue.value.length - 1);
    mediaItem.add(queue.value[clampedIndex]);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
  }
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
    _subscriptions.add(_player.positionStream.listen(_handlePositionChanged));
    _subscriptions.add(_player.durationStream.listen(_handleDurationChanged));
  }

  final MobileAudioPlayerAdapter _player;
  final StreamController<MobileAudioPlaybackState> _states;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  List<Track> _queue = const [];
  List<String> _audioUrls = const [];
  MobileAudioPlaybackState _currentState = MobileAudioPlaybackState.empty();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isCompleted = false;
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
        .map(
          (url) => AudioSource.uri(
            Uri.parse(url),
            headers: ApiConfig.defaultHeaders,
          ),
        )
        .toList(growable: false);

    await _player.setAudioSources(
      sources,
      initialIndex: clampedIndex,
      initialPosition: Duration.zero,
    );
    _queue = nextQueue;
    _audioUrls = nextAudioUrls;
    _position = Duration.zero;
    _duration = Duration(seconds: nextQueue[clampedIndex].durationSeconds);
    _isCompleted = false;
    _emitState(index: clampedIndex, isPlaying: _player.playing);
    unawaited(_startPlaybackSafely(clampedIndex));
  }

  @override
  Future<void> play() async {
    if (_disposed || _queue.isEmpty) return;
    await _startPlaybackSafely(_currentState.index);
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
    _position = position;
    _isCompleted = false;
    _emitState(position: _position, isCompleted: false);
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    await _player.stop();
    _queue = const [];
    _audioUrls = const [];
    _position = Duration.zero;
    _duration = Duration.zero;
    _isCompleted = false;
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
    _emitState(isPlaying: isPlaying, isCompleted: isPlaying ? false : null);
  }

  void _handleCurrentIndexChanged(int? index) {
    if (index == null || _queue.isEmpty) return;
    final effectiveIndex = index.clamp(0, _queue.length - 1);
    _position = Duration.zero;
    _duration = Duration(seconds: _queue[effectiveIndex].durationSeconds);
    _isCompleted = false;
    _emitState(index: effectiveIndex, position: _position, isCompleted: false);
  }

  void _handleProcessingStateChanged(ProcessingState state) {
    if (state == ProcessingState.completed && _queue.isNotEmpty) {
      _isCompleted = true;
      _emitState(isPlaying: false, isCompleted: true);
    } else if (state == ProcessingState.ready ||
        state == ProcessingState.loading) {
      if (_isCompleted) {
        _isCompleted = false;
        _emitState(isCompleted: false);
      }
    }
  }

  void _handlePositionChanged(Duration position) {
    if (_queue.isEmpty) return;
    _position = position;
    _emitState(position: position);
  }

  void _handleDurationChanged(Duration? duration) {
    if (_queue.isEmpty) return;
    _duration =
        duration ??
        Duration(seconds: _currentState.track?.durationSeconds ?? 0);
    _emitState(duration: _duration);
  }

  void _emitState({
    int? index,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isCompleted,
  }) {
    if (_queue.isEmpty) {
      _emit(MobileAudioPlaybackState.empty());
      return;
    }

    final effectiveIndex =
        (index ?? _player.currentIndex ?? _currentState.index).clamp(
          0,
          _queue.length - 1,
        );
    final effectivePosition = position ?? _position;
    final effectiveDuration = duration ?? _duration;
    final effectiveCompleted = isCompleted ?? _isCompleted;
    _position = effectivePosition;
    _duration = effectiveDuration;
    _isCompleted = effectiveCompleted;
    _emit(
      MobileAudioPlaybackState(
        queue: _queue,
        index: effectiveIndex,
        isPlaying: isPlaying ?? _player.playing,
        position: effectivePosition,
        duration: effectiveDuration,
        isCompleted: effectiveCompleted,
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
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  bool get playing => _player.playing;

  @override
  int? get currentIndex => _player.currentIndex;

  @override
  Duration get position => _player.position;

  @override
  Duration? get duration => _player.duration;

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
