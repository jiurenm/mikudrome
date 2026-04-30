import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../api/config.dart';
import '../models/track.dart';
import 'mobile_audio_playback.dart';

Future<MikudromeAudioHandler>? _audioServiceHandlerInit;

MobileAudioPlaybackService createMobileAudioPlaybackService() {
  return JustAudioMobileAudioPlaybackService.fromAudioService();
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
  final StreamController<MobileAudioPlaybackState> _mikudromeStates =
      StreamController<MobileAudioPlaybackState>.broadcast(sync: true);
  final List<StreamSubscription<Object?>> _subscriptions = [];
  List<Track> _tracks = const [];
  List<String> _audioUrls = const [];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isCompleted = false;
  bool _disposed = false;

  Stream<MobileAudioPlaybackState> get mikudromeState =>
      _mikudromeStates.stream;

  Future<void> setMikudromeQueue({
    required List<Track> tracks,
    required List<String> audioUrls,
    required int initialIndex,
    CoverUrlForTrack? coverUrlForTrack,
  }) async {
    if (_disposed) return;
    if (tracks.isEmpty) {
      _tracks = const [];
      _audioUrls = const [];
      queue.add(const []);
      mediaItem.add(null);
      await _player.stop();
      _publishPlaybackState(processingState: AudioProcessingState.idle);
      _emitMikudromeState(empty: true);
      return;
    }

    final nextTracks = List<Track>.unmodifiable(tracks);
    final nextAudioUrls = List<String>.unmodifiable(audioUrls);
    final clampedIndex = initialIndex.clamp(0, nextTracks.length - 1);
    final artHeaders = ApiConfig.defaultHeaders.isEmpty
        ? null
        : ApiConfig.defaultHeaders;
    final items = [
      for (var i = 0; i < nextTracks.length; i++)
        MediaItem(
          id: nextAudioUrls[i],
          title: nextTracks[i].title,
          artist: nextTracks[i].vocalLine,
          duration: Duration(seconds: nextTracks[i].durationSeconds),
          artUri: _artUriForTrack(nextTracks[i], coverUrlForTrack),
          artHeaders: artHeaders,
        ),
    ];

    await _player.setAudioSources(
      nextAudioUrls
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
    _tracks = nextTracks;
    _audioUrls = nextAudioUrls;
    queue.add(items);
    mediaItem.add(items[clampedIndex]);
    _position = Duration.zero;
    _duration = Duration(seconds: _tracks[clampedIndex].durationSeconds);
    _isCompleted = false;
    _publishPlaybackState();
    _emitMikudromeState(index: clampedIndex, isPlaying: _player.playing);
    await _startPlaybackSafely(clampedIndex);
  }

  Uri? _artUriForTrack(Track track, CoverUrlForTrack? coverUrlForTrack) {
    final coverUrl = coverUrlForTrack?.call(track).trim() ?? '';
    if (coverUrl.isEmpty) return null;
    return Uri.tryParse(coverUrl);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _position = position;
    _isCompleted = false;
    _publishPlaybackState();
    _emitMikudromeState(position: _position, isCompleted: false);
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> stop() async {
    await _player.stop();
    _tracks = const [];
    _audioUrls = const [];
    _position = Duration.zero;
    _duration = Duration.zero;
    _isCompleted = false;
    queue.add(const []);
    mediaItem.add(null);
    _publishPlaybackState(processingState: AudioProcessingState.idle);
    _emitMikudromeState(empty: true);
  }

  Future<void> _startPlaybackSafely(int index) async {
    try {
      await play();
      if (!_disposed) {
        _publishPlaybackState(isPlaying: true);
        _emitMikudromeState(index: index, isPlaying: true);
      }
    } catch (_) {
      if (!_disposed) {
        _emitMikudromeState(index: index, isPlaying: false);
      }
    }
  }

  void _handleCurrentIndexChanged(int? index) {
    if (index == null || _tracks.isEmpty || queue.value.isEmpty) return;
    final clampedIndex = index.clamp(0, queue.value.length - 1);
    _position = Duration.zero;
    _duration = Duration(seconds: _tracks[clampedIndex].durationSeconds);
    _isCompleted = false;
    mediaItem.add(queue.value[clampedIndex]);
    _publishPlaybackState();
    _emitMikudromeState(
      index: clampedIndex,
      position: _position,
      isCompleted: false,
    );
  }

  void _handlePlayingChanged(bool isPlaying) {
    if (_tracks.isEmpty) return;
    _publishPlaybackState(isPlaying: isPlaying);
    _emitMikudromeState(
      isPlaying: isPlaying,
      isCompleted: isPlaying ? false : null,
    );
  }

  void _handleProcessingStateChanged(ProcessingState state) {
    if (state == ProcessingState.completed && _tracks.isNotEmpty) {
      _isCompleted = true;
      _publishPlaybackState(
        isPlaying: false,
        processingState: AudioProcessingState.completed,
      );
      _emitMikudromeState(isPlaying: false, isCompleted: true);
    } else if (state == ProcessingState.ready ||
        state == ProcessingState.loading) {
      _publishPlaybackState(
        processingState: state == ProcessingState.loading
            ? AudioProcessingState.loading
            : AudioProcessingState.ready,
      );
      if (_isCompleted) {
        _isCompleted = false;
        _emitMikudromeState(isCompleted: false);
      }
    }
  }

  void _handlePositionChanged(Duration position) {
    if (_tracks.isEmpty) return;
    _position = position;
    _publishPlaybackState();
    _emitMikudromeState(position: position);
  }

  void _handleDurationChanged(Duration? duration) {
    if (_tracks.isEmpty) return;
    _duration =
        duration ??
        Duration(seconds: mediaItem.value?.duration?.inSeconds ?? 0);
    final currentItem = mediaItem.value;
    if (currentItem != null) {
      mediaItem.add(currentItem.copyWith(duration: _duration));
    }
    _publishPlaybackState();
    _emitMikudromeState(duration: _duration);
  }

  void _publishPlaybackState({
    bool? isPlaying,
    AudioProcessingState processingState = AudioProcessingState.ready,
  }) {
    if (_disposed) return;
    playbackState.add(
      PlaybackState(
        controls: const [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.pause,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: processingState,
        playing: isPlaying ?? _player.playing,
        updatePosition: _position,
      ),
    );
  }

  void _emitMikudromeState({
    int? index,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isCompleted,
    bool empty = false,
  }) {
    if (_disposed) return;
    if (empty || _tracks.isEmpty) {
      _mikudromeStates.add(MobileAudioPlaybackState.empty());
      return;
    }
    final effectiveIndex = (index ?? _player.currentIndex ?? 0).clamp(
      0,
      _tracks.length - 1,
    );
    final effectivePosition = position ?? _position;
    final effectiveDuration = duration ?? _duration;
    final effectiveCompleted = isCompleted ?? _isCompleted;
    _position = effectivePosition;
    _duration = effectiveDuration;
    _isCompleted = effectiveCompleted;
    _mikudromeStates.add(
      MobileAudioPlaybackState(
        queue: _tracks,
        index: effectiveIndex,
        isPlaying: isPlaying ?? _player.playing,
        position: effectivePosition,
        duration: effectiveDuration,
        isCompleted: effectiveCompleted,
        audioUrl: _audioUrls[effectiveIndex],
      ),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _mikudromeStates.close();
  }
}

class JustAudioMobileAudioPlaybackService
    implements MobileAudioPlaybackService {
  JustAudioMobileAudioPlaybackService.fromAudioService()
    : this(
        handlerLoader: () => _audioServiceHandlerInit ??= AudioService.init(
          builder: MikudromeAudioHandler.new,
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.miku39.mikudrome.playback',
            androidNotificationChannelName: 'Mikudrome playback',
            androidNotificationIcon: 'drawable/ic_notification',
            androidNotificationOngoing: true,
          ),
        ),
        usesAudioService: true,
      );

  JustAudioMobileAudioPlaybackService({
    MikudromeAudioHandler? handler,
    Future<MikudromeAudioHandler> Function()? handlerLoader,
    MobileAudioPlayerAdapter? player,
    this.usesAudioService = false,
  }) : _handler = handler,
       _handlerLoader = handlerLoader,
       _fallbackHandler = handler == null && handlerLoader == null
           ? MikudromeAudioHandler(player: player)
           : null,
       _states = StreamController<MobileAudioPlaybackState>.broadcast(
         sync: true,
       ) {
    final immediateHandler = _handler ?? _fallbackHandler;
    if (immediateHandler != null) {
      _bindHandler(immediateHandler);
    }
  }

  final MikudromeAudioHandler? _handler;
  final MikudromeAudioHandler? _fallbackHandler;
  final Future<MikudromeAudioHandler> Function()? _handlerLoader;
  final bool usesAudioService;
  final StreamController<MobileAudioPlaybackState> _states;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  MobileAudioPlaybackState _currentState = MobileAudioPlaybackState.empty();
  MikudromeAudioHandler? _boundHandler;
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
    CoverUrlForTrack? coverUrlForTrack,
  }) async {
    if (_disposed) return;

    final nextQueue = List<Track>.unmodifiable(queue);
    final nextAudioUrls = List<String>.unmodifiable(
      nextQueue.map(audioUrlForTrack),
    );
    final handler = await _effectiveHandler();
    await handler.setMikudromeQueue(
      tracks: nextQueue,
      audioUrls: nextAudioUrls,
      initialIndex: index,
      coverUrlForTrack: coverUrlForTrack,
    );
  }

  @override
  Future<void> play() async {
    if (_disposed || _currentState.queue.isEmpty) return;
    try {
      final handler = await _effectiveHandler();
      await handler.play();
    } catch (_) {
      if (!_disposed) {
        _emit(_currentState.copyWith(isPlaying: false));
      }
    }
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    final handler = await _effectiveHandler();
    await handler.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed) return;
    final handler = await _effectiveHandler();
    await handler.seek(position);
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    final handler = await _effectiveHandler();
    await handler.stop();
  }

  @override
  Future<void> next() async {
    if (_disposed || _currentState.queue.isEmpty) return;
    final handler = await _effectiveHandler();
    await handler.skipToNext();
  }

  @override
  Future<void> previous() async {
    if (_disposed || _currentState.queue.isEmpty) return;
    final handler = await _effectiveHandler();
    await handler.skipToPrevious();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await (_handler ?? _fallbackHandler ?? _boundHandler)?.dispose();
    await _states.close();
  }

  Future<MikudromeAudioHandler> _effectiveHandler() async {
    final immediateHandler = _handler ?? _fallbackHandler;
    if (immediateHandler != null) return immediateHandler;
    final existing = _boundHandler;
    if (existing != null) return existing;
    final handler = await _handlerLoader!();
    if (!_disposed) {
      _bindHandler(handler);
    }
    return handler;
  }

  void _bindHandler(MikudromeAudioHandler handler) {
    if (_boundHandler == handler) return;
    _boundHandler = handler;
    _subscriptions.add(handler.mikudromeState.listen(_emit));
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
