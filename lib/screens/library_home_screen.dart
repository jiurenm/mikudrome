import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../api/api.dart';
import '../config/app_config_controller.dart';
import '../models/track.dart';
import '../models/video.dart';
import '../services/mobile_audio_playback.dart'
    hide createMobileAudioPlaybackService;
import '../services/mobile_audio_playback_service.dart';
import '../services/playback_storage.dart';
import '../theme/vocal_theme.dart';
import '../widgets/now_playing_bar.dart';
import '../widgets/player/pip_mini_player.dart';
import '../widgets/app_shell.dart';
import '../widgets/discover_screen.dart';
import '../widgets/mobile_app_shell.dart';
import 'album_detail_screen.dart';
import 'albums_screen.dart';
import 'player_screen.dart';
import 'producer_detail_screen.dart';
import 'mv_gallery_screen.dart';
import 'producers_screen.dart';
import 'vocalist_detail_screen.dart';
import 'vocalists_screen.dart';
import '../models/album.dart';
import '../models/producer.dart';
import '../models/vocalist.dart';
import '../utils/responsive.dart';
import '../widgets/mobile_player_sheet.dart';
import '../widgets/mobile_more_screen.dart';
import '../widgets/my_music_screen.dart';
import '../widgets/settings_screen.dart';
import '../services/playlist_repository.dart';
import '../services/web_audio_playback_controller.dart';
import 'playlists_screen.dart';
import 'playlist_detail_screen.dart';
import 'favorites_screen.dart';
import 'server_setup_screen.dart';

enum PlaybackMode { video, audio }

enum PlaybackOrderMode { sequential, listLoop, singleLoop }

@visibleForTesting
Future<void> routeMobileAudioPlaybackForMode({
  required bool isMobile,
  required PlaybackMode playbackMode,
  required MobileAudioPlaybackService service,
  required Future<void> Function() playAudioQueue,
}) async {
  if (!isMobile) return;
  if (playbackMode == PlaybackMode.audio) {
    await playAudioQueue();
    return;
  }
  await service.stop();
}

/// Root screen: app shell + route-based content. Album detail is shown in-shell (sidebar stays).
class LibraryHomeScreen extends StatefulWidget {
  const LibraryHomeScreen({super.key, this.appConfigController});

  final AppConfigController? appConfigController;

  @override
  State<LibraryHomeScreen> createState() => _LibraryHomeScreenState();
}

class _MobileNavigationSnapshot {
  const _MobileNavigationSnapshot({
    required this.tab,
    required this.route,
    required this.selectedAlbum,
    required this.selectedProducer,
    required this.selectedVocalist,
    required this.selectedPlaylistId,
    required this.showPlayer,
  });

  final MobileAppTab tab;
  final ShellRoute route;
  final Album? selectedAlbum;
  final Producer? selectedProducer;
  final Vocalist? selectedVocalist;
  final int? selectedPlaylistId;
  final bool showPlayer;
}

class _LibraryHomeScreenState extends State<LibraryHomeScreen> {
  static Future<void> _noopTogglePlayback() async {}

  static Future<void> _noopSeekToFraction(double _) async {}
  ShellRoute _route = ShellRoute.albums;
  Album? _selectedAlbum;
  Producer? _selectedProducer;
  Vocalist? _selectedVocalist;
  int? _selectedPlaylistId;
  MobileAppTab _mobileTab = MobileAppTab.discover;
  final List<_MobileNavigationSnapshot> _mobileHistory = [];
  List<Track> _playerQueue = const [];
  int _playerIndex = 0;
  bool _showPlayer = false;
  bool _isPlaying = false;
  double _playbackProgress = 0;
  String _elapsedLabel = '--:--';
  String _durationLabel = '--:--';
  String _playerContextLabel = 'Now Playing';
  PlaybackMode _playbackMode = PlaybackMode.audio;
  PlaybackOrderMode _playbackOrderMode = PlaybackOrderMode.sequential;
  PlayerTogglePlayback _playerTogglePlayback = _noopTogglePlayback;
  PlayerSeekToFraction _playerSeekToFraction = _noopSeekToFraction;
  late final WebAudioPlaybackController _webAudioPlaybackController;
  late final MobileAudioPlaybackService _mobileAudioPlaybackService;
  StreamSubscription<MobileAudioPlaybackState>? _mobileAudioSubscription;

  bool _restoredNotStarted = false;
  double? _resumeProgress;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _webAudioPlaybackController = WebAudioPlaybackController();
    _mobileAudioPlaybackService = createMobileAudioPlaybackService();
    _mobileAudioSubscription = _mobileAudioPlaybackService.states.listen(
      _handleMobileAudioState,
    );
    _restorePlaybackState();
    PlaylistRepository.instance.initialize(ApiClient());
  }

  @override
  void dispose() {
    unawaited(_mobileAudioSubscription?.cancel());
    unawaited(_mobileAudioPlaybackService.dispose());
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '--:--';
    final min = (totalSeconds ~/ 60) % 60;
    final sec = totalSeconds % 60;
    final hour = totalSeconds ~/ 3600;
    if (hour > 0) {
      return '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  void _restorePlaybackState() {
    final saved = PlaybackStorage.load();
    if (saved == null) return;
    final track =
        saved.queue.isNotEmpty &&
            saved.index >= 0 &&
            saved.index < saved.queue.length
        ? saved.queue[saved.index]
        : null;
    final elapsed = track != null
        ? (track.durationSeconds * saved.progress).round()
        : 0;
    setState(() {
      _playerQueue = saved.queue;
      _playerIndex = saved.index;
      _playbackProgress = saved.progress;
      _playbackMode = saved.mode;
      _playbackOrderMode = saved.orderMode;
      _playerContextLabel = saved.contextLabel;
      _isPlaying = false;
      _showPlayer = false;
      _restoredNotStarted = true;
      _resumeProgress = saved.progress;
      if (track != null) {
        _elapsedLabel = _formatDuration(elapsed);
        _durationLabel = _formatDuration(track.durationSeconds);
      }
    });
  }

  void _savePlaybackState() {
    if (_playerQueue.isEmpty) {
      PlaybackStorage.clear();
      return;
    }
    PlaybackStorage.save(
      queue: _playerQueue,
      index: _playerIndex,
      progress: _playbackProgress,
      mode: _playbackMode,
      orderMode: _playbackOrderMode,
      contextLabel: _playerContextLabel,
    );
  }

  Track? get _currentTrack {
    if (_playerQueue.isEmpty ||
        _playerIndex < 0 ||
        _playerIndex >= _playerQueue.length) {
      return null;
    }
    return _playerQueue[_playerIndex];
  }

  _MobileNavigationSnapshot _currentMobileSnapshot() {
    return _MobileNavigationSnapshot(
      tab: _mobileTab,
      route: _route,
      selectedAlbum: _selectedAlbum,
      selectedProducer: _selectedProducer,
      selectedVocalist: _selectedVocalist,
      selectedPlaylistId: _selectedPlaylistId,
      showPlayer: _showPlayer,
    );
  }

  void _restoreMobileSnapshot(_MobileNavigationSnapshot snapshot) {
    _mobileTab = snapshot.tab;
    _route = snapshot.route;
    _selectedAlbum = snapshot.selectedAlbum;
    _selectedProducer = snapshot.selectedProducer;
    _selectedVocalist = snapshot.selectedVocalist;
    _selectedPlaylistId = snapshot.selectedPlaylistId;
    _showPlayer = snapshot.showPlayer;
  }

  bool _isSameMobileSnapshot(
    _MobileNavigationSnapshot a,
    _MobileNavigationSnapshot b,
  ) {
    return a.tab == b.tab &&
        a.route == b.route &&
        a.selectedAlbum?.id == b.selectedAlbum?.id &&
        a.selectedProducer?.id == b.selectedProducer?.id &&
        a.selectedVocalist?.name == b.selectedVocalist?.name &&
        a.selectedPlaylistId == b.selectedPlaylistId &&
        a.showPlayer == b.showPlayer;
  }

  void _recordMobileHistory() {
    if (!isMobile(context)) return;
    final snapshot = _currentMobileSnapshot();
    if (_mobileHistory.isNotEmpty &&
        _isSameMobileSnapshot(_mobileHistory.last, snapshot)) {
      return;
    }
    _mobileHistory.add(snapshot);
  }

  void _handleMobileBack() {
    if (!isMobile(context)) return;
    if (_showPlayer) {
      setState(() {
        _showPlayer = false;
      });
      return;
    }
    if (_mobileHistory.isEmpty) return;
    setState(() {
      _restoreMobileSnapshot(_mobileHistory.removeLast());
    });
  }

  Widget _contentForRoute(ShellRoute route) {
    // On mobile, 'more' is the sentinel for the "More" tab
    if (isMobile(context) && route == ShellRoute.more) {
      return MobileMoreScreen(
        onNavigate: (r) {
          _recordMobileHistory();
          setState(() {
            _route = r;
          });
        },
      );
    }
    switch (route) {
      case ShellRoute.albums:
        return AlbumsScreen(
          onAlbumTap: (album) {
            _recordMobileHistory();
            setState(() {
              _selectedAlbum = album;
              _selectedProducer = null;
              _showPlayer = false;
            });
          },
        );
      case ShellRoute.producers:
        return ProducersScreen(
          onProducerTap: (producer) {
            _recordMobileHistory();
            setState(() {
              _selectedProducer = producer;
              _selectedAlbum = null;
              _showPlayer = false;
            });
          },
        );
      case ShellRoute.vocalists:
        return VocalistsScreen(
          onVocalistTap: (vocalist) {
            _recordMobileHistory();
            setState(() {
              _selectedVocalist = vocalist;
              _selectedAlbum = null;
              _selectedProducer = null;
              _showPlayer = false;
            });
          },
        );
      case ShellRoute.playlists:
        return PlaylistsScreen(
          onPlaylistTap: (playlistId) {
            _recordMobileHistory();
            setState(() {
              _selectedPlaylistId = playlistId;
              _showPlayer = false;
            });
          },
        );
      case ShellRoute.favorites:
        return FavoritesScreen(
          onBack: _mobileHistory.isNotEmpty ? _handleMobileBack : null,
          onPlayTrack: (track, queue, index) => _openPlayerForQueue(
            track: track,
            queue: queue,
            index: index,
            contextLabel: 'Favorites',
          ),
          currentPlayingTrackId: _currentTrack?.id,
          isPlaying: _isPlaying,
        );
      case ShellRoute.localMv:
        return MvGalleryScreen(onVideoTap: _playVideo);
      case ShellRoute.more:
        return MobileMoreScreen(
          onNavigate: (r) {
            _recordMobileHistory();
            setState(() {
              _route = r;
            });
          },
        );
    }
  }

  DiscoverSection _discoverSectionForRoute(ShellRoute route) {
    return switch (route) {
      ShellRoute.producers => DiscoverSection.producers,
      ShellRoute.vocalists => DiscoverSection.vocalists,
      ShellRoute.localMv => DiscoverSection.mv,
      _ => DiscoverSection.albums,
    };
  }

  ShellRoute _routeForDiscoverSection(DiscoverSection section) {
    return switch (section) {
      DiscoverSection.albums => ShellRoute.albums,
      DiscoverSection.producers => ShellRoute.producers,
      DiscoverSection.vocalists => ShellRoute.vocalists,
      DiscoverSection.mv => ShellRoute.localMv,
    };
  }

  void _clearSelection() {
    _selectedAlbum = null;
    _selectedProducer = null;
    _selectedVocalist = null;
    _selectedPlaylistId = null;
  }

  void _navigateMobileDiscover(DiscoverSection section) {
    final route = _routeForDiscoverSection(section);
    if (_mobileTab == MobileAppTab.discover &&
        _route == route &&
        _selectedAlbum == null &&
        _selectedProducer == null &&
        _selectedVocalist == null &&
        _selectedPlaylistId == null &&
        !_showPlayer) {
      return;
    }
    _recordMobileHistory();
    setState(() {
      _mobileTab = MobileAppTab.discover;
      _route = route;
      _clearSelection();
      _showPlayer = false;
    });
  }

  void _navigateMobileMyMusic(ShellRoute route) {
    if (_mobileTab == MobileAppTab.myMusic &&
        _route == route &&
        _selectedAlbum == null &&
        _selectedProducer == null &&
        _selectedVocalist == null &&
        _selectedPlaylistId == null &&
        !_showPlayer) {
      return;
    }
    _recordMobileHistory();
    setState(() {
      _mobileTab = MobileAppTab.myMusic;
      _route = route;
      _clearSelection();
      _showPlayer = false;
    });
  }

  void _selectMobileTab(MobileAppTab tab) {
    if (tab == _mobileTab) return;
    _recordMobileHistory();
    setState(() {
      _mobileTab = tab;
      if (tab == MobileAppTab.discover) {
        _route = ShellRoute.albums;
        _clearSelection();
      }
      _showPlayer = false;
    });
  }

  void _openMobileRescan() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'mobile-library-rescan'),
        builder: (routeContext) => Scaffold(
          appBar: AppBar(title: const Text('媒体库重扫')),
          body: SafeArea(
            child: MobileMoreScreen(
              onNavigate: (route) {
                Navigator.of(routeContext).pop();
                if (!mounted) return;
                _recordMobileHistory();
                setState(() {
                  _mobileTab = switch (route) {
                    ShellRoute.favorites ||
                    ShellRoute.playlists => MobileAppTab.myMusic,
                    _ => MobileAppTab.discover,
                  };
                  _route = route;
                  _clearSelection();
                  _showPlayer = false;
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  void _clearPlaybackForServerChange() {
    setState(() {
      _playerQueue = const [];
      _playerIndex = 0;
      _showPlayer = false;
      _isPlaying = false;
      _playbackProgress = 0;
      _elapsedLabel = '--:--';
      _durationLabel = '--:--';
      _playerContextLabel = 'Now Playing';
      _playbackMode = PlaybackMode.audio;
      _playbackOrderMode = PlaybackOrderMode.sequential;
      _playerTogglePlayback = _noopTogglePlayback;
      _playerSeekToFraction = _noopSeekToFraction;
      _restoredNotStarted = false;
      _resumeProgress = null;
      _videoController = null;
      _lastSavedProgress = 0;
    });
    PlaybackStorage.clear();
  }

  Future<void> _openServerSettings() async {
    final controller = widget.appConfigController;
    if (controller == null) return;

    var previousStatus = controller.state.status;
    var clearedForSave = false;
    late final VoidCallback listener;
    listener = () {
      final state = controller.state;
      if (!clearedForSave &&
          previousStatus == AppConfigStatus.loading &&
          state.status == AppConfigStatus.configured) {
        clearedForSave = true;
        _clearPlaybackForServerChange();
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
      previousStatus = state.status;
    };

    controller.addListener(listener);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ServerSetupScreen(controller: controller),
        ),
      );
    } finally {
      controller.removeListener(listener);
    }
  }

  PlaybackMode _defaultModeForTrack(Track track) =>
      track.hasVideo ? PlaybackMode.video : PlaybackMode.audio;

  bool get _canUseSharedWebAudio =>
      _playbackMode == PlaybackMode.audio &&
      !_canUseMobileAudioPlayback &&
      _webAudioPlaybackController.isAvailable;

  bool get _canUseMobileAudioPlayback {
    if (!mounted) return false;
    return isMobile(context) && _playbackMode == PlaybackMode.audio;
  }

  bool get _isMobilePlaybackSurface {
    if (!mounted) return false;
    return isMobile(context);
  }

  String _mobileAudioUrlForTrack(Track track) {
    return ApiClient().streamAudioUrl(track.id);
  }

  Future<void> _playMobileAudioQueue({
    required List<Track> queue,
    required int index,
  }) {
    return _mobileAudioPlaybackService.playQueue(
      queue: queue,
      index: index,
      audioUrlForTrack: _mobileAudioUrlForTrack,
    );
  }

  Future<void> _routeMobileAudioPlaybackForCurrentMode() {
    return routeMobileAudioPlaybackForMode(
      isMobile: _isMobilePlaybackSurface,
      playbackMode: _playbackMode,
      service: _mobileAudioPlaybackService,
      playAudioQueue: () =>
          _playMobileAudioQueue(queue: _playerQueue, index: _playerIndex),
    );
  }

  void _handleMobileAudioState(MobileAudioPlaybackState state) {
    if (!mounted || !isMobile(context) || _playbackMode != PlaybackMode.audio) {
      return;
    }

    final previousTrackId = _currentTrack?.id;
    final track = state.track;
    final effectiveDuration = state.duration > Duration.zero
        ? state.duration
        : Duration(seconds: track?.durationSeconds ?? 0);
    final effectivePosition =
        effectiveDuration > Duration.zero && state.position > effectiveDuration
        ? effectiveDuration
        : state.position;
    var shouldSavePlaybackState = previousTrackId != track?.id;
    setState(() {
      _playerQueue = state.queue;
      _playerIndex = state.queue.isEmpty
          ? 0
          : state.index.clamp(0, state.queue.length - 1);
      _isPlaying = state.isPlaying;
      if (track == null) {
        _playbackProgress = 0;
        _elapsedLabel = '--:--';
        _durationLabel = '--:--';
        return;
      }
      if (previousTrackId != track.id) {
        _playbackProgress = 0;
        _elapsedLabel = '00:00';
      }
      if (effectiveDuration > Duration.zero) {
        _playbackProgress =
            effectivePosition.inMilliseconds / effectiveDuration.inMilliseconds;
        _elapsedLabel = _formatDuration(effectivePosition.inSeconds);
        _durationLabel = _formatDuration(effectiveDuration.inSeconds);
        shouldSavePlaybackState =
            shouldSavePlaybackState ||
            (_playbackProgress - _lastSavedProgress).abs() > 0.05 ||
            !state.isPlaying ||
            state.isCompleted;
      } else {
        _playbackProgress = 0;
        _elapsedLabel = '--:--';
        _durationLabel = '--:--';
        shouldSavePlaybackState =
            shouldSavePlaybackState || !state.isPlaying || state.isCompleted;
      }
    });
    if (shouldSavePlaybackState) {
      _lastSavedProgress = _playbackProgress;
      _savePlaybackState();
    }
    if (state.isCompleted) {
      unawaited(_handleMobileAudioCompletion());
    }
  }

  Future<void> _handleMobileAudioCompletion() async {
    if (!mounted || _playerQueue.isEmpty) return;
    if (_playbackOrderMode == PlaybackOrderMode.singleLoop) {
      await _playMobileAudioQueue(queue: _playerQueue, index: _playerIndex);
      return;
    }
    if (_playerIndex < _playerQueue.length - 1) {
      _playNext();
      return;
    }
    if (_playbackOrderMode == PlaybackOrderMode.listLoop) {
      if (_playerQueue.length > 1) {
        _playNext();
      } else {
        await _playMobileAudioQueue(queue: _playerQueue, index: _playerIndex);
      }
    }
  }

  Future<void> _activateSharedWebAudioTrack(
    Track track, {
    double? progress,
    bool autoplay = true,
  }) async {
    if (!_webAudioPlaybackController.isAvailable) {
      return;
    }
    final initialPosition =
        progress != null && progress > 0 && track.durationSeconds > 0
        ? Duration(
            milliseconds: (track.durationSeconds * 1000 * progress).round(),
          )
        : Duration.zero;
    await _webAudioPlaybackController.activateTrack(
      track: track,
      url: ApiClient().streamAudioUrl(track.id),
      initialPosition: initialPosition,
      autoplay: autoplay,
    );
  }

  PlaybackMode _nextModeForTrack(Track track) {
    if (_playbackMode == PlaybackMode.video && !track.hasVideo) {
      return PlaybackMode.audio;
    }
    return track.hasVideo ? _playbackMode : PlaybackMode.audio;
  }

  void _openPlayerForQueue({
    required Track track,
    required List<Track> queue,
    required int index,
    required String contextLabel,
  }) {
    if (queue.isEmpty) return;
    final selectedTrack = queue[index.clamp(0, queue.length - 1)];
    setState(() {
      _playerQueue = List<Track>.from(queue);
      _playerIndex = index.clamp(0, queue.length - 1);
      _playerContextLabel = contextLabel;
      _playbackMode = _defaultModeForTrack(selectedTrack);
      _showPlayer = true;
      _isPlaying = true;
      _restoredNotStarted = false;
      _resumeProgress = null;
    });
    _savePlaybackState();
    if (_isMobilePlaybackSurface) {
      unawaited(_routeMobileAudioPlaybackForCurrentMode());
    } else if (_playbackMode == PlaybackMode.audio) {
      unawaited(_activateSharedWebAudioTrack(selectedTrack));
    }
  }

  void _selectPlayerTrack(int index, {bool showPlayer = true}) {
    if (index < 0 || index >= _playerQueue.length) return;
    final nextTrack = _playerQueue[index];
    setState(() {
      _playerIndex = index;
      _playbackMode = _nextModeForTrack(nextTrack);
      _showPlayer = showPlayer;
      _isPlaying = true;
    });
    _savePlaybackState();
    if (_isMobilePlaybackSurface) {
      unawaited(_routeMobileAudioPlaybackForCurrentMode());
    } else if (_canUseSharedWebAudio) {
      unawaited(_activateSharedWebAudioTrack(nextTrack));
    }
  }

  void _cyclePlaybackOrderMode() {
    setState(() {
      _playbackOrderMode = switch (_playbackOrderMode) {
        PlaybackOrderMode.sequential => PlaybackOrderMode.listLoop,
        PlaybackOrderMode.listLoop => PlaybackOrderMode.singleLoop,
        PlaybackOrderMode.singleLoop => PlaybackOrderMode.sequential,
      };
    });
    _savePlaybackState();
  }

  void _playPrevious() {
    if (_playerQueue.isEmpty) return;
    final nextIndex = switch (_playbackOrderMode) {
      PlaybackOrderMode.listLoop =>
        _playerIndex > 0
            ? _playerIndex - 1
            : (_playerQueue.length > 1 ? _playerQueue.length - 1 : null),
      PlaybackOrderMode.sequential || PlaybackOrderMode.singleLoop =>
        _playerIndex > 0 ? _playerIndex - 1 : null,
    };
    if (nextIndex == null) return;
    final nextTrack = _playerQueue[nextIndex];
    setState(() {
      _playerIndex = nextIndex;
      _playbackMode = _nextModeForTrack(nextTrack);
      _isPlaying = true;
    });
    _savePlaybackState();
    if (_isMobilePlaybackSurface) {
      unawaited(_routeMobileAudioPlaybackForCurrentMode());
    } else if (_canUseSharedWebAudio) {
      unawaited(_activateSharedWebAudioTrack(nextTrack));
    }
  }

  void _playNext() {
    if (_playerQueue.isEmpty) return;
    final nextIndex = switch (_playbackOrderMode) {
      PlaybackOrderMode.listLoop =>
        _playerIndex < _playerQueue.length - 1
            ? _playerIndex + 1
            : (_playerQueue.length > 1 ? 0 : null),
      PlaybackOrderMode.sequential || PlaybackOrderMode.singleLoop =>
        _playerIndex < _playerQueue.length - 1 ? _playerIndex + 1 : null,
    };
    if (nextIndex == null) return;
    final nextTrack = _playerQueue[nextIndex];
    setState(() {
      _playerIndex = nextIndex;
      _playbackMode = _nextModeForTrack(nextTrack);
      _isPlaying = true;
    });
    _savePlaybackState();
    if (_isMobilePlaybackSurface) {
      unawaited(_routeMobileAudioPlaybackForCurrentMode());
    } else if (_canUseSharedWebAudio) {
      unawaited(_activateSharedWebAudioTrack(nextTrack));
    }
  }

  Future<void> _togglePlayback() async {
    if (_currentTrack == null) return;
    if (_canUseMobileAudioPlayback) {
      if (_restoredNotStarted) {
        setState(() {
          _restoredNotStarted = false;
          _isPlaying = true;
        });
        await _playMobileAudioQueue(queue: _playerQueue, index: _playerIndex);
        return;
      }
      if (_isPlaying) {
        await _mobileAudioPlaybackService.pause();
      } else {
        await _mobileAudioPlaybackService.play();
      }
      return;
    }
    if (_restoredNotStarted) {
      // First play after restore — mount the PlayerScreen
      setState(() {
        _restoredNotStarted = false;
        _isPlaying = true;
      });
      return;
    }
    await _playerTogglePlayback();
  }

  Future<void> _seekPlayback(double value) async {
    if (_currentTrack == null) return;
    if (_canUseMobileAudioPlayback) {
      await _seekMobileAudioPlayback(value);
      return;
    }
    await _playerSeekToFraction(value);
  }

  Future<void> _seekMobileAudioPlayback(double value) async {
    final track = _currentTrack;
    if (track == null) return;
    final progress = value.clamp(0.0, 1.0).toDouble();
    final duration = Duration(seconds: track.durationSeconds);
    final target = duration * progress;
    await _mobileAudioPlaybackService.seek(target);
    if (!mounted) return;
    setState(() {
      _playbackProgress = progress;
      _elapsedLabel = _formatDuration(target.inSeconds);
      _durationLabel = _formatDuration(track.durationSeconds);
    });
    _savePlaybackState();
  }

  void _switchPlaybackMode(PlaybackMode mode) {
    final currentTrack = _currentTrack;
    if (currentTrack == null) return;
    if (mode == PlaybackMode.video && !currentTrack.hasVideo) return;
    setState(() {
      _playbackMode = mode;
      _isPlaying = true;
    });
    if (_isMobilePlaybackSurface) {
      unawaited(_routeMobileAudioPlaybackForCurrentMode());
    } else if (mode == PlaybackMode.audio &&
        _webAudioPlaybackController.isAvailable) {
      unawaited(
        _activateSharedWebAudioTrack(currentTrack, progress: _playbackProgress),
      );
    }
  }

  void _openCurrentPlayer() {
    if (_currentTrack == null) return;
    setState(() {
      _restoredNotStarted = false;
      _showPlayer = true;
    });
  }

  void _closePlayer() {
    setState(() {
      _showPlayer = false;
    });
  }

  double _lastSavedProgress = 0;

  void _updatePlaybackUi({
    required bool isPlaying,
    required double progress,
    required String elapsedLabel,
    required String durationLabel,
  }) {
    if (!mounted) return;
    setState(() {
      _isPlaying = isPlaying;
      _playbackProgress = progress;
      _elapsedLabel = elapsedLabel;
      _durationLabel = durationLabel;
    });
    // Throttle localStorage writes: save every ~5% progress change
    if ((progress - _lastSavedProgress).abs() > 0.05 || !isPlaying) {
      _lastSavedProgress = progress;
      _savePlaybackState();
    }
  }

  void _registerPlayerControls({
    required PlayerTogglePlayback togglePlayback,
    required PlayerSeekToFraction seekToFraction,
  }) {
    _playerTogglePlayback = togglePlayback;
    _playerSeekToFraction = seekToFraction;
  }

  void _onVideoControllerChanged(VideoPlayerController? c) {
    if (!mounted) return;
    setState(() => _videoController = c);
  }

  String _albumContextLabel(Album album) => 'Album / ${album.title}';
  String _producerContextLabel(Producer producer) =>
      'Producer / ${producer.name}';
  String _mvContextLabel(Producer producer) =>
      'Featured MVs / ${producer.name}';
  String _vocalistContextLabel(Vocalist vocalist) =>
      'Vocalist / ${vocalist.name}';

  Future<void> _playVideo(Video video) async {
    final api = ApiClient();
    if (video.hasTrack) {
      // Track-associated MV: fetch the real Track and play it
      final track = await api.getTrack(video.trackId!);
      if (track == null) return;
      _openPlayerForQueue(
        track: track,
        queue: [track],
        index: 0,
        contextLabel: 'MV Gallery / ${video.artist}',
      );
    } else {
      // Standalone MV: create a synthetic Track with video stream override.
      // Parse "Title - Artist feat. Vocal" from filename-based title.
      var title = video.title;
      var composer = video.composer;
      var vocal = video.vocal;
      var artist = video.artist;

      if (composer.isEmpty && vocal.isEmpty) {
        final dashMatch = RegExp(r'^(.+?)\s*[-–—]\s*(.+)$').firstMatch(title);
        if (dashMatch != null) {
          title = dashMatch.group(1)!.trim();
          final creditsPart = dashMatch.group(2)!.trim();
          final featMatch = RegExp(
            r'^(.+?)\s+feat\.?\s+(.+)$',
            caseSensitive: false,
          ).firstMatch(creditsPart);
          if (featMatch != null) {
            composer = featMatch.group(1)!.trim();
            vocal = featMatch.group(2)!.trim();
          } else {
            composer = creditsPart;
          }
          if (artist.isEmpty) {
            artist = composer;
            if (vocal.isNotEmpty) artist += '; $vocal';
          }
        }
      }

      final syntheticTrack = Track(
        id: -video.id, // negative to avoid collision with real tracks
        title: title,
        audioPath: '',
        videoPath: 'standalone', // non-empty so hasVideo == true
        videoThumbPath: video.thumbPath,
        durationSeconds: video.durationSeconds,
        artists: artist,
        composer: composer,
        vocal: vocal,
        videoStreamOverrideUrl: api.videoStreamUrl(video.id),
        coverOverrideUrl: api.videoThumbUrl(video.id),
      );
      _openPlayerForQueue(
        track: syntheticTrack,
        queue: [syntheticTrack],
        index: 0,
        contextLabel:
            'MV Gallery / ${composer.isNotEmpty ? composer : video.title}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack = _currentTrack;
    final mobile = isMobile(context);

    Widget mainContent;
    if (_selectedAlbum != null) {
      mainContent = AlbumDetailScreen(
        album: _selectedAlbum!,
        onBack: mobile && _mobileHistory.isNotEmpty ? _handleMobileBack : null,
        onProducerTap: (producer) {
          _recordMobileHistory();
          setState(() {
            _selectedProducer = producer;
            _selectedAlbum = null;
            _route = ShellRoute.producers;
            _showPlayer = false;
          });
        },
        onPlayTrack: (track, queue, index) => _openPlayerForQueue(
          track: track,
          queue: queue,
          index: index,
          contextLabel: _albumContextLabel(_selectedAlbum!),
        ),
        currentPlayingTrackId: _currentTrack?.id,
        isPlaying: _isPlaying,
      );
    } else if (_selectedProducer != null) {
      mainContent = ProducerDetailScreen(
        producer: _selectedProducer!,
        onBack: mobile && _mobileHistory.isNotEmpty ? _handleMobileBack : null,
        onAlbumTap: (album) {
          _recordMobileHistory();
          setState(() {
            _selectedAlbum = album;
            _selectedProducer = null;
            _route = ShellRoute.albums;
            _showPlayer = false;
          });
        },
        onPlayTrack: (track, queue, index) => _openPlayerForQueue(
          track: track,
          queue: queue,
          index: index,
          contextLabel: queue.every((item) => item.hasVideo)
              ? _mvContextLabel(_selectedProducer!)
              : _producerContextLabel(_selectedProducer!),
        ),
      );
    } else if (_selectedVocalist != null) {
      mainContent = VocalistDetailScreen(
        vocalist: _selectedVocalist!,
        onBack: mobile && _mobileHistory.isNotEmpty ? _handleMobileBack : null,
        onAlbumTap: (album) {
          _recordMobileHistory();
          setState(() {
            _selectedAlbum = album;
            _selectedVocalist = null;
            _route = ShellRoute.albums;
            _showPlayer = false;
          });
        },
        onPlayTrack: (track, queue, index) => _openPlayerForQueue(
          track: track,
          queue: queue,
          index: index,
          contextLabel: _vocalistContextLabel(_selectedVocalist!),
        ),
      );
    } else if (_selectedPlaylistId != null) {
      mainContent = PlaylistDetailScreen(
        playlistId: _selectedPlaylistId!,
        onBack: mobile && _mobileHistory.isNotEmpty ? _handleMobileBack : null,
        onPlayTrack: (track, queue, index) => _openPlayerForQueue(
          track: track,
          queue: queue,
          index: index,
          contextLabel: 'Playlist',
        ),
        currentPlayingTrackId: _currentTrack?.id,
        isPlaying: _isPlaying,
      );
    } else {
      mainContent = _contentForRoute(_route);
    }

    // --- Branch: Mobile vs Desktop ---
    if (mobile) {
      // Mobile: three-tab shell + MobilePlayerSheet overlay.
      final bottomPadding = MediaQuery.of(context).padding.bottom + 56;

      final showMyMusicContent =
          _route == ShellRoute.favorites || _route == ShellRoute.playlists;
      final appShell = MobileAppShell(
        currentTab: _mobileTab,
        onTabChanged: _selectMobileTab,
        discover: DiscoverScreen(
          currentSection: _discoverSectionForRoute(_route),
          onSectionChanged: _navigateMobileDiscover,
          child: mainContent,
        ),
        myMusic: showMyMusicContent
            ? mainContent
            : MyMusicScreen(
                onNavigate: _navigateMobileMyMusic,
                onQueue: _openCurrentPlayer,
              ),
        settings: SettingsScreen(
          serverUrl: ApiConfig.defaultBaseUrl,
          onEditServer: _openServerSettings,
          onRescan: _openMobileRescan,
        ),
      );

      return PopScope(
        canPop: _mobileHistory.isEmpty && !_showPlayer,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleMobileBack();
        },
        child: VocalThemeProvider(
          track: currentTrack,
          child: Stack(
            children: [
              appShell,
              if (currentTrack != null && !_restoredNotStarted)
                MobilePlayerSheet(
                  track: currentTrack,
                  coverUrl: ApiClient(
                    baseUrl: ApiConfig.defaultBaseUrl,
                  ).albumCoverUrl(currentTrack.albumId.toString()),
                  isPlaying: _isPlaying,
                  progress: _playbackProgress,
                  onPlayPause: _togglePlayback,
                  bottomPadding: bottomPadding,
                  expanded: _showPlayer,
                  onExpandedChanged: (expanded) => setState(() {
                    _showPlayer = expanded;
                  }),
                  playerBuilder: (onClose) => PlayerScreen(
                    track: currentTrack,
                    queue: _playerQueue,
                    currentIndex: _playerIndex,
                    contextLabel: _playerContextLabel,
                    playbackMode: _playbackMode,
                    onSelectTrack: (index) => _selectPlayerTrack(index),
                    onPrevious: _playPrevious,
                    onNext: _playNext,
                    onClose: onClose,
                    onSwitchPlaybackMode: _switchPlaybackMode,
                    playbackOrderMode: _playbackOrderMode,
                    onCyclePlaybackOrderMode: _cyclePlaybackOrderMode,
                    onPlaybackStateChanged: _updatePlaybackUi,
                    onControlsReady:
                        ({required togglePlayback, required seekToFraction}) {
                          _registerPlayerControls(
                            togglePlayback: togglePlayback,
                            seekToFraction: seekToFraction,
                          );
                          _resumeProgress = null;
                        },
                    initialProgress: _resumeProgress,
                    onVideoControllerChanged: _onVideoControllerChanged,
                    renderVideo: true,
                    useExternalAudioPlayback:
                        _playbackMode == PlaybackMode.audio,
                    externalIsPlaying: _isPlaying,
                    externalProgress: _playbackProgress,
                    onExternalPlay: _mobileAudioPlaybackService.play,
                    onExternalPause: _mobileAudioPlaybackService.pause,
                    onExternalSeekToFraction: _seekMobileAudioPlayback,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // --- Desktop: EXISTING layout (unchanged) ---
    final content = Stack(
      fit: StackFit.expand,
      children: [
        mainContent,
        if (currentTrack != null && !_restoredNotStarted)
          Offstage(
            offstage: !_showPlayer,
            child: PlayerScreen(
              track: currentTrack,
              queue: _playerQueue,
              currentIndex: _playerIndex,
              contextLabel: _playerContextLabel,
              playbackMode: _playbackMode,
              onSelectTrack: (index) => _selectPlayerTrack(index),
              onPrevious: _playPrevious,
              onNext: _playNext,
              onClose: _closePlayer,
              onSwitchPlaybackMode: _switchPlaybackMode,
              playbackOrderMode: _playbackOrderMode,
              onCyclePlaybackOrderMode: _cyclePlaybackOrderMode,
              onPlaybackStateChanged: _updatePlaybackUi,
              onControlsReady:
                  ({required togglePlayback, required seekToFraction}) {
                    _registerPlayerControls(
                      togglePlayback: togglePlayback,
                      seekToFraction: seekToFraction,
                    );
                    _resumeProgress = null;
                  },
              initialProgress: _resumeProgress,
              onVideoControllerChanged: _onVideoControllerChanged,
              renderVideo: _showPlayer,
            ),
          ),
        if (!_showPlayer &&
            _playbackMode == PlaybackMode.video &&
            _videoController != null &&
            !_restoredNotStarted &&
            currentTrack != null)
          PipMiniPlayer(
            controller: _videoController!,
            track: currentTrack,
            isPlaying: _isPlaying,
            onTap: _openCurrentPlayer,
            onTogglePlay: _togglePlayback,
            onClose: () => _switchPlaybackMode(PlaybackMode.audio),
          ),
      ],
    );

    return VocalThemeProvider(
      track: currentTrack,
      child: AppShell(
        currentRoute: _route,
        forceSidebarCollapsed: _showPlayer,
        onNavigate: (r) => setState(() {
          _route = r;
          _selectedAlbum = null;
          _selectedProducer = null;
          _selectedVocalist = null;
          _selectedPlaylistId = null;
          _showPlayer = false;
        }),
        nowPlayingBar: _showPlayer
            ? const SizedBox.shrink()
            : NowPlayingBar(
                track: currentTrack,
                queue: _playerQueue,
                currentIndex: _playerIndex,
                isPlaying: _isPlaying,
                progress: _playbackProgress,
                elapsedLabel: _elapsedLabel,
                durationLabel: _durationLabel,
                playbackMode: _playbackMode,
                onTogglePlay: _togglePlayback,
                onSeekProgress: _seekPlayback,
                onPrevious: _playPrevious,
                onNext: _playNext,
                onOpenPlayer: _openCurrentPlayer,
                onSelectQueueTrack: (index) =>
                    _selectPlayerTrack(index, showPlayer: false),
              ),
        child: content,
      ),
    );
  }
}
