import 'package:flutter/material.dart';

import '../models/track.dart';
import '../screens/library_home_screen.dart';
import '../theme/app_theme.dart';

export 'player/lyrics_section.dart';
export 'player/queue_panel.dart';
export 'player/track_info_section.dart';

const _trackInfoColumnWidth = 100.0;

class ModeSwitcher extends StatelessWidget {
  const ModeSwitcher({
    super.key,
    required this.playbackMode,
    required this.canUseVideoMode,
    required this.onChanged,
  });

  final PlaybackMode playbackMode;
  final bool canUseVideoMode;
  final ValueChanged<PlaybackMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PlaybackMode>(
      segments: const [
        ButtonSegment<PlaybackMode>(
          value: PlaybackMode.video,
          label: Text('MV'),
          icon: Icon(Icons.movie),
        ),
        ButtonSegment<PlaybackMode>(
          value: PlaybackMode.audio,
          label: Text('Audio'),
          icon: Icon(Icons.music_note),
        ),
      ],
      selected: {playbackMode},
      onSelectionChanged: canUseVideoMode ? (selection) {
        final nextMode = selection.first;
        onChanged(nextMode);
      } : null,
      showSelectedIcon: false,
    );
  }
}

class CreditColumn extends StatelessWidget {
  const CreditColumn({
    super.key,
    required this.label,
    required this.value,
    this.valueWidth = _trackInfoColumnWidth,
  });

  final String label;
  final String value;
  final double valueWidth;

  @override
  Widget build(BuildContext context) {
    const valueStyle = TextStyle(
      fontSize: 18,
      color: AppTheme.mikuGreen,
      fontWeight: FontWeight.w500,
    );

    return SizedBox(
      width: valueWidth,
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textMuted,
                  letterSpacing: 1.5,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Tooltip(
            message: value,
            waitDuration: const Duration(milliseconds: 250),
            child: _AutoScrollText(
              text: value,
              width: valueWidth,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoScrollText extends StatefulWidget {
  const _AutoScrollText({
    required this.text,
    required this.width,
    required this.style,
  });

  final String text;
  final double width;
  final TextStyle style;

  @override
  State<_AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<_AutoScrollText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double>? _offsetAnimation;
  double _overflow = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void didUpdateWidget(covariant _AutoScrollText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.width != widget.width ||
        oldWidget.style != widget.style) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
    }
  }

  void _recalculate() {
    if (!mounted) return;
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();

    final nextOverflow =
        (textPainter.width - widget.width).clamp(0, double.infinity).toDouble();

    if ((nextOverflow - _overflow).abs() < 0.5) return;

    _overflow = nextOverflow;

    if (_overflow <= 0) {
      _offsetAnimation = null;
      _controller.stop();
      _controller.reset();
      if (mounted) setState(() {});
      return;
    }

    final travelMs = ((_overflow / 42) * 1000).clamp(1400, 8000).round();
    const pauseMs = 650;

    _controller.duration = Duration(milliseconds: travelMs * 2 + pauseMs * 2);
    _offsetAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(0),
        weight: pauseMs.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: _overflow),
        weight: travelMs.toDouble(),
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(_overflow),
        weight: pauseMs.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: _overflow, end: 0),
        weight: travelMs.toDouble(),
      ),
    ]).animate(_controller);

    _controller
      ..reset()
      ..repeat();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      widget.text,
      style: widget.style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      textAlign: TextAlign.center,
    );

    if (_overflow <= 0 || _offsetAnimation == null) {
      return SizedBox(
        width: widget.width,
        child: textWidget,
      );
    }

    return SizedBox(
      width: widget.width,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final dx = _offsetAnimation?.value ?? 0;
            return Transform.translate(
              offset: Offset(-dx, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: child,
              ),
            );
          },
          child: Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
      ),
    );
  }
}

class VocalBadgeColumn extends StatelessWidget {
  const VocalBadgeColumn({
    super.key,
    required this.vocalists,
    this.columnWidth = _trackInfoColumnWidth,
  });

  final List<String> vocalists;
  final double columnWidth;

  @override
  Widget build(BuildContext context) {
    final values = vocalists.isNotEmpty ? vocalists : const ['Unknown'];
    final vocalText = values.join(', ');
    const vocalStyle = TextStyle(
      fontSize: 18,
      color: AppTheme.mikuGreen,
      fontWeight: FontWeight.w500,
    );

    return SizedBox(
      width: columnWidth,
      child: Column(
        children: [
          Text(
            'Vocalists',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textMuted,
                  letterSpacing: 1.5,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Tooltip(
            message: vocalText,
            waitDuration: const Duration(milliseconds: 250),
            child: _AutoScrollText(
              text: vocalText,
              width: columnWidth,
              style: vocalStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class VocalBadge extends StatelessWidget {
  const VocalBadge({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.mikuGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.mikuGreen),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.mikuGreen,
        ),
      ),
    );
  }
}

class PlayerHeader extends StatelessWidget {
  const PlayerHeader({
    super.key,
    required this.contextLabel,
    required this.playbackMode,
    required this.canUseVideoMode,
    required this.onClose,
    required this.onChangedMode,
    required this.onEnterFullscreen,
  });

  final String contextLabel;
  final PlaybackMode playbackMode;
  final bool canUseVideoMode;
  final VoidCallback onClose;
  final ValueChanged<PlaybackMode> onChangedMode;
  final VoidCallback? onEnterFullscreen;

  bool get _isVideoMode => playbackMode == PlaybackMode.video;

  @override
  Widget build(BuildContext context) {
    final modeText =
        _isVideoMode ? 'Mode: MV Playback' : 'Mode: Audio Playback';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            tooltip: 'Back',
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.mikuGreen,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    _isVideoMode ? Icons.movie : Icons.music_note,
                    color: Colors.black,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'MIKUDROME',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: AppTheme.mikuGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    contextLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (!_isVideoMode) ...[
            Text(
              modeText,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
            const SizedBox(width: 10),
          ],
          ModeSwitcher(
            playbackMode: playbackMode,
            canUseVideoMode: canUseVideoMode,
            onChanged: onChangedMode,
          ),
          if (_isVideoMode)
            IconButton(
              onPressed: onEnterFullscreen,
              icon: const Icon(Icons.fullscreen, color: AppTheme.textMuted),
              tooltip: 'Fullscreen',
            ),
        ],
      ),
    );
  }
}

class AudioArtworkCard extends StatelessWidget {
  const AudioArtworkCard({
    super.key,
    required this.albumCoverUrl,
    required this.placeholder,
  });

  final String albumCoverUrl;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: albumCoverUrl.isNotEmpty
                  ? Image.network(
                      albumCoverUrl,
                      width: 280,
                      height: 280,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => placeholder,
                    )
                  : placeholder,
            ),
          ],
        ),
      ),
    );
  }
}

class VideoModeDetails extends StatelessWidget {
  const VideoModeDetails({
    super.key,
    required this.title,
    required this.subtitle,
    required this.showSideInfo,
  });

  final String title;
  final String subtitle;
  final bool showSideInfo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                  maxLines: showSideInfo ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!showSideInfo) ...[
            const SizedBox(width: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TrackListItem extends StatelessWidget {
  const TrackListItem({
    super.key,
    required this.track,
    required this.subtitle,
    required this.coverUrl,
    required this.isActive,
    required this.onTap,
  });

  final Track track;
  final String subtitle;
  final String coverUrl;
  final bool isActive;
  final VoidCallback onTap;

  Widget _coverPlaceholder() => Container(
        width: 48,
        height: 48,
        color: AppTheme.cardBg,
        alignment: Alignment.center,
        child: Icon(
          track.hasVideo ? Icons.movie : Icons.music_note,
          color: track.hasVideo ? AppTheme.mikuGreen : AppTheme.textMuted,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withValues(alpha: 0.03) : null,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? const Border(
                  left: BorderSide(color: AppTheme.mikuGreen, width: 4),
                )
              : null,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  if (coverUrl.isNotEmpty)
                    Image.network(
                      coverUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _coverPlaceholder(),
                    )
                  else
                    _coverPlaceholder(),
                  if (track.hasVideo)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'MV',
                          style: TextStyle(
                            color: AppTheme.mikuGreen,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color:
                          isActive ? AppTheme.mikuGreen : AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle.isNotEmpty ? subtitle : 'Unknown credits',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (track.hasVideo)
                  const Icon(Icons.movie, size: 14, color: AppTheme.mikuGreen)
                else
                  const Icon(Icons.music_note,
                      size: 14, color: AppTheme.textMuted),
                const SizedBox(height: 4),
                Text(
                  track.durationFormatted,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
