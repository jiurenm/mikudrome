import 'package:flutter/material.dart';

import '../models/album.dart';
import '../theme/app_theme.dart';
import 'album_detail_screen.dart';

/// Main library: album grid + search, matching miku_main.html.
class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({
    super.key,
    this.albums,
    this.onRefresh,
  });

  final List<Album>? albums;
  final VoidCallback? onRefresh;

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  static List<Album> _mockAlbums() {
    return [
      const Album(
        id: '1',
        title: 'HUMAN',
        producerName: 'ピノキオピー',
        year: 2021,
        trackCount: 14,
        coverSeed: 'album1',
      ),
      const Album(
        id: '2',
        title: 'Greatest Idols',
        producerName: 'Mitchie M',
        year: 2013,
        trackCount: 13,
        coverSeed: 'mitchie',
      ),
      const Album(
        id: '3',
        title: 'Vocaloid Collection',
        producerName: 'Various',
        year: 2020,
        trackCount: 24,
        coverSeed: 'vc',
      ),
    ];
  }

  late List<Album> _albums;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _albums = widget.albums ?? _mockAlbums();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Albums',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total ${_albums.length} albums found in your NAS',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 264,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search producers, songs...',
                          prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 18),
                        ),
                        style: const TextStyle(fontSize: 14),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 32,
              crossAxisSpacing: 32,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final album = _albums[index];
                return _AlbumCard(
                  album: album,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => AlbumDetailScreen(album: album),
                      ),
                    );
                  },
                );
              },
              childCount: _albums.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _AlbumCard extends StatefulWidget {
  const _AlbumCard({required this.album, required this.onTap});

  final Album album;
  final VoidCallback onTap;

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final size = c.maxWidth;
                return Stack(
                  clipBehavior: Clip.antiAlias,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.album.coverUrl,
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: size,
                          height: size,
                          color: AppTheme.cardBg,
                          child: const Icon(Icons.album, color: AppTheme.textMuted, size: 48),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onTap,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.play_circle_fill,
                                color: AppTheme.mikuGreen,
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.album.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            widget.album.producerName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.album.year} • ${widget.album.trackCount} Tracks',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textMuted,
                  letterSpacing: 0.5,
                ),
          ),
        ],
      ),
    );
  }
}
