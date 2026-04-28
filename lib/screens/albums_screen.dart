import 'package:flutter/material.dart';

import '../models/album.dart';
import '../api/api.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/auto_scroll_text.dart';
import 'album_detail_screen.dart';

/// Main library: album grid from API (media/Artist/Album), with search.
/// When [onAlbumTap] is set, opens album in-shell; otherwise pushes a new route.
class AlbumsScreen extends StatefulWidget {
  AlbumsScreen({super.key, this.baseUrl = '', this.onAlbumTap});

  final String baseUrl;
  String get _effectiveBaseUrl =>
      baseUrl.isEmpty ? ApiConfig.defaultBaseUrl : baseUrl;
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
      final list = await ApiClient(
        baseUrl: widget._effectiveBaseUrl,
      ).getAlbums();
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

  Widget _buildHeader(BuildContext context, int albumCount) {
    final titleWidget = Column(
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
          'Total $albumCount albums',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
        ),
      ],
    );

    final searchWidget = TextField(
      controller: _searchController,
      decoration: const InputDecoration(
        hintText: 'Search producers, songs...',
        prefixIcon: Icon(Icons.search, color: AppTheme.textMuted, size: 18),
      ),
      style: const TextStyle(fontSize: 14),
      onChanged: (_) => setState(() {}),
    );

    if (isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget,
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: searchWidget),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        titleWidget,
        SizedBox(width: 264, child: searchWidget),
      ],
    );
  }

  List<Album> get _filteredAlbums {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _albums;
    return _albums
        .where(
          (a) =>
              a.title.toLowerCase().contains(q) ||
              a.producerName.toLowerCase().contains(q),
        )
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
            padding: EdgeInsets.all(isMobile(context) ? 12.0 : 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_buildHeader(context, list.length)],
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
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.80,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
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
                                baseUrl: widget._effectiveBaseUrl,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  }, childCount: list.length),
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
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
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
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.album.coverUrl,
                          headers: ApiConfig.defaultHeaders,
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                          cacheWidth: 360,
                          errorBuilder: (_, __, ___) => Container(
                            width: size,
                            height: size,
                            color: AppTheme.cardBg,
                            child: const Icon(
                              Icons.album,
                              color: AppTheme.textMuted,
                              size: 48,
                            ),
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
                                    size: 40,
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
            const SizedBox(height: 8),
            SizedBox(
              height: 20,
              child: AutoScrollText(
                text: widget.album.title,
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                active: _hovering,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 16,
              child: AutoScrollText(
                text: widget.album.producerName,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall!.copyWith(color: AppTheme.textMuted),
                active: _hovering,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
