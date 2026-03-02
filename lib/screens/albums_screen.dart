import 'package:flutter/material.dart';

import '../models/album.dart';
import '../api/api.dart';
import '../theme/app_theme.dart';
import 'album_detail_screen.dart';

/// Main library: album grid from API (media/Artist/Album), with search.
/// When [onAlbumTap] is set, opens album in-shell; otherwise pushes a new route.
class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({
    super.key,
    this.baseUrl = ApiConfig.defaultBaseUrl,
    this.onAlbumTap,
  });

  final String baseUrl;
  final ValueChanged<Album>? onAlbumTap;

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  List<Album> _albums = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiClient(baseUrl: widget.baseUrl).getAlbums();
      setState(() {
        _albums = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Album> get _filteredAlbums {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _albums;
    return _albums
        .where((a) =>
            a.title.toLowerCase().contains(q) ||
            a.producerName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadAlbums, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final list = _filteredAlbums;
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
                          'Total ${list.length} albums',
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
                        decoration: const InputDecoration(
                          hintText: 'Search producers, songs...',
                          prefixIcon: Icon(Icons.search, color: AppTheme.textMuted, size: 18),
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
        list.isEmpty
            ? const SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No albums. Add media under media/Artist/Album/ and run the server.',
                  ),
                ),
              )
            : SliverPadding(
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
                      final album = list[index];
                      return _AlbumCard(
                        album: album,
                        onTap: () {
                          if (widget.onAlbumTap != null) {
                            widget.onAlbumTap!(album);
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) => AlbumDetailScreen(
                                  album: album,
                                  baseUrl: widget.baseUrl,
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                    childCount: list.length,
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
  bool _hovering = false;

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
                return MouseRegion(
                  onEnter: (_) => setState(() => _hovering = true),
                  onExit: (_) => setState(() => _hovering = false),
                  child: Stack(
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
                      if (_hovering)
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
                  ),
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
            widget.album.year > 0
                ? '${widget.album.year} • ${widget.album.trackCount} Tracks'
                : '${widget.album.trackCount} Tracks',
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
