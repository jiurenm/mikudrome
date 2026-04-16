import 'package:flutter/material.dart';

import '../../models/playlist_item.dart';
import '../../models/track.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

class PlaylistTrackRow extends StatefulWidget {
  const PlaylistTrackRow({
    super.key,
    required this.item,
    required this.baseUrl,
    required this.onTap,
    this.onEdit,
    this.onRemove,
    this.showDragHandle = false,
    this.dragHandle,
    this.isCurrentlyPlaying = false,
  }) : track = null;

  const PlaylistTrackRow.track({
    super.key,
    required this.track,
    required this.baseUrl,
    required this.onTap,
    this.onEdit,
    this.onRemove,
    this.showDragHandle = false,
    this.dragHandle,
    this.isCurrentlyPlaying = false,
  }) : item = null;

  final PlaylistItem? item;
  final Track? track;
  final String baseUrl;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
  final bool showDragHandle;
  final Widget? dragHandle;
  final bool isCurrentlyPlaying;

  @override
  State<PlaylistTrackRow> createState() => _PlaylistTrackRowState();
}

class _PlaylistTrackRowState extends State<PlaylistTrackRow> {
  bool _hovering = false;

  Track get _track => widget.item?.track ?? widget.track!;
  String get _vocalLine => _track.vocalLine;
  String get _note => widget.item?.note.trim() ?? '';
  String get _coverUrl {
    final item = widget.item;
    if (item != null) {
      if (item.coverMode == 'custom' &&
          item.customCoverPath.trim().isNotEmpty) {
        return _resolveCoverUrl(item.customCoverPath);
      }
      if (item.coverMode == 'library' &&
          item.cachedCoverUrl.trim().isNotEmpty) {
        return _resolveCoverUrl(item.cachedCoverUrl);
      }
    }
    return '${widget.baseUrl}/api/stream/${_track.id}/thumb';
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

  Widget _buildTitleBlock({
    required BuildContext context,
    required Track track,
    required Color titleColor,
    required String vocalLine,
    required String note,
    required bool mobile,
  }) {
    return Column(
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
        if (mobile && note.isNotEmpty)
          Text(
            note,
            key: const ValueKey('playlist-track-row-note-mobile'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
        if (vocalLine.isNotEmpty)
          Text(
            vocalLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
          ),
      ],
    );
  }

  Widget _buildDesktopNoteColumn(BuildContext context, String note) {
    return Align(
      alignment: Alignment.centerLeft,
      child: note.isEmpty
          ? const SizedBox.shrink()
          : Text(
              note,
              key: const ValueKey('playlist-track-row-note-desktop'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
    );
  }

  Widget _buildDesktopContentBlock({
    required BuildContext context,
    required Track track,
    required Color titleColor,
    required String vocalLine,
    required String note,
  }) {
    return Expanded(
      child: Row(
        children: [
          Flexible(
            flex: 2,
            child: _buildTitleBlock(
              context: context,
              track: track,
              titleColor: titleColor,
              vocalLine: vocalLine,
              note: note,
              mobile: false,
            ),
          ),
          const SizedBox(width: 24),
          Flexible(
            flex: 3,
            child: _buildDesktopNoteColumn(context, note),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final track = _track;
    final isActive = widget.isCurrentlyPlaying;
    final mobile = isMobile(context);
    final vocalLine = _vocalLine;
    final note = _note;
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
                  widget.dragHandle ??
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
                    _coverUrl,
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
                if (mobile)
                  Expanded(
                    child: _buildTitleBlock(
                      context: context,
                      track: track,
                      titleColor: titleColor,
                      vocalLine: vocalLine,
                      note: note,
                      mobile: true,
                    ),
                  )
                else
                  _buildDesktopContentBlock(
                    context: context,
                    track: track,
                    titleColor: titleColor,
                    vocalLine: vocalLine,
                    note: note,
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
                ],
                if (widget.onRemove != null)
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
                          widget.onRemove?.call();
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
                if (widget.onEdit != null)
                  IconButton(
                    onPressed: widget.onEdit,
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppTheme.textMuted,
                    ),
                    tooltip: 'Edit playlist item',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
