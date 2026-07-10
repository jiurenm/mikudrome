import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../api/config.dart';
import '../models/track.dart';
import 'mobile_audio_playback.dart';

const _toggleFavoriteAction = 'toggleFavorite';
const _favoriteIcon = 'drawable/ic_favorite';
const _favoriteBorderIcon = 'drawable/ic_favorite_border';
const _positionEmitInterval = Duration(seconds: 1);
const _maxPlaybackRecoveryAttempts = 3;
const _audioQualityQueryKey = 'quality';
const _lowQualityAudioValue = 'low';
const _mobileAudioLoadConfiguration = AudioLoadConfiguration(
  androidLoadControl: AndroidLoadControl(
    minBufferDuration: Duration(seconds: 30),
    maxBufferDuration: Duration(seconds: 90),
    bufferForPlaybackDuration: Duration(seconds: 2),
    bufferForPlaybackAfterRebufferDuration: Duration(seconds: 8),
    backBufferDuration: Duration(seconds: 10),
  ),
  darwinLoadControl: DarwinLoadControl(
    preferredForwardBufferDuration: Duration(seconds: 30),
  ),
);

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
  Stream<PlayerException> get errorStream;
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
  Future<void> setLoopMode(LoopMode loopMode);
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
    _subscriptions.add(_player.errorStream.listen(_handlePlaybackError));
  }

  final MobileAudioPlayerAdapter _player;
  final StreamController<MobileAudioPlaybackState> _mikudromeStates =
      StreamController<MobileAudioPlaybackState>.broadcast(sync: true);
  final List<StreamSubscription<Object?>> _subscriptions = [];
  List<Track> _tracks = const [];
  List<String> _audioUrls = const [];
  int? _currentIndex;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _lastEmittedPosition = Duration.zero;
  bool _isCompleted = false;
  bool _playbackRequested = false;
  bool _isRecoveringPlayback = false;
  int _playbackRecoveryAttempts = 0;
  MobilePlaybackOrderMode _orderMode = MobilePlaybackOrderMode.sequential;
  Duration? _lastPausedSeekPosition;
  TrackFavoriteStatus? _isTrackFavorited;
  TrackFavoriteToggle? _toggleTrackFavorite;
  bool _disposed = false;

  Stream<MobileAudioPlaybackState> get mikudromeState =>
      _mikudromeStates.stream;

  Future<void> setMikudromeQueue({
    required List<Track> tracks,
    required List<String> audioUrls,
    required int initialIndex,
    CoverUrlForTrack? coverUrlForTrack,
    MobilePlaybackOrderMode orderMode = MobilePlaybackOrderMode.sequential,
    Duration initialPosition = Duration.zero,
    TrackFavoriteStatus? isTrackFavorited,
    TrackFavoriteToggle? toggleTrackFavorite,
  }) async {
    if (_disposed) return;
    _orderMode = orderMode;
    _isTrackFavorited = isTrackFavorited;
    _toggleTrackFavorite = toggleTrackFavorite;
    if (tracks.isEmpty) {
      _tracks = const [];
      _audioUrls = const [];
      _currentIndex = null;
      _lastEmittedPosition = Duration.zero;
      _lastPausedSeekPosition = null;
      _isTrackFavorited = null;
      _toggleTrackFavorite = null;
      _playbackRequested = false;
      _playbackRecoveryAttempts = 0;
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
    final clampedPosition = _clampPositionForTrack(
      initialPosition,
      nextTracks[clampedIndex],
    );
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
      initialPosition: clampedPosition,
    );
    await _player.setLoopMode(_loopModeForOrderMode(_orderMode));
    _tracks = nextTracks;
    _audioUrls = nextAudioUrls;
    queue.add(items);
    mediaItem.add(items[clampedIndex]);
    _currentIndex = clampedIndex;
    _position = clampedPosition;
    _lastEmittedPosition = clampedPosition;
    _duration = Duration(seconds: _tracks[clampedIndex].durationSeconds);
    _isCompleted = false;
    _lastPausedSeekPosition = null;
    _playbackRecoveryAttempts = 0;
    _publishPlaybackState();
    _emitMikudromeState(
      index: clampedIndex,
      position: clampedPosition,
      isPlaying: _player.playing,
    );
    await _startPlaybackSafely(clampedIndex);
  }

  Future<void> setPlaybackOrderMode(MobilePlaybackOrderMode orderMode) async {
    if (_disposed) return;
    _orderMode = orderMode;
    await _player.setLoopMode(_loopModeForOrderMode(orderMode));
  }

  LoopMode _loopModeForOrderMode(MobilePlaybackOrderMode orderMode) {
    return switch (orderMode) {
      MobilePlaybackOrderMode.sequential => LoopMode.off,
      MobilePlaybackOrderMode.listLoop => LoopMode.all,
      MobilePlaybackOrderMode.singleLoop => LoopMode.one,
    };
  }

  Uri? _artUriForTrack(Track track, CoverUrlForTrack? coverUrlForTrack) {
    final coverUrl = coverUrlForTrack?.call(track).trim() ?? '';
    if (coverUrl.isEmpty) return null;
    return Uri.tryParse(coverUrl);
  }

  Duration _clampPositionForTrack(Duration position, Track track) {
    if (position <= Duration.zero) return Duration.zero;
    final duration = Duration(seconds: track.durationSeconds);
    if (duration <= Duration.zero || position <= duration) return position;
    return duration;
  }

  @override
  Future<void> play() async {
    if (_disposed) return;
    _lastPausedSeekPosition = null;
    _isCompleted = false;
    _playbackRequested = true;

    try {
      final playFuture = _player.play();
      if (_tracks.isNotEmpty) {
        _publishPlaybackState(isPlaying: true);
        _emitMikudromeState(isPlaying: true, isCompleted: false);
      }
      unawaited(
        playFuture.catchError((Object _) {
          if (!_disposed && _tracks.isNotEmpty) {
            _playbackRequested = false;
            _publishPlaybackState(isPlaying: false);
            _emitMikudromeState(isPlaying: false);
          }
        }),
      );
    } catch (_) {
      if (!_disposed && _tracks.isNotEmpty) {
        _playbackRequested = false;
        _publishPlaybackState(isPlaying: false);
        _emitMikudromeState(isPlaying: false);
      }
    }
  }

  @override
  Future<void> pause() async {
    if (_disposed || _tracks.isEmpty) {
      await _player.pause();
      return;
    }

    final previousPosition = _position;
    _lastPausedSeekPosition = _positionForPause();
    _position = _lastPausedSeekPosition!;
    _playbackRequested = false;
    _publishPlaybackState(isPlaying: false);
    _emitMikudromeState(isPlaying: false);

    try {
      await _player.pause();
    } catch (_) {
      if (!_disposed) {
        _lastPausedSeekPosition = null;
        _position = previousPosition;
        _publishPlaybackState(isPlaying: _player.playing);
        _emitMikudromeState(position: _position, isPlaying: _player.playing);
      }
      rethrow;
    }
  }

  @override
  Future<void> seek(Duration position) async {
    final wasPlaying = _effectiveIsPlaying;
    if (!wasPlaying) {
      _lastPausedSeekPosition = position;
      _position = position;
    }
    await _player.seek(position);
    _position = position;
    if (wasPlaying) {
      _lastPausedSeekPosition = null;
    }
    _isCompleted = false;
    _publishPlaybackState();
    _emitMikudromeState(position: _position, isCompleted: false);
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    if (name != _toggleFavoriteAction) {
      return super.customAction(name, extras);
    }
    final toggle = _toggleTrackFavorite;
    final track = _currentTrack;
    if (toggle == null || track == null) return null;
    try {
      await toggle(track);
    } finally {
      _publishPlaybackState();
    }
    return null;
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _tracks = const [];
    _audioUrls = const [];
    _currentIndex = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _isCompleted = false;
    _lastPausedSeekPosition = null;
    _playbackRequested = false;
    _playbackRecoveryAttempts = 0;
    _isTrackFavorited = null;
    _toggleTrackFavorite = null;
    queue.add(const []);
    mediaItem.add(null);
    _publishPlaybackState(processingState: AudioProcessingState.idle);
    _emitMikudromeState(empty: true);
  }

  @override
  Future<void> onTaskRemoved() => stop();

  Duration _positionForPause() {
    final playerPosition = _player.position;
    if (playerPosition > _position) {
      return playerPosition;
    }
    return _position;
  }

  Future<void> _startPlaybackSafely(int index) async {
    try {
      await play();
    } catch (_) {
      if (!_disposed) {
        _emitMikudromeState(index: index, isPlaying: false);
      }
    }
  }

  void _handleCurrentIndexChanged(int? index) {
    if (index == null || _tracks.isEmpty || queue.value.isEmpty) return;
    final clampedIndex = index.clamp(0, queue.value.length - 1);
    final didChangeTrack = _currentIndex != clampedIndex;
    _currentIndex = clampedIndex;
    mediaItem.add(queue.value[clampedIndex]);
    if (!didChangeTrack) {
      _publishPlaybackState(
        processingState:
            playbackState.value.processingState ==
                AudioProcessingState.buffering
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
      );
      _emitMikudromeState(index: clampedIndex);
      return;
    }
    _position = Duration.zero;
    _duration = Duration(seconds: _tracks[clampedIndex].durationSeconds);
    _isCompleted = false;
    _lastPausedSeekPosition = null;
    _publishPlaybackState();
    _emitMikudromeState(
      index: clampedIndex,
      position: _position,
      isCompleted: false,
    );
  }

  void _handlePlayingChanged(bool isPlaying) {
    if (_tracks.isEmpty) return;
    if (_lastPausedSeekPosition != null) {
      _publishPlaybackState(isPlaying: false);
      _emitMikudromeState(isPlaying: false, isCompleted: null);
      return;
    }
    if (isPlaying) {
      _lastPausedSeekPosition = null;
    }
    _publishPlaybackState(isPlaying: isPlaying);
    _emitMikudromeState(
      isPlaying: isPlaying,
      isCompleted: isPlaying ? false : null,
    );
  }

  void _handleProcessingStateChanged(ProcessingState state) {
    if (state == ProcessingState.completed && _tracks.isNotEmpty) {
      _isCompleted = true;
      _playbackRequested = false;
      _publishPlaybackState(
        isPlaying: false,
        processingState: AudioProcessingState.completed,
      );
      _emitMikudromeState(isPlaying: false, isCompleted: true);
    } else if (state == ProcessingState.buffering && _tracks.isNotEmpty) {
      _publishPlaybackState(
        isPlaying: _playbackRequested && _lastPausedSeekPosition == null,
        processingState: AudioProcessingState.buffering,
      );
      _emitMikudromeState(
        isPlaying: _playbackRequested && _lastPausedSeekPosition == null,
        isCompleted: false,
      );
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
    final pausedSeekPosition = _lastPausedSeekPosition;
    if (pausedSeekPosition != null) {
      _position = pausedSeekPosition;
      _publishPlaybackState(isPlaying: false);
      _emitMikudromeState(position: pausedSeekPosition, isPlaying: false);
      return;
    }
    _position = position;
    if (!_shouldEmitPosition(position)) {
      return;
    }
    _publishPlaybackState();
    _emitMikudromeState(position: position);
  }

  void _handlePlaybackError(PlayerException _) {
    if (_disposed ||
        _tracks.isEmpty ||
        !_playbackRequested ||
        _lastPausedSeekPosition != null ||
        _isCompleted ||
        _isRecoveringPlayback) {
      return;
    }

    if (_playbackRecoveryAttempts >= _maxPlaybackRecoveryAttempts) {
      _playbackRequested = false;
      _publishPlaybackState(isPlaying: false);
      _emitMikudromeState(isPlaying: false);
      return;
    }

    _playbackRecoveryAttempts += 1;
    final retryPosition = _positionForPause();
    _publishPlaybackState(
      isPlaying: true,
      processingState: AudioProcessingState.buffering,
    );
    _emitMikudromeState(position: retryPosition, isPlaying: true);
    unawaited(_recoverPlaybackAt(retryPosition));
  }

  Future<void> _recoverPlaybackAt(Duration position) async {
    _isRecoveringPlayback = true;
    try {
      await _switchCurrentTrackToLowQuality(position);
      await _player.seek(position);
      if (_disposed || !_playbackRequested || _tracks.isEmpty) return;
      await _player.play();
    } catch (_) {
      if (!_disposed && _tracks.isNotEmpty) {
        _playbackRequested = false;
        _publishPlaybackState(isPlaying: false);
        _emitMikudromeState(position: position, isPlaying: false);
      }
    } finally {
      _isRecoveringPlayback = false;
    }
  }

  Future<void> _switchCurrentTrackToLowQuality(
    Duration position, {
    bool resumePlayback = false,
  }) async {
    if (_disposed || _tracks.isEmpty || _audioUrls.isEmpty) return;
    final index = (_currentIndex ?? _player.currentIndex ?? 0).clamp(
      0,
      _audioUrls.length - 1,
    );
    final currentUrl = _audioUrls[index];
    final lowQualityUrl = _withLowQualityAudio(currentUrl);
    if (lowQualityUrl == currentUrl) return;

    final nextAudioUrls = List<String>.from(_audioUrls);
    nextAudioUrls[index] = lowQualityUrl;
    final nextQueue = List<MediaItem>.from(queue.value);
    if (index < nextQueue.length) {
      nextQueue[index] = nextQueue[index].copyWith(id: lowQualityUrl);
    }

    await _player.setAudioSources(
      nextAudioUrls
          .map(
            (url) => AudioSource.uri(
              Uri.parse(url),
              headers: ApiConfig.defaultHeaders,
            ),
          )
          .toList(growable: false),
      initialIndex: index,
      initialPosition: position,
    );
    if (_disposed || _tracks.isEmpty) return;
    _audioUrls = List<String>.unmodifiable(nextAudioUrls);
    queue.add(List<MediaItem>.unmodifiable(nextQueue));
    if (index < nextQueue.length) {
      mediaItem.add(nextQueue[index]);
    }
    _emitMikudromeState(index: index, position: position);
    if (resumePlayback && _playbackRequested) {
      await _player.play();
    }
  }

  String _withLowQualityAudio(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    if (uri.queryParameters[_audioQualityQueryKey] == _lowQualityAudioValue) {
      return url;
    }
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            _audioQualityQueryKey: _lowQualityAudioValue,
          },
        )
        .toString();
  }

  bool _shouldEmitPosition(Duration position) {
    if (position.inSeconds == _lastEmittedPosition.inSeconds) {
      return false;
    }
    final delta = position - _lastEmittedPosition;
    return !delta.isNegative || delta.abs() >= _positionEmitInterval;
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
    final playing = isPlaying ?? _effectiveIsPlaying;
    final updatePosition = _lastPausedSeekPosition ?? _position;
    playbackState.add(
      PlaybackState(
        controls: _mediaControlsForState(playing),
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processingState,
        playing: playing,
        updatePosition: updatePosition,
        speed: playing && processingState == AudioProcessingState.ready
            ? 1.0
            : 0.0,
        queueIndex: _playbackQueueIndex,
      ),
    );
  }

  List<MediaControl> _mediaControlsForState(bool playing) {
    return [
      MediaControl.skipToPrevious,
      playing ? MediaControl.pause : MediaControl.play,
      MediaControl.skipToNext,
      _favoriteControlForCurrentTrack(),
    ];
  }

  MediaControl _favoriteControlForCurrentTrack() {
    final track = _currentTrack;
    final isFavorite =
        track != null && (_isTrackFavorited?.call(track.id) ?? false);
    return MediaControl.custom(
      androidIcon: isFavorite ? _favoriteIcon : _favoriteBorderIcon,
      label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      name: _toggleFavoriteAction,
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
    final effectiveIndex = (index ?? _currentIndex ?? _player.currentIndex ?? 0)
        .clamp(0, _tracks.length - 1);
    _currentIndex = effectiveIndex;
    final effectivePosition = position ?? _position;
    final effectiveDuration = duration ?? _duration;
    final effectiveCompleted = isCompleted ?? _isCompleted;
    _position = effectivePosition;
    _duration = effectiveDuration;
    _isCompleted = effectiveCompleted;
    _lastEmittedPosition = effectivePosition;
    _mikudromeStates.add(
      MobileAudioPlaybackState(
        queue: _tracks,
        index: effectiveIndex,
        isPlaying: isPlaying ?? _effectiveIsPlaying,
        position: effectivePosition,
        duration: effectiveDuration,
        isCompleted: effectiveCompleted,
        audioUrl: _audioUrls[effectiveIndex],
      ),
    );
  }

  bool get _effectiveIsPlaying =>
      _lastPausedSeekPosition == null && _player.playing;

  int? get _playbackQueueIndex {
    if (_tracks.isEmpty) return null;
    final index = _currentIndex ?? _player.currentIndex;
    if (index == null || index < 0 || index >= _tracks.length) return null;
    return index;
  }

  Track? get _currentTrack {
    final index = _currentIndex;
    if (index == null || index < 0 || index >= _tracks.length) return null;
    return _tracks[index];
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
    MobilePlaybackOrderMode orderMode = MobilePlaybackOrderMode.sequential,
    Duration initialPosition = Duration.zero,
    TrackFavoriteStatus? isTrackFavorited,
    TrackFavoriteToggle? toggleTrackFavorite,
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
      orderMode: orderMode,
      initialPosition: initialPosition,
      isTrackFavorited: isTrackFavorited,
      toggleTrackFavorite: toggleTrackFavorite,
    );
  }

  @override
  Future<void> setPlaybackOrderMode(MobilePlaybackOrderMode orderMode) async {
    if (_disposed) return;
    final handler = await _effectiveHandler();
    await handler.setPlaybackOrderMode(orderMode);
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
    : _player =
          player ??
          AudioPlayer(audioLoadConfiguration: _mobileAudioLoadConfiguration);

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
  Stream<PlayerException> get errorStream => _player.errorStream;

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
  Future<void> setLoopMode(LoopMode loopMode) => _player.setLoopMode(loopMode);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
