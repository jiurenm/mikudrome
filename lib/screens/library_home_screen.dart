import 'package:flutter/material.dart';

import '../models/track.dart';
import '../theme/app_theme.dart';
import '../widgets/now_playing_bar.dart';
import '../widgets/app_shell.dart';
import 'album_detail_screen.dart';
import 'albums_screen.dart';
import 'player_screen.dart';
import 'producer_detail_screen.dart';
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
        return const _PlaceholderScreen(
          title: 'Local MV Gallery',
          subtitle: 'All tracks with local MV',
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
    });
  }

  void _selectPlayerTrack(int index) {
    if (index < 0 || index >= _playerQueue.length) return;
    final nextTrack = _playerQueue[index];
    setState(() {
      _playerIndex = index;
      _playbackMode = _nextModeForTrack(nextTrack);
      _showPlayer = true;
      _isPlaying = true;
    });
  }

  void _cyclePlaybackOrderMode() {
    setState(() {
      _playbackOrderMode = switch (_playbackOrderMode) {
        PlaybackOrderMode.sequential => PlaybackOrderMode.listLoop,
        PlaybackOrderMode.listLoop => PlaybackOrderMode.singleLoop,
        PlaybackOrderMode.singleLoop => PlaybackOrderMode.sequential,
      };
    });
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
  }

  void _togglePlayback() {
    if (_currentTrack == null) return;
    setState(() {
      _showPlayer = true;
    });
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
      _showPlayer = true;
    });
  }

  void _closePlayer() {
    setState(() {
      _showPlayer = false;
    });
  }

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
  }

  String _albumContextLabel(Album album) => 'Album / ${album.title}';
  String _producerContextLabel(Producer producer) =>
      'Producer / ${producer.name}';
  String _mvContextLabel(Producer producer) =>
      'Featured MVs / ${producer.name}';

  @override
  Widget build(BuildContext context) {
    final currentTrack = _currentTrack;
    Widget content;
    if (_showPlayer && currentTrack != null) {
      content = PlayerScreen(
        track: currentTrack,
        queue: _playerQueue,
        currentIndex: _playerIndex,
        contextLabel: _playerContextLabel,
        playbackMode: _playbackMode,
        onSelectTrack: _selectPlayerTrack,
        onPrevious: _playPrevious,
        onNext: _playNext,
        onClose: _closePlayer,
        onSwitchPlaybackMode: _switchPlaybackMode,
        playbackOrderMode: _playbackOrderMode,
        onCyclePlaybackOrderMode: _cyclePlaybackOrderMode,
        onPlaybackStateChanged: _updatePlaybackUi,
      );
    } else if (_selectedAlbum != null) {
      content = AlbumDetailScreen(
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
      );
    } else if (_selectedProducer != null) {
      content = ProducerDetailScreen(
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
      content = _contentForRoute(_route);
    }

    return AppShell(
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
              isPlaying: _isPlaying,
              progress: _playbackProgress,
              elapsedLabel: _elapsedLabel,
              durationLabel: _durationLabel,
              playbackMode: _playbackMode,
              onTogglePlay: _togglePlayback,
              onPrevious: _playPrevious,
              onNext: _playNext,
              onOpenPlayer: _openCurrentPlayer,
            ),
      child: content,
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
