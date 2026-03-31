import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../api/api.dart';
import '../models/track.dart';
import '../models/video.dart';
import '../services/playback_storage.dart';
import '../theme/app_theme.dart';
import '../theme/vocal_theme.dart';
import '../widgets/now_playing_bar.dart';
import '../widgets/player/pip_mini_player.dart';
import '../widgets/app_shell.dart';
import 'album_detail_screen.dart';
import 'albums_screen.dart';
import 'player_screen.dart';
import 'producer_detail_screen.dart';
import 'mv_gallery_screen.dart';
import 'producers_screen.dart';
import '../models/album.dart';
import '../models/producer.dart';

enum PlaybackMode { video, audio }

enum PlaybackOrderMode { sequential, listLoop, singleLoop }

/// Root screen: app shell + route-based content. Album detail is shown in-shell (sidebar stays).
class LibraryHomeScreen extends StatefulWidget {
  const LibraryHomeScreen({super.key});

  @override
  State<LibraryHomeScreen> createState() => _LibraryHomeScreenState();
}

class _LibraryHomeScreenState extends State<LibraryHomeScreen> {
  static Future<void> _noopTogglePlayback() async {}

  static Future<void> _noopSeekToFraction(double _) async {}
  ShellRoute _route = ShellRoute.albums;
  Album? _selectedAlbum;
  Producer? _selectedProducer;
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

  bool _restoredNotStarted = false;
  double? _resumeProgress;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _restorePlaybackState();
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
    final track = saved.queue.isNotEmpty &&
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

  Widget _contentForRoute(ShellRoute route) {
    switch (route) {
      case ShellRoute.albums:
        return AlbumsScreen(
          onAlbumTap: (album) => setState(() {
            _selectedAlbum = album;
            _selectedProducer = null;
            _showPlayer = false;
          }),
        );
      case ShellRoute.producers:
        return ProducersScreen(
          onProducerTap: (producer) => setState(() {
            _selectedProducer = producer;
            _selectedAlbum = null;
            _showPlayer = false;
          }),
        );
      case ShellRoute.vocalists:
        return const _PlaceholderScreen(
          title: 'Vocalists',
          subtitle: 'Browse by vocalist (e.g. 初音ミク)',
        );
      case ShellRoute.nasFolders:
        return const _PlaceholderScreen(
          title: 'NAS Folders',
          subtitle: 'Browse by folder structure',
        );
      case ShellRoute.favorites:
        return const _PlaceholderScreen(
          title: 'Favorite Tracks',
          subtitle: 'Your liked tracks',
        );
      case ShellRoute.localMv:
        return MvGalleryScreen(
          onVideoTap: _playVideo,
        );
    }
  }

  PlaybackMode _defaultModeForTrack(Track track) =>
      track.hasVideo ? PlaybackMode.video : PlaybackMode.audio;

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
      PlaybackOrderMode.listLoop => _playerIndex > 0
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
  }

  void _playNext() {
    if (_playerQueue.isEmpty) return;
    final nextIndex = switch (_playbackOrderMode) {
      PlaybackOrderMode.listLoop => _playerIndex < _playerQueue.length - 1
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
  }

  Future<void> _togglePlayback() async {
    if (_currentTrack == null) return;
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
    await _playerSeekToFraction(value);
  }

  void _switchPlaybackMode(PlaybackMode mode) {
    final currentTrack = _currentTrack;
    if (currentTrack == null) return;
    if (mode == PlaybackMode.video && !currentTrack.hasVideo) return;
    setState(() {
      _playbackMode = mode;
      _isPlaying = true;
    });
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
          final featMatch =
              RegExp(r'^(.+?)\s+feat\.?\s+(.+)$', caseSensitive: false)
                  .firstMatch(creditsPart);
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
        contextLabel: 'MV Gallery / ${composer.isNotEmpty ? composer : video.title}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack = _currentTrack;
    Widget mainContent;
    if (_selectedAlbum != null) {
      mainContent = AlbumDetailScreen(
        album: _selectedAlbum!,
        onProducerTap: (producer) => setState(() {
          _selectedProducer = producer;
          _selectedAlbum = null;
          _route = ShellRoute.producers;
          _showPlayer = false;
        }),
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
        onAlbumTap: (album) => setState(() {
          _selectedAlbum = album;
          _selectedProducer = null;
          _route = ShellRoute.albums;
          _showPlayer = false;
        }),
        onPlayTrack: (track, queue, index) => _openPlayerForQueue(
          track: track,
          queue: queue,
          index: index,
          contextLabel: queue.every((item) => item.hasVideo)
              ? _mvContextLabel(_selectedProducer!)
              : _producerContextLabel(_selectedProducer!),
        ),
      );
    } else {
      mainContent = _contentForRoute(_route);
    }

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
              onControlsReady: (
                  {required togglePlayback, required seekToFraction}) {
                _registerPlayerControls(
                    togglePlayback: togglePlayback,
                    seekToFraction: seekToFraction);
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

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}
