import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

import '../api/api.dart';
import '../config/app_config_controller.dart';
import '../models/playback_modes.dart';
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
import 'daily_recommendations_screen.dart';
import 'player_screen.dart';
import 'producer_detail_screen.dart';
import 'mv_gallery_screen.dart';
import 'producers_screen.dart';
import 'recent_playback_screen.dart';
import 'vocalist_detail_screen.dart';
import 'vocalists_screen.dart';
import 'player_playback_policy.dart';
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

export '../models/playback_modes.dart';

@visibleForTesting
PlaybackMode defaultPlaybackModeForTrack(
  Track track, {
  required bool isMobileSurface,
}) {
  if (isMobileSurface) {
    return PlaybackMode.audio;
  }
  return track.hasVideo ? PlaybackMode.video : PlaybackMode.audio;
}

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

@visibleForTesting
Future<void> pauseMobileAudioPlaybackForLifecycle({
  required AppLifecycleState lifecycleState,
  required bool isMobile,
  required PlaybackMode playbackMode,
  required MobileAudioPlaybackService service,
}) async {
  return;
}

/// Root screen: app shell + route-based content. Album detail is shown in-shell (sidebar stays).
class LibraryHomeScreen extends StatefulWidget {
  const LibraryHomeScreen({
    super.key,
    this.appConfigController,
    this.mobileAudioPlaybackService,
  });

  final AppConfigController? appConfigController;
  final MobileAudioPlaybackService? mobileAudioPlaybackService;

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
    required this.showDiscoverHome,
  });

  final MobileAppTab tab;
  final ShellRoute route;
  final Album? selectedAlbum;
  final Producer? selectedProducer;
  final Vocalist? selectedVocalist;
  final int? selectedPlaylistId;
  final bool showPlayer;
  final bool showDiscoverHome;
}

class _LibraryHomeScreenState extends State<LibraryHomeScreen>
    with WidgetsBindingObserver {
  static Future<void> _noopTogglePlayback() async {}

  static Future<void> _noopSeekToFraction(double _) async {}
  ShellRoute _route = ShellRoute.albums;
  Album? _selectedAlbum;
  Producer? _selectedProducer;
  Vocalist? _selectedVocalist;
  int? _selectedPlaylistId;
  MobileAppTab _mobileTab = MobileAppTab.discover;
  final List<_MobileNavigationSnapshot> _mobileHistory = [];
  bool _showMobileDiscoverHome = true;
  List<Track> _playerQueue = const [];
  List<Track>? _orderedPlayerQueue;
  int _playerIndex = 0;
  bool _shuffleEnabled = false;
  bool _showPlayer = false;
  bool _preferVideoOnExpand = false;
  bool _isPlaying = false;
  double _playbackProgress = 0;
  String _elapsedLabel = '--:--';
  String _durationLabel = '--:--';
  String _playerContextLabel = 'Now Playing';
  PlaybackMode _playbackMode = PlaybackMode.audio;
  PlaybackOrderMode _playbackOrderMode = PlaybackOrderMode.sequential;
  PlayerTogglePlayback _playerTogglePlayback = _noopTogglePlayback;
  PlayerSeekToFraction _playerSeekToFraction = _noopSeekToFraction;
  final PlaybackUiUpdateGate _playbackUiUpdateGate = PlaybackUiUpdateGate();
  late final WebAudioPlaybackController _webAudioPlaybackController;
  late final MobileAudioPlaybackService _mobileAudioPlaybackService;
  late final bool _ownsMobileAudioPlaybackService;
  StreamSubscription<MobileAudioPlaybackState>? _mobileAudioSubscription;

  bool _restoredNotStarted = false;
  double? _resumeProgress;
  VideoPlayerController? _videoController;
  int _mobileVideoCollapseRequest = 0;
  int? _pendingMobileVideoCollapseAudioRequest;
  Track? _pendingMobileVideoCollapseAudioTrack;
  int? _pendingMobileVideoCollapseAudioIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _webAudioPlaybackController = WebAudioPlaybackController();
    final injectedMobileAudioService = widget.mobileAudioPlaybackService;
    _ownsMobileAudioPlaybackService = injectedMobileAudioService == null;
    _mobileAudioPlaybackService =
        injectedMobileAudioService ?? createMobileAudioPlaybackService();
    _mobileAudioSubscription = _mobileAudioPlaybackService.states.listen(
      _handleMobileAudioState,
    );
    _restorePlaybackState();
    PlaylistRepository.instance.initialize(ApiClient());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_mobileAudioSubscription?.cancel());
    if (_ownsMobileAudioPlaybackService) {
      unawaited(_mobileAudioPlaybackService.dispose());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(
      pauseMobileAudioPlaybackForLifecycle(
        lifecycleState: state,
        isMobile: _isMobilePlaybackSurface,
        playbackMode: _playbackMode,
        service: _mobileAudioPlaybackService,
      ),
    );
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
    _savePlaybackHistoryToCloud();
  }

  void _savePlaybackHistoryToCloud() {
    final track = _currentTrack;
    if (track == null || track.id <= 0) return;
    final durationMs = max(0, track.durationSeconds * 1000);
    final positionMs = durationMs == 0
        ? 0
        : (durationMs * _playbackProgress.clamp(0.0, 1.0)).round();
    unawaited(
      ApiClient()
          .savePlaybackHistory(
            trackId: track.id,
            positionMs: positionMs,
            durationMs: durationMs,
            mode: _playbackMode,
            contextLabel: _playerContextLabel,
          )
          .catchError((_) {}),
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

  String _coverUrlForTrack(Track track) {
    return track.coverOverrideUrl ??
        (track.albumId > 0
            ? ApiClient(
                baseUrl: ApiConfig.defaultBaseUrl,
              ).albumCoverUrl(track.albumId.toString())
            : '');
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
      showDiscoverHome: _showMobileDiscoverHome,
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
    _showMobileDiscoverHome = snapshot.showDiscoverHome;
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
        a.showPlayer == b.showPlayer &&
        a.showDiscoverHome == b.showDiscoverHome;
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
      _collapseCurrentMobilePlayer();
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
            _showMobileDiscoverHome = false;
          });
        },
      );
    }
    switch (route) {
      case ShellRoute.albums:
        return AlbumsScreen(
          mobileRecommendationLayout:
              _mobileTab == MobileAppTab.discover && !_showMobileDiscoverHome,
          onMobileBack: _mobileHistory.isNotEmpty ? _handleMobileBack : null,
          onAlbumTap: (album) {
            _recordMobileHistory();
            setState(() {
              _selectedAlbum = album;
              _selectedProducer = null;
              _showMobileDiscoverHome = false;
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
              _showMobileDiscoverHome = false;
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
              _showMobileDiscoverHome = false;
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
      case ShellRoute.recentPlayed:
        return RecentPlaybackScreen(
          onBack: _mobileHistory.isNotEmpty ? _handleMobileBack : null,
          onPlayTrack: (track) => _openPlayerForQueue(
            track: track,
            queue: [track],
            index: 0,
            contextLabel: '最近播放',
          ),
          onAddToQueue: _addTrackToCurrentQueue,
          currentPlayingTrackId: _currentTrack?.id,
          isPlaying: _isPlaying,
        );
      case ShellRoute.dailyRecommendations:
        return DailyRecommendationsScreen(
          onBack: _mobileHistory.isNotEmpty ? _handleMobileBack : null,
          onPlayTrack: (track, queue, index) => _openPlayerForQueue(
            track: track,
            queue: queue,
            index: index,
            contextLabel: '每日推荐',
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
              _showMobileDiscoverHome = false;
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
        !_showMobileDiscoverHome &&
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
      _showMobileDiscoverHome = false;
      _clearSelection();
      _showPlayer = false;
    });
  }

  void _openMobileDiscoverAlbum(Album album) {
    _recordMobileHistory();
    setState(() {
      _mobileTab = MobileAppTab.discover;
      _route = ShellRoute.albums;
      _showMobileDiscoverHome = false;
      _clearSelection();
      _selectedAlbum = album;
      _showPlayer = false;
    });
  }

  void _openMobileDiscoverProducer(Producer producer) {
    _recordMobileHistory();
    setState(() {
      _mobileTab = MobileAppTab.discover;
      _route = ShellRoute.producers;
      _showMobileDiscoverHome = false;
      _clearSelection();
      _selectedProducer = producer;
      _showPlayer = false;
    });
  }

  void _openMobileDiscoverVocalist(Vocalist vocalist) {
    _recordMobileHistory();
    setState(() {
      _mobileTab = MobileAppTab.discover;
      _route = ShellRoute.vocalists;
      _showMobileDiscoverHome = false;
      _clearSelection();
      _selectedVocalist = vocalist;
      _showPlayer = false;
    });
  }

  void _openMobileDailyRecommendations() {
    if (_mobileTab == MobileAppTab.discover &&
        _route == ShellRoute.dailyRecommendations &&
        !_showPlayer) {
      return;
    }
    _recordMobileHistory();
    setState(() {
      _mobileTab = MobileAppTab.discover;
      _route = ShellRoute.dailyRecommendations;
      _showMobileDiscoverHome = false;
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
      _showMobileDiscoverHome = false;
      _clearSelection();
      _showPlayer = false;
    });
  }

  void _openMobilePlaylist(int playlistId) {
    if (_mobileTab == MobileAppTab.myMusic &&
        _selectedPlaylistId == playlistId &&
        !_showPlayer) {
      return;
    }
    _recordMobileHistory();
    setState(() {
      _mobileTab = MobileAppTab.myMusic;
      _route = ShellRoute.playlists;
      _showMobileDiscoverHome = false;
      _clearSelection();
      _selectedPlaylistId = playlistId;
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
        _showMobileDiscoverHome = true;
        _clearSelection();
      } else {
        _showMobileDiscoverHome = false;
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
                    ShellRoute.playlists ||
                    ShellRoute.recentPlayed => MobileAppTab.myMusic,
                    _ => MobileAppTab.discover,
                  };
                  _route = route;
                  _showMobileDiscoverHome = false;
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
      _orderedPlayerQueue = null;
      _playerIndex = 0;
      _shuffleEnabled = false;
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

  bool get _canUseSharedWebAudio =>
      _playbackMode == PlaybackMode.audio &&
      !_canUseMobileAudioPlayback &&
      _webAudioPlaybackController.isAvailable;

  bool get _canUseMobileAudioPlayback {
    if (!mounted) return false;
    return isMobile(context) &&
        _playbackMode == PlaybackMode.audio &&
        _currentTrack?.hasAudio == true;
  }

  bool get _isMobilePlaybackSurface {
    if (!mounted) return false;
    return isMobile(context);
  }

  String _mobileAudioUrlForTrack(Track track) {
    return ApiClient().streamAudioUrl(track.id);
  }

  MobilePlaybackOrderMode get _mobilePlaybackOrderMode =>
      switch (_playbackOrderMode) {
        PlaybackOrderMode.sequential => MobilePlaybackOrderMode.sequential,
        PlaybackOrderMode.listLoop => MobilePlaybackOrderMode.listLoop,
        PlaybackOrderMode.singleLoop => MobilePlaybackOrderMode.singleLoop,
      };

  Future<void> _playMobileAudioQueue({
    required List<Track> queue,
    required int index,
    Duration initialPosition = Duration.zero,
  }) {
    return _mobileAudioPlaybackService.playQueue(
      queue: queue,
      index: index,
      audioUrlForTrack: _mobileAudioUrlForTrack,
      coverUrlForTrack: _coverUrlForTrack,
      orderMode: _mobilePlaybackOrderMode,
      initialPosition: initialPosition,
      isTrackFavorited: PlaylistRepository.instance.isFavorite,
      toggleTrackFavorite: (track) {
        return PlaylistRepository.instance.toggleFavorite(
          track.id,
          ApiClient(),
        );
      },
    );
  }

  Future<void> _playRestoredMobileAudioQueue(double resumeProgress) async {
    final track = _currentTrack;
    if (track == null) return;
    final progress = resumeProgress.clamp(0.0, 1.0).toDouble();
    final initialPosition = progress > 0 && track.durationSeconds > 0
        ? Duration(
            milliseconds: (track.durationSeconds * 1000 * progress).round(),
          )
        : Duration.zero;
    await _playMobileAudioQueue(
      queue: _playerQueue,
      index: _playerIndex,
      initialPosition: initialPosition,
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

  void _invalidateMobileVideoCollapseRequest() {
    _mobileVideoCollapseRequest += 1;
  }

  Future<void> _syncMobileAudioQueuePreservingProgress() async {
    if (!_isMobilePlaybackSurface) return;
    if (_playbackMode != PlaybackMode.audio) {
      await _mobileAudioPlaybackService.stop();
      return;
    }

    final progress = _playbackProgress;
    final track = _currentTrack;
    final initialPosition = progress > 0 && track != null
        ? Duration(
            milliseconds:
                (track.durationSeconds * 1000 * progress.clamp(0.0, 1.0))
                    .round(),
          )
        : Duration.zero;
    await _playMobileAudioQueue(
      queue: _playerQueue,
      index: _playerIndex,
      initialPosition: initialPosition,
    );
  }

  void _handleMobileAudioState(MobileAudioPlaybackState state) {
    if (!mounted || !isMobile(context) || _playbackMode != PlaybackMode.audio) {
      return;
    }
    if (_isStaleMobileVideoCollapseAudioState(state)) {
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
      if (_shuffleEnabled && track != null && _playerQueue.isNotEmpty) {
        final shuffledIndex = _playerQueue.indexWhere(
          (item) => item.id == track.id,
        );
        if (shuffledIndex >= 0) {
          _playerIndex = shuffledIndex;
        }
      } else {
        _playerQueue = state.queue;
        _playerIndex = state.queue.isEmpty
            ? 0
            : state.index.clamp(0, state.queue.length - 1);
        _orderedPlayerQueue = null;
      }
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
    return resolvePlaybackModeForIntent(
      track: track,
      isMobileSurface: _isMobilePlaybackSurface,
      intent: PlaybackStartIntent.preserve,
      preferVideoOnExpand: _preferVideoOnExpand,
      playerIsOpen: _showPlayer,
      currentPlaybackMode: _playbackMode,
    );
  }

  void _openPlayerForQueue({
    required Track track,
    required List<Track> queue,
    required int index,
    required String contextLabel,
    PlaybackStartIntent intent = PlaybackStartIntent.audio,
  }) {
    if (queue.isEmpty) return;
    _invalidateMobileVideoCollapseRequest();
    final selectedTrack = queue[index.clamp(0, queue.length - 1)];
    final effectiveIntent = _isMobilePlaybackSurface
        ? intent
        : selectedTrack.hasVideo
        ? PlaybackStartIntent.video
        : PlaybackStartIntent.audio;
    setState(() {
      _playerQueue = List<Track>.from(queue);
      _orderedPlayerQueue = null;
      _playerIndex = index.clamp(0, queue.length - 1);
      _shuffleEnabled = false;
      _playerContextLabel = contextLabel;
      _playbackMode = resolvePlaybackModeForIntent(
        track: selectedTrack,
        isMobileSurface: _isMobilePlaybackSurface,
        intent: effectiveIntent,
        preferVideoOnExpand: _preferVideoOnExpand,
        playerIsOpen: true,
      );
      _preferVideoOnExpand =
          effectiveIntent == PlaybackStartIntent.video &&
          selectedTrack.hasVideo;
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
    _invalidateMobileVideoCollapseRequest();
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

  void _addTrackToCurrentQueue(Track track) {
    if (_playerQueue.any((item) => item.id == track.id)) return;
    _invalidateMobileVideoCollapseRequest();
    setState(() {
      _playerQueue = [..._playerQueue, track];
      _orderedPlayerQueue = null;
    });
    _savePlaybackState();
    unawaited(_syncMobileAudioQueuePreservingProgress());
  }

  void _cyclePlaybackOrderMode() {
    _invalidateMobileVideoCollapseRequest();
    late final PlaybackOrderMode nextMode;
    setState(() {
      nextMode = switch (_playbackOrderMode) {
        PlaybackOrderMode.sequential => PlaybackOrderMode.listLoop,
        PlaybackOrderMode.listLoop => PlaybackOrderMode.singleLoop,
        PlaybackOrderMode.singleLoop => PlaybackOrderMode.sequential,
      };
      _playbackOrderMode = nextMode;
    });
    _savePlaybackState();
    if (_isMobilePlaybackSurface) {
      unawaited(
        _mobileAudioPlaybackService.setPlaybackOrderMode(
          _mobilePlaybackOrderMode,
        ),
      );
    }
  }

  void _toggleShufflePlayback() {
    if (_playerQueue.length < 2) return;
    final currentTrack = _currentTrack;
    if (currentTrack == null) return;

    if (_shuffleEnabled) {
      final ordered = _orderedPlayerQueue;
      if (ordered == null || ordered.isEmpty) return;
      _invalidateMobileVideoCollapseRequest();
      final restoredIndex = ordered.indexWhere(
        (track) => track.id == currentTrack.id,
      );
      setState(() {
        _playerQueue = List<Track>.from(ordered);
        _playerIndex = restoredIndex < 0 ? 0 : restoredIndex;
        _orderedPlayerQueue = null;
        _shuffleEnabled = false;
      });
      _savePlaybackState();
      unawaited(_syncMobileAudioQueuePreservingProgress());
      return;
    }

    _invalidateMobileVideoCollapseRequest();
    final rest =
        _playerQueue.where((track) => track.id != currentTrack.id).toList()
          ..shuffle(Random());
    setState(() {
      _orderedPlayerQueue = List<Track>.from(_playerQueue);
      _playerQueue = [currentTrack, ...rest];
      _playerIndex = 0;
      _shuffleEnabled = true;
    });
    _savePlaybackState();
    unawaited(_syncMobileAudioQueuePreservingProgress());
  }

  void _playPrevious() {
    if (_playerQueue.isEmpty) return;
    final nextIndex = resolveRelativePlaybackIndex(
      orderMode: _playbackOrderMode,
      currentIndex: _playerIndex,
      queueLength: _playerQueue.length,
      delta: -1,
    );
    if (nextIndex == null) return;
    _invalidateMobileVideoCollapseRequest();
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
    final nextIndex = resolveRelativePlaybackIndex(
      orderMode: _playbackOrderMode,
      currentIndex: _playerIndex,
      queueLength: _playerQueue.length,
      delta: 1,
    );
    if (nextIndex == null) return;
    _invalidateMobileVideoCollapseRequest();
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
        final resumeProgress = _resumeProgress ?? _playbackProgress;
        setState(() {
          _restoredNotStarted = false;
          _isPlaying = true;
          _resumeProgress = null;
        });
        await _playRestoredMobileAudioQueue(resumeProgress);
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

  Future<void> _playMobileAudioFromPlayerControls() async {
    if (_restoredNotStarted) {
      await _togglePlayback();
      return;
    }
    await _mobileAudioPlaybackService.play();
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
    if (mode == PlaybackMode.audio && !currentTrack.hasAudio) return;
    _invalidateMobileVideoCollapseRequest();
    setState(() {
      _playbackMode = mode;
      if (_isMobilePlaybackSurface) {
        _preferVideoOnExpand =
            mode == PlaybackMode.video && currentTrack.hasVideo;
      }
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
    final currentTrack = _currentTrack;
    if (currentTrack == null) return;
    _invalidateMobileVideoCollapseRequest();
    setState(() {
      _restoredNotStarted = false;
      _showPlayer = true;
      _playbackMode = resolvePlaybackModeForIntent(
        track: currentTrack,
        isMobileSurface: _isMobilePlaybackSurface,
        intent: PlaybackStartIntent.preserve,
        preferVideoOnExpand: _preferVideoOnExpand,
        playerIsOpen: true,
      );
    });
    if (_isMobilePlaybackSurface && _playbackMode == PlaybackMode.video) {
      _resumeProgress = _playbackProgress;
    }
  }

  void _closePlayer() {
    _invalidateMobileVideoCollapseRequest();
    setState(() {
      _showPlayer = false;
    });
  }

  void _collapseCurrentMobilePlayer() {
    if (_isMobilePlaybackSurface && _playbackMode == PlaybackMode.video) {
      setState(() {
        _showPlayer = true;
      });
      unawaited(_collapseMobileVideoToAudio());
      return;
    }
    _closePlayer();
  }

  Future<void> _collapseMobileVideoToAudio() async {
    final currentTrack = _currentTrack;
    if (currentTrack == null) {
      _closePlayer();
      return;
    }
    if (!currentTrack.hasAudio) {
      _invalidateMobileVideoCollapseRequest();
      setState(() {
        _playbackMode = PlaybackMode.video;
        _showPlayer = true;
        _preferVideoOnExpand = currentTrack.hasVideo;
      });
      return;
    }
    final request = ++_mobileVideoCollapseRequest;
    final index = _playerIndex;
    final progress = _playbackProgress.clamp(0.0, 1.0).toDouble();
    final initialPosition = currentTrack.durationSeconds > 0
        ? Duration(
            milliseconds: (currentTrack.durationSeconds * 1000 * progress)
                .round(),
          )
        : Duration.zero;
    _pendingMobileVideoCollapseAudioRequest = request;
    _pendingMobileVideoCollapseAudioTrack = currentTrack;
    _pendingMobileVideoCollapseAudioIndex = index;
    try {
      await _playMobileAudioQueue(
        queue: _playerQueue,
        index: _playerIndex,
        initialPosition: initialPosition,
      );
    } catch (_) {
      if (!mounted) return;
      _clearPendingMobileVideoCollapseAudio(request);
      if (!_isCurrentMobileVideoCollapseRequest(
        request: request,
        track: currentTrack,
        index: index,
      )) {
        return;
      }
      setState(() {
        _playbackMode = PlaybackMode.video;
        _showPlayer = true;
        _preferVideoOnExpand = currentTrack.hasVideo;
      });
      return;
    }
    if (!mounted) return;
    if (!_isCurrentMobileVideoCollapseRequest(
      request: request,
      track: currentTrack,
      index: index,
    )) {
      _clearPendingMobileVideoCollapseAudio(request);
      await _repairMobileAudioAfterStaleCollapse();
      return;
    }
    _clearPendingMobileVideoCollapseAudio(request);
    setState(() {
      _playbackMode = PlaybackMode.audio;
      _showPlayer = false;
      _preferVideoOnExpand = currentTrack.hasVideo;
    });
  }

  bool _isStaleMobileVideoCollapseAudioState(MobileAudioPlaybackState state) {
    final request = _pendingMobileVideoCollapseAudioRequest;
    final track = _pendingMobileVideoCollapseAudioTrack;
    final index = _pendingMobileVideoCollapseAudioIndex;
    final stateTrack = state.track;
    if (request == null ||
        track == null ||
        index == null ||
        stateTrack?.id != track.id ||
        state.index != index) {
      return false;
    }
    return !_isCurrentMobileVideoCollapseRequest(
      request: request,
      track: track,
      index: index,
    );
  }

  void _clearPendingMobileVideoCollapseAudio(int request) {
    if (_pendingMobileVideoCollapseAudioRequest != request) return;
    _pendingMobileVideoCollapseAudioRequest = null;
    _pendingMobileVideoCollapseAudioTrack = null;
    _pendingMobileVideoCollapseAudioIndex = null;
  }

  Future<void> _repairMobileAudioAfterStaleCollapse() async {
    try {
      await _routeMobileAudioPlaybackForCurrentMode();
    } catch (_) {}
  }

  bool _isCurrentMobileVideoCollapseRequest({
    required int request,
    required Track track,
    required int index,
  }) {
    return request == _mobileVideoCollapseRequest &&
        _isMobilePlaybackSurface &&
        _playbackMode == PlaybackMode.video &&
        _playerIndex == index &&
        _currentTrack?.id == track.id;
  }

  double _lastSavedProgress = 0;

  void _updatePlaybackUi({
    required bool isPlaying,
    required double progress,
    required String elapsedLabel,
    required String durationLabel,
  }) {
    if (!mounted) return;
    if (!_playbackUiUpdateGate.shouldPublish(
      isPlaying: isPlaying,
      progress: progress,
      elapsedLabel: elapsedLabel,
      durationLabel: durationLabel,
    )) {
      return;
    }
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
    void applyControllerChange() {
      if (!mounted) return;
      setState(() => _videoController = c);
      if (c != null &&
          _isMobilePlaybackSurface &&
          _playbackMode == PlaybackMode.video) {
        unawaited(_stopMobileAudioAfterVideoAttach());
      }
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        applyControllerChange();
      });
    } else {
      applyControllerChange();
    }
  }

  Future<void> _stopMobileAudioAfterVideoAttach() async {
    try {
      await _mobileAudioPlaybackService.stop();
    } catch (_) {}
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
        intent: PlaybackStartIntent.video,
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
        intent: PlaybackStartIntent.video,
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
        onPlayTrack:
            (track, queue, index, {intent = PlaybackStartIntent.audio}) =>
                _openPlayerForQueue(
                  track: track,
                  queue: queue,
                  index: index,
                  contextLabel: _albumContextLabel(_selectedAlbum!),
                  intent: intent,
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
        onPlayTrack:
            (track, queue, index, {intent = PlaybackStartIntent.audio}) =>
                _openPlayerForQueue(
                  track: track,
                  queue: queue,
                  index: index,
                  contextLabel: queue.every((item) => item.hasVideo)
                      ? _mvContextLabel(_selectedProducer!)
                      : _producerContextLabel(_selectedProducer!),
                  intent: intent,
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
        onPlayTrack:
            (track, queue, index, {intent = PlaybackStartIntent.audio}) =>
                _openPlayerForQueue(
                  track: track,
                  queue: queue,
                  index: index,
                  contextLabel: _vocalistContextLabel(_selectedVocalist!),
                  intent: intent,
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
          _route == ShellRoute.favorites ||
          _route == ShellRoute.playlists ||
          _route == ShellRoute.recentPlayed;
      final appShell = MobileAppShell(
        currentTab: _mobileTab,
        onTabChanged: _selectMobileTab,
        discover: DiscoverScreen(
          currentSection: _discoverSectionForRoute(_route),
          onSectionChanged: _navigateMobileDiscover,
          onMobileMoreSelected: _navigateMobileDiscover,
          onMobileAlbumSelected: _openMobileDiscoverAlbum,
          onMobileProducerSelected: _openMobileDiscoverProducer,
          onMobileVocalistSelected: _openMobileDiscoverVocalist,
          onDailyRecommendationsSelected: _openMobileDailyRecommendations,
          showSectionTabs:
              _showMobileDiscoverHome &&
              _selectedAlbum == null &&
              _selectedProducer == null &&
              _selectedVocalist == null,
          preferMobileHome: _showMobileDiscoverHome,
          child: mainContent,
        ),
        myMusic: showMyMusicContent
            ? mainContent
            : MyMusicScreen(
                onNavigate: _navigateMobileMyMusic,
                onPlaylistTap: _openMobilePlaylist,
                onQueue: _openCurrentPlayer,
                currentTrack: currentTrack,
              ),
        settings: SettingsScreen(
          serverUrl: ApiConfig.defaultBaseUrl,
          hasServerCookie: ApiConfig.defaultHeaders.containsKey('Cookie'),
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
              if (currentTrack != null)
                MobilePlayerSheet(
                  track: currentTrack,
                  coverUrl: _coverUrlForTrack(currentTrack),
                  isPlaying: _isPlaying,
                  progress: _playbackProgress,
                  onPlayPause: _togglePlayback,
                  bottomPadding: bottomPadding,
                  expanded: _showPlayer,
                  onExpandedChanged: (expanded) {
                    if (expanded) {
                      _openCurrentPlayer();
                      return;
                    }
                    _collapseCurrentMobilePlayer();
                  },
                  playerBuilder: (onClose) => PlayerScreen(
                    track: currentTrack,
                    queue: _playerQueue,
                    currentIndex: _playerIndex,
                    contextLabel: _playerContextLabel,
                    baseUrl: ApiConfig.defaultBaseUrl,
                    playbackMode: _playbackMode,
                    onSelectTrack: (index) => _selectPlayerTrack(index),
                    onPrevious: _playPrevious,
                    onNext: _playNext,
                    onClose: () {
                      if (_isMobilePlaybackSurface &&
                          _playbackMode == PlaybackMode.video) {
                        _collapseCurrentMobilePlayer();
                        return;
                      }
                      onClose();
                    },
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
                    onExternalPlay: _playMobileAudioFromPlayerControls,
                    onExternalPause: _mobileAudioPlaybackService.pause,
                    onExternalSeekToFraction: _seekMobileAudioPlayback,
                    currentCoverUrl: _coverUrlForTrack(currentTrack),
                    coverUrlForTrack: _coverUrlForTrack,
                    shuffleEnabled: _shuffleEnabled,
                    onToggleShuffle: _toggleShufflePlayback,
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
              baseUrl: ApiConfig.defaultBaseUrl,
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
