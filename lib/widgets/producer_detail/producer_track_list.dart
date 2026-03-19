import 'package:flutter/material.dart';

import '../../models/track.dart';
import '../../theme/app_theme.dart';

class ProducerTrackList extends StatelessWidget {
  const ProducerTrackList({
    super.key,
    required this.tracks,
    required this.baseUrl,
    required this.onPlay,
  });

  final List<Track> tracks;
  final String baseUrl;
  final void Function(Track track, int index) onPlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${tracks.length} tracks',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textMuted,
              ),
        ),
        const SizedBox(height: 24),
        if (tracks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Text(
              'No tracks for this producer.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
          )
        else ...[
          const _ProducerTrackListHeader(),
          ...tracks.asMap().entries.map(
                (e) => ProducerTrackRow(
                  index: e.key + 1,
                  track: e.value,
                  baseUrl: baseUrl,
                  onPlay: () => onPlay(e.value, e.key),
                ),
              ),
        ],
      ],
    );
  }
}

class _ProducerTrackListHeader extends StatelessWidget {
  const _ProducerTrackListHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
              width: 32, child: Text('#', style: _trackHeaderStyle(context))),
          const SizedBox(width: 16),
          Expanded(
            flex: 6,
            child: Text('Title / Vocalists', style: _trackHeaderStyle(context)),
          ),
          Expanded(
            flex: 3,
            child: Center(
                child: Text('Tags / MV', style: _trackHeaderStyle(context))),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 48,
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  Icon(Icons.access_time, size: 12, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle? _trackHeaderStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.textMuted,
        );
  }
}

class ProducerTrackRow extends StatefulWidget {
  const ProducerTrackRow({
    super.key,
    required this.index,
    required this.track,
    required this.baseUrl,
    required this.onPlay,
  });

  final int index;
  final Track track;
  final String baseUrl;
  final VoidCallback onPlay;

  @override
  State<ProducerTrackRow> createState() => _ProducerTrackRowState();
}

class _ProducerTrackRowState extends State<ProducerTrackRow> {
  bool _hovering = false;

  String get _vocalLine => widget.track.vocalLine;

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final titleColor = _hovering ? AppTheme.mikuGreen : AppTheme.textPrimary;

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
                      if (!track.hasVideo && track.format.isEmpty && _hovering)
                        IconButton(
                          onPressed: () {},
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
