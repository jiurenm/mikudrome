import 'package:flutter/material.dart';

import '../../models/track.dart';
import '../../theme/app_theme.dart';
import 'download_mv_dialog.dart';

typedef AlbumTopMessage = void Function(String message,
    {required bool isError});

class AlbumTrackRow extends StatefulWidget {
  const AlbumTrackRow({
    super.key,
    required this.index,
    required this.track,
    required this.baseUrl,
    required this.onDownloadComplete,
    required this.onPlay,
    required this.showTopMessage,
    this.isCurrentlyPlaying = false,
  });

  final int index;
  final Track track;
  final String baseUrl;
  final VoidCallback onDownloadComplete;
  final VoidCallback onPlay;
  final AlbumTopMessage showTopMessage;
  final bool isCurrentlyPlaying;

  @override
  State<AlbumTrackRow> createState() => _AlbumTrackRowState();
}

class _AlbumTrackRowState extends State<AlbumTrackRow> {
  bool _hovering = false;

  void _openDownloadMvDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => DownloadMvDialog(
        trackTitle: widget.track.title,
        trackId: widget.track.id,
        baseUrl: widget.baseUrl,
        initialUrl: widget.track.source,
        onSuccess: () {
          widget.onDownloadComplete();
          if (context.mounted) {
            widget.showTopMessage('MV 已下载并关联到曲目', isError: false);
          }
        },
        onError: (message) {
          if (context.mounted) {
            widget.showTopMessage(message, isError: true);
          }
        },
      ),
    );
  }

  String get _vocalLine => widget.track.vocalLine;

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final index = widget.index;
    final isActive = widget.isCurrentlyPlaying;
    final numberColor =
        isActive || _hovering ? AppTheme.mikuGreen : AppTheme.textMuted;
    final titleColor =
        isActive || _hovering ? AppTheme.mikuGreen : AppTheme.textPrimary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPlay,
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white.withValues(alpha: 0.03),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: isActive
                      ? const Icon(Icons.graphic_eq,
                          size: 18, color: AppTheme.mikuGreen)
                      : Text(
                          track.displayNumber(index),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: numberColor,
                                  ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        track.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (_vocalLine.isNotEmpty)
                        Text(
                          _vocalLine,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                  ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (track.hasVideo)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.mikuGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppTheme.mikuGreen.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.movie,
                                  size: 10, color: AppTheme.mikuGreen),
                              const SizedBox(width: 4),
                              Text(
                                'LOCAL MV',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppTheme.mikuGreen,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      if (track.hasVideo && track.format.isNotEmpty)
                        const SizedBox(width: 12),
                      if (track.format.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Text(
                            track.format,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: const Color(0xFF9CA3AF),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                        ),
                      if (!track.hasVideo && _hovering) ...[
                        if (track.format.isNotEmpty) const SizedBox(width: 12),
                        IconButton(
                          onPressed: () => _openDownloadMvDialog(context),
                          style: IconButton.styleFrom(
                            foregroundColor: AppTheme.textMuted,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.all(8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ).copyWith(
                            overlayColor:
                                MaterialStateProperty.resolveWith<Color?>(
                                    (states) {
                              if (states.contains(MaterialState.hovered)) {
                                return AppTheme.textPrimary
                                    .withValues(alpha: 0.08);
                              }
                              return null;
                            }),
                            foregroundColor:
                                MaterialStateProperty.resolveWith<Color>(
                                    (states) {
                              if (states.contains(MaterialState.hovered)) {
                                return AppTheme.textPrimary;
                              }
                              return AppTheme.textMuted;
                            }),
                          ),
                          icon: const Icon(Icons.download, size: 20),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 48,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      track.durationFormatted,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
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
