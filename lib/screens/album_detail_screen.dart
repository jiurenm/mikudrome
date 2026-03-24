import 'dart:math';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/album.dart';
import '../models/producer.dart';
import '../models/track.dart';
import '../theme/app_theme.dart';
import '../widgets/album_detail/album_action_bar.dart';
import '../widgets/album_detail/album_hero_section.dart';
import '../widgets/album_detail/album_track_list.dart';

void _showTopMessage(BuildContext context, String message,
    {required bool isError}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      top: MediaQuery.paddingOf(ctx).top + 16,
      left: 24,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isError ? Colors.red.shade800 : AppTheme.mikuGreen,
            borderRadius: BorderRadius.circular(8),
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
                size: 22,
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
  Future.delayed(const Duration(seconds: 3), () {
    entry.remove();
  });
}

class AlbumDetailScreen extends StatefulWidget {
  AlbumDetailScreen({
    super.key,
    required this.album,
    this.baseUrl = '',
    this.onProducerTap,
    this.onPlayTrack,
  });

  final Album album;
  final String baseUrl;
  String get _effectiveBaseUrl =>
      baseUrl.isEmpty ? ApiConfig.defaultBaseUrl : baseUrl;
  final ValueChanged<Producer>? onProducerTap;
  final void Function(Track track, List<Track> queue, int index)? onPlayTrack;

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  List<Track> _tracks = [];
  bool _loading = true;
  String? _error;

  Map<int, List<Track>> get _tracksByDisc {
    final Map<int, List<Track>> grouped = {};
    for (final track in _tracks) {
      grouped.putIfAbsent(track.discNumber, () => []).add(track);
    }
    return grouped;
  }

  bool get _isMultiDisc => _tracksByDisc.keys.length > 1;

  @override
  void initState() {
    super.initState();
    _loadAlbum();
  }

  Future<void> _loadAlbum() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiClient(baseUrl: widget._effectiveBaseUrl)
          .getAlbum(widget.album.id);
      if (result == null || !mounted) return;
      setState(() {
        _tracks = result.tracks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _playTrack(Track track, int index, {List<Track>? queue}) {
    widget.onPlayTrack?.call(track, queue ?? _tracks, index);
  }

  void _shufflePlay() {
    if (_tracks.isEmpty) return;
    final shuffled = List<Track>.from(_tracks);
    shuffled.shuffle(Random());
    _playTrack(shuffled.first, 0, queue: shuffled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.mikuDark,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: AlbumHeroSection(
                    album: widget.album,
                    tracks: _tracks,
                    baseUrl: widget._effectiveBaseUrl,
                    onProducerTap: widget.onProducerTap,
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
                                onPressed: _loadAlbum,
                                child: const Text('Retry')),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: AlbumActionBar(
                      tracks: _tracks,
                      onPlayAll: () => _playTrack(_tracks.first, 0),
                      onShuffle: _shufflePlay,
                    ),
                  ),
                  AlbumTrackList(
                    tracks: _tracks,
                    isMultiDisc: _isMultiDisc,
                    tracksByDisc: _tracksByDisc,
                    baseUrl: widget._effectiveBaseUrl,
                    onDownloadComplete: _loadAlbum,
                    onPlayTrack: _playTrack,
                    showTopMessage: (message, {required isError}) =>
                        _showTopMessage(context, message, isError: isError),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
