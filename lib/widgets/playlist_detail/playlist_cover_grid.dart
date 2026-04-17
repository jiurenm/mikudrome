import 'package:flutter/material.dart';

import '../../models/playlist_item.dart';
import '../../theme/app_theme.dart';

class PlaylistCoverGrid extends StatelessWidget {
  const PlaylistCoverGrid({
    super.key,
    required this.items,
    required this.selectedItemId,
    required this.baseUrl,
    required this.showTitles,
    required this.onSelect,
    required this.onPlay,
  });

  final List<PlaylistItem> items;
  final int? selectedItemId;
  final String baseUrl;
  final bool showTitles;
  final ValueChanged<PlaylistItem> onSelect;
  final ValueChanged<PlaylistItem> onPlay;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = (width / 180).floor().clamp(1, 6);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: showTitles ? 0.82 : 0.98,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _PlaylistCoverCard(
              item: item,
              selected: item.id == selectedItemId,
              baseUrl: baseUrl,
              showTitle: showTitles,
              onSelect: () => onSelect(item),
              onPlay: () => onPlay(item),
            );
          },
        );
      },
    );
  }
}

class _PlaylistCoverCard extends StatefulWidget {
  const _PlaylistCoverCard({
    required this.item,
    required this.selected,
    required this.baseUrl,
    required this.showTitle,
    required this.onSelect,
    required this.onPlay,
  });

  final PlaylistItem item;
  final bool selected;
  final String baseUrl;
  final bool showTitle;
  final VoidCallback onSelect;
  final VoidCallback onPlay;

  @override
  State<_PlaylistCoverCard> createState() => _PlaylistCoverCardState();
}

class _PlaylistCoverCardState extends State<_PlaylistCoverCard> {
  bool _hovering = false;

  String get _coverUrl {
    final item = widget.item;
    if (item.coverMode == 'custom' && item.customCoverPath.trim().isNotEmpty) {
      return _resolveCoverUrl(item.customCoverPath);
    }
    if (item.coverMode == 'library' && item.cachedCoverUrl.trim().isNotEmpty) {
      return _resolveCoverUrl(item.cachedCoverUrl);
    }
    return '${widget.baseUrl}/api/stream/${item.track.id}/thumb';
  }

  String _resolveCoverUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('/')) {
      return '${widget.baseUrl}$url';
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final showOverlayTitle = !widget.showTitle && _hovering;
    final borderColor = widget.selected
        ? AppTheme.mikuGreen
        : Colors.white.withValues(alpha: _hovering ? 0.16 : 0.08);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('playlist-cover-card-${item.id}'),
          onTap: widget.onSelect,
          onDoubleTap: widget.onPlay,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: widget.selected ? 0.06 : (_hovering ? 0.04 : 0.02),
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: borderColor, width: widget.selected ? 1.6 : 1),
              boxShadow: [
                if (widget.selected)
                  BoxShadow(
                    color: AppTheme.mikuGreen.withValues(alpha: 0.14),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    key: ValueKey('playlist-cover-media-${item.id}'),
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            _coverUrl,
                            fit: BoxFit.cover,
                            cacheWidth: 420,
                            cacheHeight: 420,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.cardBg,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.music_note,
                                size: 36,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(
                                  alpha:
                                      _hovering || widget.selected ? 0.04 : 0,
                                ),
                                Colors.black.withValues(
                                  alpha: _hovering || widget.selected
                                      ? 0.38
                                      : 0.16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (showOverlayTitle)
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                item.track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      if (widget.selected)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              key: ValueKey(
                                'playlist-cover-card-selected-${item.id}',
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppTheme.mikuGreen
                                      .withValues(alpha: 0.45),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Center(
                        child: IgnorePointer(
                          ignoring: !_hovering && !widget.selected,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 140),
                            opacity: _hovering || widget.selected ? 1 : 0,
                            child: Material(
                              color: Colors.black.withValues(alpha: 0.38),
                              shape: const CircleBorder(),
                              child: InkWell(
                                key: ValueKey('playlist-cover-play-${item.id}'),
                                onTap: widget.onPlay,
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.showTitle) ...[
                  const SizedBox(height: 10),
                  Text(
                    item.track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: widget.selected
                              ? AppTheme.textPrimary
                              : AppTheme.textPrimary.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
