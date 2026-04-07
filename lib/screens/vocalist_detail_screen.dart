import 'dart:math';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/album.dart';
import '../models/track.dart';
import '../models/vocalist.dart';
import '../theme/app_theme.dart';
import '../theme/vocal_theme.dart';
import '../utils/responsive.dart';
import '../widgets/producer_detail/discography_grid.dart';
import '../widgets/producer_detail/producer_track_list.dart';
import 'album_detail_screen.dart';

class VocalistDetailScreen extends StatefulWidget {
  const VocalistDetailScreen({
    super.key,
    required this.vocalist,
    this.onBack,
    this.onAlbumTap,
    this.onPlayTrack,
  });

  final Vocalist vocalist;
  final VoidCallback? onBack;
  final ValueChanged<Album>? onAlbumTap;
  final void Function(Track track, List<Track> queue, int index)? onPlayTrack;

  @override
  State<VocalistDetailScreen> createState() => _VocalistDetailScreenState();
}

class _VocalistDetailScreenState extends State<VocalistDetailScreen> {
  List<Album> _albums = [];
  List<Track> _tracks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiClient().getVocalistTracks(widget.vocalist.name);
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _error = 'Vocalist not found';
          _loading = false;
        });
        return;
      }
      setState(() {
        _tracks = result.tracks;
        _albums = result.albums;
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

  void _playTrack(Track track, int index) {
    widget.onPlayTrack?.call(track, _tracks, index);
  }

  void _shufflePlay() {
    if (_tracks.isEmpty) return;
    final shuffled = List<Track>.from(_tracks);
    shuffled.shuffle(Random());
    _playTrack(shuffled.first, 0);
  }

  @override
  Widget build(BuildContext context) {
    final color = VocalColors.colorForName(widget.vocalist.name);
    final mobile = isMobile(context);

    return Scaffold(
      backgroundColor: AppTheme.mikuDark,
      body: CustomScrollView(
        slivers: [
          if (mobile && widget.onBack != null)
            SliverAppBar(
              backgroundColor: Colors.transparent,
              pinned: false,
              floating: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              title: Text(widget.vocalist.name,
                  style: const TextStyle(fontSize: 16)),
            ),
          // Hero section
          SliverToBoxAdapter(
            child: _VocalistHero(
              vocalist: widget.vocalist,
              color: color,
              trackCount: _tracks.length,
              albumCount: _albums.length,
              onShuffle: _shufflePlay,
              hasTracks: _tracks.isNotEmpty,
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
                          onPressed: _loadData, child: const Text('Retry')),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.all(mobile ? 16 : 48),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_albums.isNotEmpty) ...[
                    _SectionTitle('Albums', color: color),
                    const SizedBox(height: 24),
                    DiscographyGrid(
                      albums: _albums,
                      onAlbumTap: (album) {
                        if (widget.onAlbumTap != null) {
                          widget.onAlbumTap!(album);
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  AlbumDetailScreen(album: album),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                  _SectionTitle('All Tracks', color: color),
                  const SizedBox(height: 8),
                  ProducerTrackList(
                    tracks: _tracks,
                    baseUrl: ApiConfig.defaultBaseUrl,
                    onPlay: _playTrack,
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _VocalistHero extends StatelessWidget {
  const _VocalistHero({
    required this.vocalist,
    required this.color,
    required this.trackCount,
    required this.albumCount,
    required this.onShuffle,
    required this.hasTracks,
  });

  final Vocalist vocalist;
  final Color color;
  final int trackCount;
  final int albumCount;
  final VoidCallback onShuffle;
  final bool hasTracks;

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        mobile ? 24 : 64,
        mobile ? 24 : 48,
        mobile ? 24 : 64,
        mobile ? 24 : 40,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            AppTheme.mikuDark,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: mobile ? 28 : 40,
                backgroundColor: color.withValues(alpha: 0.15),
                foregroundImage: NetworkImage(
                  ApiClient().vocalistAvatarUrl(vocalist.name),
                ),
                onForegroundImageError: (_, __) {},
                child: Icon(
                  Icons.mic,
                  size: mobile ? 28 : 40,
                  color: color,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vocalist.name,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '$trackCount tracks',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppTheme.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$albumCount albums',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (hasTracks)
            FilledButton.icon(
              onPressed: onShuffle,
              icon: const Icon(Icons.shuffle, size: 18),
              label: const Text('Shuffle Play'),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.color = AppTheme.mikuGreen});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 2,
          color: color,
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
