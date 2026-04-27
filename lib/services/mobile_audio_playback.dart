import 'dart:async';

import '../models/track.dart';
export 'mobile_audio_playback_service.dart';

typedef AudioUrlForTrack = String Function(Track track);

class MobileAudioPlaybackState {
  const MobileAudioPlaybackState({
    required this.queue,
    required this.index,
    required this.isPlaying,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isCompleted = false,
    this.audioUrl,
  });

  factory MobileAudioPlaybackState.empty() {
    return const MobileAudioPlaybackState(
      queue: [],
      index: 0,
      isPlaying: false,
    );
  }

  final List<Track> queue;
  final int index;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isCompleted;
  final String? audioUrl;

  Track? get track => queue.isEmpty ? null : queue[index];

  MobileAudioPlaybackState copyWith({
    List<Track>? queue,
    int? index,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isCompleted,
    String? audioUrl,
  }) {
    return MobileAudioPlaybackState(
      queue: queue ?? this.queue,
      index: index ?? this.index,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isCompleted: isCompleted ?? this.isCompleted,
      audioUrl: audioUrl ?? this.audioUrl,
    );
  }
}

abstract class MobileAudioPlaybackService {
  Stream<MobileAudioPlaybackState> get states;
  MobileAudioPlaybackState get currentState;

  Future<void> playQueue({
    required List<Track> queue,
    required int index,
    required AudioUrlForTrack audioUrlForTrack,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> next();
  Future<void> previous();
  Future<void> dispose();
}

class FakeMobileAudioPlaybackService implements MobileAudioPlaybackService {
  FakeMobileAudioPlaybackService()
    : _states = StreamController<MobileAudioPlaybackState>.broadcast(
        sync: true,
      );

  final StreamController<MobileAudioPlaybackState> _states;
  AudioUrlForTrack? _audioUrlForTrack;
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
    _audioUrlForTrack = audioUrlForTrack;
    if (queue.isEmpty) {
      _emit(MobileAudioPlaybackState.empty());
      return;
    }

    final clampedIndex = index.clamp(0, queue.length - 1);
    final immutableQueue = List<Track>.unmodifiable(queue);
    final track = immutableQueue[clampedIndex];
    _emit(
      MobileAudioPlaybackState(
        queue: immutableQueue,
        index: clampedIndex,
        isPlaying: true,
        duration: Duration(seconds: track.durationSeconds),
        audioUrl: audioUrlForTrack(track),
      ),
    );
  }

  @override
  Future<void> play() async {
    if (_currentState.queue.isEmpty) return;
    _emit(_currentState.copyWith(isPlaying: true));
  }

  @override
  Future<void> pause() async {
    _emit(_currentState.copyWith(isPlaying: false));
  }

  @override
  Future<void> seek(Duration position) async {
    if (_currentState.queue.isEmpty) return;
    _emit(_currentState.copyWith(position: position, isCompleted: false));
  }

  @override
  Future<void> stop() async {
    _emit(MobileAudioPlaybackState.empty());
  }

  @override
  Future<void> next() async {
    _selectRelative(1);
  }

  @override
  Future<void> previous() async {
    _selectRelative(-1);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _states.close();
  }

  void _selectRelative(int delta) {
    final queue = _currentState.queue;
    if (queue.isEmpty) {
      _emit(MobileAudioPlaybackState.empty());
      return;
    }

    final index = (_currentState.index + delta).clamp(0, queue.length - 1);
    final track = queue[index];
    _emit(
      MobileAudioPlaybackState(
        queue: queue,
        index: index,
        isPlaying: _currentState.isPlaying,
        duration: Duration(seconds: track.durationSeconds),
        audioUrl: _audioUrlForTrack?.call(track) ?? _currentState.audioUrl,
      ),
    );
  }

  void _emit(MobileAudioPlaybackState state) {
    if (_disposed) return;
    _currentState = state;
    _states.add(state);
  }
}

class NoopMobileAudioPlaybackService implements MobileAudioPlaybackService {
  NoopMobileAudioPlaybackService()
    : _states = StreamController<MobileAudioPlaybackState>.broadcast(
        sync: true,
      );

  final StreamController<MobileAudioPlaybackState> _states;
  final MobileAudioPlaybackState _currentState =
      MobileAudioPlaybackState.empty();
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
  }) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> next() async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _states.close();
  }
}
