import 'dart:async';

import 'package:flutter/material.dart';

import '../models/timed_lyric_line.dart';
import '../models/track.dart';
import '../screens/library_home_screen.dart';
import '../theme/app_theme.dart';

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
      onSelectionChanged: (selection) {
        final nextMode = selection.first;
        if (nextMode == PlaybackMode.video && !canUseVideoMode) return;
        onChanged(nextMode);
      },
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
    required this.showQueue,
    required this.onClose,
    required this.onChangedMode,
    required this.onToggleQueue,
    required this.onEnterFullscreen,
  });

  final String contextLabel;
  final PlaybackMode playbackMode;
  final bool canUseVideoMode;
  final bool showQueue;
  final VoidCallback onClose;
  final ValueChanged<PlaybackMode> onChangedMode;
  final VoidCallback onToggleQueue;
  final VoidCallback? onEnterFullscreen;

  bool get _isVideoMode => playbackMode == PlaybackMode.video;

  @override
  Widget build(BuildContext context) {
    final modeText = _isVideoMode ? 'Mode: MV Playback' : 'Mode: Audio Playback';
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
          const SizedBox(width: 8),
          IconButton(
            onPressed: onToggleQueue,
            icon: Icon(
              showQueue ? Icons.queue_music : Icons.queue_music_outlined,
              color: showQueue ? AppTheme.mikuGreen : AppTheme.textMuted,
            ),
            tooltip: showQueue ? 'Hide queue' : 'Show queue',
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

class QueuePanel extends StatelessWidget {
  const QueuePanel({
    super.key,
    required this.contextLabel,
    required this.queue,
    required this.currentIndex,
    required this.isVideoMode,
    required this.coverUrlForTrack,
    required this.onSelectTrack,
  });

  final String contextLabel;
  final List<Track> queue;
  final int currentIndex;
  final bool isVideoMode;
  final String Function(Track track) coverUrlForTrack;
  final ValueChanged<int> onSelectTrack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isVideoMode ? 320 : 280,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey.shade800)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                contextLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              Text(
                '${currentIndex + 1}/${queue.length}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.mikuGreen,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final track = queue[index];
                final subtitle = track.vocalLine.isNotEmpty
                    ? track.vocalLine
                    : 'Unknown credits';
                return TrackListItem(
                  track: track,
                  subtitle: subtitle,
                  coverUrl: coverUrlForTrack(track),
                  isActive: index == currentIndex,
                  onTap: () => onSelectTrack(index),
                );
              },
            ),
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

class TrackInfoSection extends StatelessWidget {
  const TrackInfoSection({
    super.key,
    required this.track,
  });

  final Track track;

  @override
  Widget build(BuildContext context) {
    final vocalists = track.vocalists;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 10,
            children: [
              CreditColumn(
                label: 'Composer',
                value: track.composerDisplay,
              ),
              Container(
                width: 1,
                height: 28,
                color: Colors.grey.shade700,
              ),
              CreditColumn(
                label: 'Lyricist',
                value: track.lyricistDisplay,
              ),
              Container(
                width: 1,
                height: 28,
                color: Colors.grey.shade700,
              ),
              VocalBadgeColumn(vocalists: vocalists),
            ],
          ),
        ],
      ),
    );
  }
}

class LyricsSection extends StatefulWidget {
  const LyricsSection({
    super.key,
    required this.lyrics,
    this.timedLyrics = const [],
    this.activeIndex = -1,
  });

  final String lyrics;
  final List<TimedLyricLine> timedLyrics;
  final int activeIndex;

  @override
  State<LyricsSection> createState() => _LyricsSectionState();
}

class _LyricsSectionState extends State<LyricsSection> {
  static const _lineSpacing = 8.0;
  static const _lyricsAnimationDuration = Duration(milliseconds: 200);
  static const _lyricsAnimationCurve = Curves.easeOutCubic;

  late final ScrollController _scrollController;
  final Map<int, GlobalKey> _lineKeys = <int, GlobalKey>{};
  static const _highlightSyncDelay = Duration(milliseconds: 40);

  int _displayedActiveIndex = -1;
  int _lastAutoScrolledIndex = -1;
  bool _isAutoScrolling = false;
  int? _pendingAutoScrollIndex;
  Timer? _highlightSyncTimer;

  bool get _hasLyrics => widget.lyrics.trim().isNotEmpty;
  bool get _hasTimedLyrics => widget.timedLyrics.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _displayedActiveIndex = widget.activeIndex;
    _scheduleAutoScrollToActive(force: true);
  }

  @override
  void didUpdateWidget(covariant LyricsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasTimedLyrics) {
      _lineKeys.clear();
      _displayedActiveIndex = -1;
      _lastAutoScrolledIndex = -1;
      _pendingAutoScrollIndex = null;
      _isAutoScrolling = false;
      _highlightSyncTimer?.cancel();
      return;
    }

    if (oldWidget.timedLyrics != widget.timedLyrics) {
      _lineKeys.clear();
      _displayedActiveIndex = widget.activeIndex;
      _lastAutoScrolledIndex = -1;
      _pendingAutoScrollIndex = null;
      _isAutoScrolling = false;
      _highlightSyncTimer?.cancel();
      _scheduleAutoScrollToActive(force: true);
      return;
    }

    if (widget.activeIndex != oldWidget.activeIndex) {
      _syncDisplayedActiveIndex();
      _scheduleAutoScrollToActive();
    }
  }

  @override
  void dispose() {
    _highlightSyncTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncDisplayedActiveIndex() {
    _highlightSyncTimer?.cancel();

    final targetIndex = widget.activeIndex;
    if (!mounted) return;

    if (_isAutoScrolling) {
      if (_displayedActiveIndex == targetIndex) return;
      setState(() {
        _displayedActiveIndex = targetIndex;
      });
      return;
    }

    _highlightSyncTimer = Timer(_highlightSyncDelay, () {
      if (!mounted || _displayedActiveIndex == targetIndex) return;
      setState(() {
        _displayedActiveIndex = targetIndex;
      });
    });
  }

  GlobalKey _keyForLine(int index) => _lineKeys.putIfAbsent(index, GlobalKey.new);

  double _approximateOffsetForIndex(int index) {
    if (!_scrollController.hasClients || index < 0 || widget.timedLyrics.isEmpty) {
      return 0;
    }
    const approxLineHeight = 76.0;
    final target = (index * approxLineHeight)
        .clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        )
        .toDouble();
    return target;
  }

  void _scheduleAutoScrollToActive({bool force = false}) {
    if (!_hasTimedLyrics) return;

    final activeIndex = widget.activeIndex;
    if (activeIndex < 0 || activeIndex >= widget.timedLyrics.length) return;

    if (_isAutoScrolling) {
      _pendingAutoScrollIndex = activeIndex;
      return;
    }

    final indexGap = _lastAutoScrolledIndex >= 0
        ? (activeIndex - _lastAutoScrolledIndex).abs()
        : null;
    if (!force && indexGap != null && indexGap <= 1) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final targetIndex = widget.activeIndex;
      if (targetIndex < 0 || targetIndex >= widget.timedLyrics.length) return;

      final lineContext = _lineKeys[targetIndex]?.currentContext;
      if (lineContext == null) {
        final approximateOffset = _approximateOffsetForIndex(targetIndex);
        _isAutoScrolling = true;
        _scrollController
            .animateTo(
              approximateOffset,
              duration: _lyricsAnimationDuration,
              curve: _lyricsAnimationCurve,
            )
            .whenComplete(() {
              if (!mounted) return;
              _isAutoScrolling = false;
              _pendingAutoScrollIndex = targetIndex;
              _scheduleAutoScrollToActive(force: true);
            });
        return;
      }

      final renderObject = lineContext.findRenderObject() as RenderBox?;
      final scrollableState = Scrollable.of(lineContext);
      final viewport = scrollableState.context.findRenderObject() as RenderBox?;
      if (renderObject == null || viewport == null) return;

      final topLeft = renderObject.localToGlobal(Offset.zero, ancestor: viewport);
      final lineTop = topLeft.dy;
      final lineBottom = lineTop + renderObject.size.height;
      final viewportHeight = viewport.size.height;
      final safeTop = viewportHeight * 0.22;
      final safeBottom = viewportHeight * 0.78;
      final isWithinSafeZone = lineTop >= safeTop && lineBottom <= safeBottom;

      if (!force && isWithinSafeZone) {
        _lastAutoScrolledIndex = targetIndex;
        return;
      }

      final targetOffset = (_scrollController.offset +
              (lineTop + lineBottom) / 2 -
              viewportHeight * 0.42)
          .clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          );

      _isAutoScrolling = true;
      _scrollController
          .animateTo(
            targetOffset,
            duration: _lyricsAnimationDuration,
            curve: _lyricsAnimationCurve,
          )
          .whenComplete(() {
            if (!mounted) return;
            _isAutoScrolling = false;
            _lastAutoScrolledIndex = targetIndex;
            final pendingIndex = _pendingAutoScrollIndex;
            _pendingAutoScrollIndex = null;
            if (pendingIndex != null && pendingIndex != _lastAutoScrolledIndex) {
              _scheduleAutoScrollToActive(force: true);
            }
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: !_hasLyrics
          ? Align(
              alignment: Alignment.topLeft,
              child: Text(
                'No lyrics available',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            )
          : _hasTimedLyrics
              ? Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: widget.timedLyrics.length,
                    itemBuilder: (context, index) {
                      final line = widget.timedLyrics[index];
                      final distance = _displayedActiveIndex < 0
                          ? null
                          : (index - _displayedActiveIndex).abs();
                      final colorAlpha = switch (distance) {
                        null => 0.82,
                        0 => 1.0,
                        1 => 0.72,
                        2 => 0.56,
                        _ => 0.36,
                      };
                      final fontWeight = switch (distance) {
                        null => FontWeight.w400,
                        0 => FontWeight.w600,
                        1 => FontWeight.w500,
                        _ => FontWeight.w400,
                      };

                      return Padding(
                        padding: EdgeInsets.only(top: index == 0 ? 0 : _lineSpacing),
                        child: _LyricLineItem(
                          lineKey: _keyForLine(index),
                          line: line,
                          isActive: index == _displayedActiveIndex,
                          colorAlpha: colorAlpha,
                          inactiveFontWeight: fontWeight,
                          animationDuration: _lyricsAnimationDuration,
                          animationCurve: _lyricsAnimationCurve,
                        ),
                      );
                    },
                  ),
                )
              : Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: SelectableText(
                      widget.lyrics.trim(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            height: 1.7,
                          ),
                    ),
                  ),
                ),
    );
  }
}

class _LyricLineItem extends StatelessWidget {
  const _LyricLineItem({
    required this.lineKey,
    required this.line,
    required this.isActive,
    required this.colorAlpha,
    required this.inactiveFontWeight,
    required this.animationDuration,
    required this.animationCurve,
  });

  static const _primaryFontSize = 22.0;
  static const _translationFontSize = 15.0;

  final Key lineKey;
  final TimedLyricLine line;
  final bool isActive;
  final double colorAlpha;
  final FontWeight inactiveFontWeight;
  final Duration animationDuration;
  final Curve animationCurve;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyLarge!;
    return Container(
      key: lineKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var textIndex = 0; textIndex < line.texts.length; textIndex++)
            TweenAnimationBuilder<Color?>(
              duration: animationDuration,
              curve: animationCurve,
              tween: ColorTween(
                end: isActive
                    ? (textIndex == 0
                        ? AppTheme.mikuGreen
                        : AppTheme.mikuGreen.withValues(alpha: 0.62))
                    : AppTheme.textPrimary.withValues(
                        alpha: textIndex == 0 ? colorAlpha : colorAlpha * 0.52,
                      ),
              ),
              builder: (context, color, child) {
                return Text(
                  line.texts[textIndex],
                  style: baseStyle.copyWith(
                    color: color,
                    height: line.texts.length > 1
                        ? (textIndex == 0 ? 1.58 : 1.18)
                        : 1.7,
                    fontWeight: isActive
                        ? (textIndex == 0 ? FontWeight.w700 : FontWeight.w400)
                        : inactiveFontWeight,
                    fontSize:
                        textIndex == 0 ? _primaryFontSize : _translationFontSize,
                  ),
                );
              },
            ),
        ],
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
                      color: isActive
                          ? AppTheme.mikuGreen
                          : AppTheme.textPrimary,
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
