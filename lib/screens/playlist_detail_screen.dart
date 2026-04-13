import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../services/playlist_repository.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/playlist_detail/playlist_edit_bar.dart';
import '../widgets/playlist_detail/playlist_hero.dart';
import '../widgets/playlist_detail/playlist_track_row.dart';

// Constants
const _kMessageDuration = Duration(seconds: 3);
const _kMessageTopOffset = 16.0;
const _kMessageHorizontalPadding = 24.0;
const _kMessageInternalPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
const _kMessageBorderRadius = 8.0;
const _kMessageIconSize = 22.0;

/// Shows a temporary message at the top of the screen.
/// Returns a Timer that can be cancelled to prevent the message from being removed.
Timer _showTopMessage(BuildContext context, String message,
    {required bool isError}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      top: MediaQuery.paddingOf(ctx).top + _kMessageTopOffset,
      left: _kMessageHorizontalPadding,
      right: _kMessageHorizontalPadding,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: _kMessageInternalPadding,
          decoration: BoxDecoration(
            color: isError ? Colors.red.shade800 : AppTheme.mikuGreen,
            borderRadius: BorderRadius.circular(_kMessageBorderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? Colors.white : Colors.black,
                size: _kMessageIconSize,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: isError ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  return Timer(_kMessageDuration, () {
    entry.remove();
  });
}

class PlaylistDetailScreen extends StatefulWidget {
  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    this.baseUrl = '',
    this.onBack,
    this.onPlayTrack,
    this.currentPlayingTrackId,
    this.isPlaying = false,
  });

  final int playlistId;
  final String baseUrl;
  final VoidCallback? onBack;
  final void Function(Track track, List<Track> queue, int index)? onPlayTrack;
  final int? currentPlayingTrackId;
  final bool isPlaying;

  String get _effectiveBaseUrl =>
      baseUrl.isEmpty ? ApiConfig.defaultBaseUrl : baseUrl;

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  List<Track> _tracks = [];
  bool _loading = true;
  String? _error;
  bool _isEditMode = false;
  bool _isLoading = false; // Prevents concurrent _loadPlaylistAndTracks calls
  bool _isOperating = false; // Shows loading feedback during operations

  late final ApiClient _client;
  Playlist? _playlist;
  Timer? _messageTimer; // Tracks the message overlay timer for cleanup

  @override
  void initState() {
    super.initState();
    // ApiClient uses http package which doesn't require disposal.
    // The http.Client is created per-request and closed automatically.
    _client = ApiClient(baseUrl: widget._effectiveBaseUrl);
    _loadPlaylistAndTracks();
    PlaylistRepository.instance.addListener(_onRepositoryUpdate);
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    PlaylistRepository.instance.removeListener(_onRepositoryUpdate);
    super.dispose();
  }

  void _onRepositoryUpdate() {
    if (!mounted) return;
    final updated = PlaylistRepository.instance.playlists
        .where((p) => p.id == widget.playlistId)
        .firstOrNull;
    // Compare by ID and relevant fields since Playlist doesn't override ==
    if (updated != null &&
        (updated.id != _playlist?.id ||
            updated.name != _playlist?.name ||
            updated.trackCount != _playlist?.trackCount ||
            updated.coverPath != _playlist?.coverPath)) {
      setState(() {
        _playlist = updated;
      });
    }
  }

  Future<void> _loadPlaylistAndTracks() async {
    // Prevent concurrent loads (race condition guard)
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _loading = true;
      _error = null;
    });
    try {
      final playlist = PlaylistRepository.instance.playlists
          .where((p) => p.id == widget.playlistId)
          .firstOrNull;
      final tracks = await _client.getPlaylistTracks(widget.playlistId);
      if (!mounted) return;
      setState(() {
        _playlist = playlist;
        _tracks = tracks;
        _loading = false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _sanitizeError(e);
        _loading = false;
        _isLoading = false;
      });
    }
  }

  /// Sanitizes error messages for user display
  String _sanitizeError(Object error) {
    final errorStr = error.toString();
    // Remove technical stack traces and internal details
    if (errorStr.contains('Exception:')) {
      return errorStr.split('Exception:').last.trim();
    }
    if (errorStr.contains('Error:')) {
      return errorStr.split('Error:').last.trim();
    }
    // Generic fallback for unknown errors
    if (errorStr.length > 200) {
      return 'An error occurred. Please try again.';
    }
    return errorStr;
  }

  void _playTrack(Track track, int index) {
    widget.onPlayTrack?.call(track, _tracks, index);
  }

  void _playAll() {
    if (_tracks.isEmpty) return;
    _playTrack(_tracks.first, 0);
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
  }

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    // Prevent concurrent operations
    if (_isOperating) return;

    // Adjust newIndex if moving down (ReorderableListView quirk)
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    // Optimistic update
    final updatedTracks = List<Track>.from(_tracks);
    final movedTrack = updatedTracks.removeAt(oldIndex);
    updatedTracks.insert(newIndex, movedTrack);

    setState(() {
      _tracks = updatedTracks;
      _isOperating = true;
    });

    // Call API
    try {
      final trackIds = updatedTracks.map((t) => t.id).toList();
      await _client.reorderPlaylist(widget.playlistId, trackIds);
    } catch (e) {
      // Revert on error
      if (!mounted) return;
      await _loadPlaylistAndTracks();
      if (!mounted) return;
      _messageTimer?.cancel();
      _messageTimer = _showTopMessage(
        context,
        'Failed to reorder: ${_sanitizeError(e)}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOperating = false;
        });
      }
    }
  }

  Future<void> _handleRemoveTrack(Track track) async {
    // Prevent concurrent operations
    if (_isOperating) return;

    // Optimistic update
    final originalTracks = _tracks;
    final updatedTracks = _tracks.where((t) => t.id != track.id).toList();

    setState(() {
      _tracks = updatedTracks;
      _isOperating = true;
    });

    // Call API
    try {
      await _client.removeTracksFromPlaylist(widget.playlistId, [track.id]);
      // Refresh playlist metadata to update track count
      await PlaylistRepository.instance.refreshPlaylists(_client);
    } catch (e) {
      // Revert on error
      if (!mounted) return;
      setState(() {
        _tracks = originalTracks;
      });
      _messageTimer?.cancel();
      _messageTimer = _showTopMessage(
        context,
        'Failed to remove track: ${_sanitizeError(e)}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOperating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_playlist == null && !_loading) {
      return Scaffold(
        backgroundColor: AppTheme.mikuDark,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Playlist not found'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.mikuDark,
      body: Stack(
        children: [
          Column(
            children: [
              if (_isEditMode)
                PlaylistEditBar(
                  onDone: _toggleEditMode,
                ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    if (isMobile(context) && widget.onBack != null)
                      SliverAppBar(
                        backgroundColor: Colors.transparent,
                        pinned: false,
                        floating: true,
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: widget.onBack,
                        ),
                        title: Text(
                          _playlist?.name ?? '',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    if (_playlist != null)
                      SliverToBoxAdapter(
                        child: PlaylistHero(
                          playlist: _playlist!,
                          client: _client,
                          onPlay: _playAll,
                          onEdit: _toggleEditMode,
                        ),
                      ),
                    if (_loading)
                      const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      SliverFillRemaining(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: _loadPlaylistAndTracks,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (_tracks.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.music_note,
                                  size: 64,
                                  color: AppTheme.textMuted.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No tracks in this playlist',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: AppTheme.textMuted,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile(context) ? 8 : 32,
                          vertical: 16,
                        ),
                        sliver: SliverReorderableList(
                          itemCount: _tracks.length,
                          onReorder: _handleReorder,
                          itemBuilder: (context, index) {
                            final track = _tracks[index];
                            return ReorderableDelayedDragStartListener(
                              key: ValueKey(track.id),
                              index: index,
                              enabled: _isEditMode,
                              child: PlaylistTrackRow(
                                track: track,
                                baseUrl: widget._effectiveBaseUrl,
                                onTap: () => _playTrack(track, index),
                                onRemove: () => _handleRemoveTrack(track),
                                showDragHandle: _isEditMode,
                                isCurrentlyPlaying:
                                    widget.currentPlayingTrackId == track.id &&
                                        widget.isPlaying,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // Loading overlay during operations
          if (_isOperating)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
