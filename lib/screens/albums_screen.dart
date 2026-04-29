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
  AlbumsScreen({
    super.key,
    this.baseUrl = '',
    this.onAlbumTap,
    this.mobileRecommendationLayout = false,
    this.onMobileBack,
  });

  final String baseUrl;
  String get _effectiveBaseUrl =>
      baseUrl.isEmpty ? ApiConfig.defaultBaseUrl : baseUrl;
  final ValueChanged<Album>? onAlbumTap;
  final bool mobileRecommendationLayout;
  final VoidCallback? onMobileBack;

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

  Widget _buildMobileRecommendationHeader(BuildContext context) {
    const filters = ['全部', '最新', '最热', 'VOCALOID', '同人', '原创'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: widget.onMobileBack,
            tooltip: '返回',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary,
              size: 24,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '专辑推荐',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(全部)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {},
                tooltip: '搜索',
                icon: const Icon(
                  Icons.search_rounded,
                  color: AppTheme.textPrimary,
                  size: 26,
                ),
              ),
              IconButton(
                onPressed: () {},
                tooltip: '列表',
                icon: const Icon(
                  Icons.format_list_bulleted_rounded,
                  color: AppTheme.textPrimary,
                  size: 26,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in filters) ...[
                  _MobileAlbumFilterChip(
                    label: filter,
                    selected: filter == filters.first,
                  ),
                  const SizedBox(width: 18),
                ],
                IconButton(
                  onPressed: () {},
                  tooltip: '网格',
                  icon: const Icon(
                    Icons.grid_view_rounded,
                    color: AppTheme.textPrimary,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final mobileRecommendation =
        isMobile(context) && widget.mobileRecommendationLayout;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: mobileRecommendation
              ? _buildMobileRecommendationHeader(context)
              : Padding(
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
                padding: mobileRecommendation
                    ? const EdgeInsets.fromLTRB(20, 0, 20, 112)
                    : const EdgeInsets.fromLTRB(24, 0, 24, 24),
                sliver: SliverGrid(
                  gridDelegate: mobileRecommendation
                      ? const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.62,
                        )
                      : const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.80,
                        ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final album = list[index];
                    void onTap() {
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
                    }

                    if (mobileRecommendation) {
                      return _MobileRecommendationAlbumCard(
                        album: album,
                        onTap: onTap,
                      );
                    }
                    return _AlbumCard(album: album, onTap: onTap);
                  }, childCount: list.length),
                ),
              ),
      ],
    );
  }
}

class _MobileAlbumFilterChip extends StatelessWidget {
  const _MobileAlbumFilterChip({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: selected
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.mikuGreen),
              color: AppTheme.mikuGreen.withValues(alpha: 0.08),
            )
          : null,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: selected ? AppTheme.mikuGreen : AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _MobileRecommendationAlbumCard extends StatelessWidget {
  const _MobileRecommendationAlbumCard({
    required this.album,
    required this.onTap,
  });

  final Album album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.network(
                      album.coverUrl,
                      headers: ApiConfig.defaultHeaders,
                      fit: BoxFit.cover,
                      cacheWidth: 260,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.cardBg,
                        child: const Icon(
                          Icons.album_rounded,
                          color: AppTheme.textMuted,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 5,
                  bottom: 5,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            album.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            album.producerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
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
