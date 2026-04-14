import 'package:flutter/material.dart';

import '../../models/track.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

class PlaylistTrackRow extends StatefulWidget {
  const PlaylistTrackRow({
    super.key,
    required this.track,
    required this.baseUrl,
    required this.onTap,
    required this.onRemove,
    this.showDragHandle = false,
    this.isCurrentlyPlaying = false,
  });

  final Track track;
  final String baseUrl;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final bool showDragHandle;
  final bool isCurrentlyPlaying;

  @override
  State<PlaylistTrackRow> createState() => _PlaylistTrackRowState();
}

class _PlaylistTrackRowState extends State<PlaylistTrackRow> {
  bool _hovering = false;

  String get _vocalLine => widget.track.vocalLine;

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final isActive = widget.isCurrentlyPlaying;
    final mobile = isMobile(context);
    final vocalLine = _vocalLine;
    final titleColor =
        isActive || _hovering ? AppTheme.mikuGreen : AppTheme.textPrimary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white.withValues(alpha: 0.03),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: mobile ? 8 : 16, vertical: mobile ? 10 : 12),
            child: Row(
              children: [
                if (widget.showDragHandle) ...[
                  Semantics(
                    label: 'Drag to reorder',
                    child: const Icon(
                      Icons.drag_handle,
                      size: 20,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    '${widget.baseUrl}/api/stream/${track.id}/thumb',
                    width: mobile ? 40 : 48,
                    height: mobile ? 40 : 48,
                    cacheWidth: mobile ? 80 : 96,
                    cacheHeight: mobile ? 80 : 96,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      // Fallback to album cover if MV thumb not available
                      if (track.albumId > 0) {
                        return Image.network(
                          '${widget.baseUrl}/api/albums/${track.albumId}/cover',
                          width: mobile ? 40 : 48,
                          height: mobile ? 40 : 48,
                          cacheWidth: mobile ? 80 : 96,
                          cacheHeight: mobile ? 80 : 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: mobile ? 40 : 48,
                            height: mobile ? 40 : 48,
                            color: AppTheme.cardBg,
                            child: Icon(
                              Icons.music_note,
                              size: mobile ? 20 : 24,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        );
                      }
                      return Container(
                        width: mobile ? 40 : 48,
                        height: mobile ? 40 : 48,
                        color: AppTheme.cardBg,
                        child: Icon(
                          Icons.music_note,
                          size: mobile ? 20 : 24,
                          color: AppTheme.textMuted,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (vocalLine.isNotEmpty)
                        Text(
                          vocalLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                  ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (!mobile) ...[
                  SizedBox(
                    width: 48,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        track.durationFormatted,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: 'Add to favorites',
                    button: true,
                    child: IconButton(
                      onPressed: () {
                        // TODO: Replace with FavoriteButton in Task 18
                      },
                      style: IconButton.styleFrom(
                        iconSize: 20,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.all(8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ).copyWith(
                        overlayColor:
                            WidgetStateProperty.resolveWith<Color?>((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return AppTheme.mikuGreen.withValues(alpha: 0.12);
                          }
                          return null;
                        }),
                        foregroundColor:
                            WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return AppTheme.mikuGreen;
                          }
                          return AppTheme.textMuted;
                        }),
                      ),
                      icon: const Icon(Icons.favorite_border),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Semantics(
                  label: 'More options',
                  button: true,
                  child: PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_horiz,
                      color: AppTheme.textMuted,
                    ),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.all(8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onSelected: (value) {
                      if (value == 'remove') {
                        widget.onRemove();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.remove_circle_outline,
                                size: 18, color: AppTheme.textMuted),
                            SizedBox(width: 12),
                            Text('Remove from playlist'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
