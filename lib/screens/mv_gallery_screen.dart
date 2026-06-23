import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/video.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/auto_scroll_text.dart';
import '../widgets/mobile_chrome_metrics.dart';

const double _mobileMiniPlayerHeight = 64;
const double _mobileGalleryBottomGutter = 16;

/// MV Gallery: video thumbnail grid from API, with search.
/// When [onVideoTap] is set, the caller handles navigation.
class MvGalleryScreen extends StatefulWidget {
  const MvGalleryScreen({super.key, this.onVideoTap, this.onMobileBack});

  final ValueChanged<Video>? onVideoTap;
  final VoidCallback? onMobileBack;

  @override
  State<MvGalleryScreen> createState() => _MvGalleryScreenState();
}

class _MvGalleryScreenState extends State<MvGalleryScreen> {
  List<Video> _videos = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiClient().getVideos();
      setState(() {
        _videos = list;
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

  List<Video> get _filteredVideos {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _videos;
    return _videos
        .where(
          (v) =>
              v.title.toLowerCase().contains(q) ||
              v.artist.toLowerCase().contains(q) ||
              v.vocal.toLowerCase().contains(q) ||
              v.composer.toLowerCase().contains(q),
        )
        .toList();
  }

  double _mobileGridBottomPadding(BuildContext context) {
    return _mobileMiniPlayerHeight +
        kPortraitBottomNavigationHeight +
        MediaQuery.paddingOf(context).bottom +
        _mobileGalleryBottomGutter;
  }

  Widget _buildGalleryHeader(
    BuildContext context,
    int count, {
    required bool compact,
  }) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MV Gallery',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Total $count videos',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
        ),
      ],
    );
    final search = TextField(
      key: const ValueKey('mv-gallery-search'),
      controller: _searchController,
      decoration: const InputDecoration(
        hintText: 'Search title, artist...',
        prefixIcon: Icon(Icons.search, color: AppTheme.textMuted, size: 18),
      ),
      style: const TextStyle(fontSize: 14),
      onChanged: (_) => setState(() {}),
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, const SizedBox(height: 16), search],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        title,
        SizedBox(width: 264, child: search),
      ],
    );
  }

  Widget _buildVideoGrid(
    BuildContext context,
    List<Video> list, {
    required bool mobile,
  }) {
    if (list.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text(
            'No videos found. Add media with MV files and run the server.',
          ),
        ),
      );
    }
    return SliverPadding(
      key: const ValueKey('mv-gallery-grid-padding'),
      padding: mobile
          ? EdgeInsets.fromLTRB(16, 0, 16, _mobileGridBottomPadding(context))
          : const EdgeInsets.fromLTRB(24, 0, 24, 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 280,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final video = list[index];
          return _MvCard(
            video: video,
            onTap: () => widget.onVideoTap?.call(video),
          );
        }, childCount: list.length),
      ),
    );
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
              FilledButton(onPressed: _loadVideos, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final list = _filteredVideos;
    final mobile = isMobile(context);
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.onMobileBack != null) ...[
                  IconButton(
                    onPressed: widget.onMobileBack,
                    tooltip: '返回',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppTheme.textPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                _buildGalleryHeader(context, list.length, compact: true),
              ],
            ),
          ),
          Expanded(
            child: CustomScrollView(
              key: const ValueKey('mv-gallery-scroll'),
              slivers: [_buildVideoGrid(context, list, mobile: true)],
            ),
          ),
        ],
      );
    }
    return CustomScrollView(
      key: const ValueKey('mv-gallery-scroll'),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _buildGalleryHeader(
                  context,
                  list.length,
                  compact: constraints.maxWidth < 620,
                );
              },
            ),
          ),
        ),
        _buildVideoGrid(context, list, mobile: false),
      ],
    );
  }
}

class _MvCard extends StatefulWidget {
  const _MvCard({required this.video, required this.onTap});

  final Video video;
  final VoidCallback onTap;

  @override
  State<_MvCard> createState() => _MvCardState();
}

class _MvCardState extends State<_MvCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final thumbUrl = ApiClient().videoThumbUrl(widget.video.id);
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
                  return Stack(
                    clipBehavior: Clip.antiAlias,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          thumbUrl,
                          headers: ApiConfig.defaultHeaders,
                          width: c.maxWidth,
                          height: c.maxHeight,
                          fit: BoxFit.cover,
                          cacheWidth: 560,
                          errorBuilder: (_, __, ___) => Container(
                            width: c.maxWidth,
                            height: c.maxHeight,
                            color: AppTheme.cardBg,
                            child: const Icon(
                              Icons.videocam,
                              color: AppTheme.textMuted,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                      // Duration badge
                      if (widget.video.durationSeconds > 0)
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.video.durationFormatted,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      // Hover overlay
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
                text: widget.video.displayTitle,
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
                text: widget.video.vocalLine,
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
