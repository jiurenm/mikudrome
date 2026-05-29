import 'package:flutter/material.dart';

import '../../models/track.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

class ProducerTrackList extends StatelessWidget {
  const ProducerTrackList({
    super.key,
    required this.tracks,
    required this.baseUrl,
    required this.onPlay,
    this.onPlayMv,
    this.useMobileLayout = false,
  });

  final List<Track> tracks;
  final String baseUrl;
  final void Function(Track track, int index) onPlay;
  final void Function(Track track, int index)? onPlayMv;
  final bool useMobileLayout;

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);

    if (mobile && useMobileLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${tracks.length} 首歌曲',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 24),
          if (tracks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Text(
                '还没有歌曲',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
              ),
            )
          else
            ...tracks.asMap().entries.map(
              (e) => _MobileProducerTrackRow(
                key: ValueKey('producer-track-mobile-row-${e.value.id}'),
                index: e.key + 1,
                track: e.value,
                onPlay: () => onPlay(e.value, e.key),
                onPlayMv: onPlayMv == null
                    ? null
                    : () => onPlayMv!(e.value, e.key),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${tracks.length} tracks',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 24),
        if (tracks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Text(
              'No tracks for this producer.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
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
              onPlayMv: onPlayMv == null
                  ? null
                  : () => onPlayMv!(e.value, e.key),
            ),
          ),
        ],
      ],
    );
  }
}

class _MobileProducerTrackRow extends StatelessWidget {
  const _MobileProducerTrackRow({
    super.key,
    required this.index,
    required this.track,
    required this.onPlay,
    this.onPlayMv,
  });

  final int index;
  final Track track;
  final VoidCallback onPlay;
  final VoidCallback? onPlayMv;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.textPrimary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.textPrimary.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.play_arrow,
                      size: 16,
                      color: AppTheme.textPrimary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.displayNumber(index),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            track.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          track.durationFormatted,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.textMuted,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ),
                    if (track.vocalLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        track.vocalLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (track.hasVideo)
                          _TrackBadge(
                            key: ValueKey('producer-track-row-mv-${track.id}'),
                            icon: Icons.movie,
                            label: 'MV',
                            foregroundColor: AppTheme.mikuGreen,
                            backgroundColor: AppTheme.mikuGreen.withValues(
                              alpha: 0.1,
                            ),
                            borderColor: AppTheme.mikuGreen.withValues(
                              alpha: 0.2,
                            ),
                            onTap: onPlayMv,
                          ),
                        if (track.format.isNotEmpty)
                          _TrackBadge(
                            label: track.format,
                            foregroundColor: const Color(0xFF9CA3AF),
                            backgroundColor: const Color(0xFF1F2937),
                            borderColor: Colors.white.withValues(alpha: 0.05),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackBadge extends StatelessWidget {
  const _TrackBadge({
    super.key,
    this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
    this.onTap,
  });

  final IconData? icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: foregroundColor),
            const SizedBox(width: 4),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foregroundColor,
                fontSize: 8,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return badge;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: badge,
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
            width: 32,
            child: Text('#', style: _trackHeaderStyle(context)),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 6,
            child: Text('Title / Vocalists', style: _trackHeaderStyle(context)),
          ),
          Expanded(
            flex: 3,
            child: Center(
              child: Text('Tags / MV', style: _trackHeaderStyle(context)),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 48,
            child: Align(
              alignment: Alignment.centerRight,
              child: Icon(
                Icons.access_time,
                size: 12,
                color: AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle? _trackHeaderStyle(BuildContext context) {
    return Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted);
  }
}

class ProducerTrackRow extends StatefulWidget {
  const ProducerTrackRow({
    super.key,
    required this.index,
    required this.track,
    required this.baseUrl,
    required this.onPlay,
    this.onPlayMv,
  });

  final int index;
  final Track track;
  final String baseUrl;
  final VoidCallback onPlay;
  final VoidCallback? onPlayMv;

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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
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
                        _TrackBadge(
                          key: ValueKey('producer-track-row-mv-${track.id}'),
                          icon: Icons.movie,
                          label: 'LOCAL MV',
                          foregroundColor: AppTheme.mikuGreen,
                          backgroundColor: AppTheme.mikuGreen.withValues(
                            alpha: 0.1,
                          ),
                          borderColor: AppTheme.mikuGreen.withValues(
                            alpha: 0.2,
                          ),
                          onTap: widget.onPlayMv,
                        ),
                      if (track.hasVideo && track.format.isNotEmpty)
                        const SizedBox(width: 12),
                      if (track.format.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Text(
                            track.format,
                            style: Theme.of(context).textTheme.labelSmall
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
                          style:
                              IconButton.styleFrom(
                                foregroundColor: AppTheme.textMuted,
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.all(8),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ).copyWith(
                                overlayColor:
                                    MaterialStateProperty.resolveWith<Color?>((
                                      states,
                                    ) {
                                      if (states.contains(
                                        MaterialState.hovered,
                                      )) {
                                        return AppTheme.textPrimary.withValues(
                                          alpha: 0.08,
                                        );
                                      }
                                      return null;
                                    }),
                                foregroundColor:
                                    MaterialStateProperty.resolveWith<Color>((
                                      states,
                                    ) {
                                      if (states.contains(
                                        MaterialState.hovered,
                                      )) {
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
