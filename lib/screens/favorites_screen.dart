import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/track.dart';
import '../services/playlist_repository.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/favorites/favorites_hero.dart';
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

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({
    super.key,
    this.baseUrl = '',
    this.onBack,
    this.onPlayTrack,
    this.currentPlayingTrackId,
    this.isPlaying = false,
  });

  final String baseUrl;
  final VoidCallback? onBack;
  final void Function(Track track, List<Track> queue, int index)? onPlayTrack;
  final int? currentPlayingTrackId;
  final bool isPlaying;

  String get _effectiveBaseUrl =>
      baseUrl.isEmpty ? ApiConfig.defaultBaseUrl : baseUrl;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Track> _tracks = [];
  bool _loading = true;
  String? _error;
  bool _isOperating = false; // Shows loading feedback during operations

  late final ApiClient _client;
  Timer? _messageTimer; // Tracks the message overlay timer for cleanup

  @override
  void initState() {
    super.initState();
    _client = ApiClient(baseUrl: widget._effectiveBaseUrl);
    _loadFavorites();
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
    // Reload favorites when repository changes (e.g., favorite toggled elsewhere)
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tracks = await _client.listFavorites();
      if (!mounted) return;
      setState(() {
        _tracks = tracks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _sanitizeError(e);
        _loading = false;
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

  Future<void> _handleRemoveFavorite(Track track) async {
    // Prevent concurrent operations
    if (_isOperating) return;

    // Optimistic update
    final originalTracks = _tracks;
    final updatedTracks = _tracks.where((t) => t.id != track.id).toList();

    setState(() {
      _tracks = updatedTracks;
      _isOperating = true;
    });

    // Call API via repository
    try {
      await PlaylistRepository.instance.toggleFavorite(track.id, _client);
    } catch (e) {
      // Revert on error
      if (!mounted) return;
      setState(() {
        _tracks = originalTracks;
      });
      _messageTimer?.cancel();
      _messageTimer = _showTopMessage(
        context,
        'Failed to remove favorite: ${_sanitizeError(e)}',
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
    return Scaffold(
      backgroundColor: AppTheme.mikuDark,
      body: Stack(
        children: [
          CustomScrollView(
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
                  title: const Text(
                    'Favorites',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              SliverToBoxAdapter(
                child: FavoritesHero(
                  trackCount: _tracks.length,
                  onPlay: _playAll,
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
                            onPressed: _loadFavorites,
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
                            Icons.favorite_border,
                            size: 64,
                            color: AppTheme.textMuted.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No favorite tracks yet',
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
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final track = _tracks[index];
                        return PlaylistTrackRow(
                          key: ValueKey(track.id),
                          track: track,
                          baseUrl: widget._effectiveBaseUrl,
                          onTap: () => _playTrack(track, index),
                          onRemove: () => _handleRemoveFavorite(track),
                          showDragHandle: false,
                          isCurrentlyPlaying:
                              widget.currentPlayingTrackId == track.id &&
                                  widget.isPlaying,
                        );
                      },
                      childCount: _tracks.length,
                    ),
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
