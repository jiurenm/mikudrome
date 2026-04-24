import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../models/timed_lyric_line.dart';
import '../../theme/app_theme.dart';

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
  static const _desktopLyricsBreakpoint = 600.0;
  static const _lineSpacing = 18.0;
  static const _mobileLineSpacing = 8.0;
  static const _stageAnimationDuration = Duration(milliseconds: 320);
  static const _stageAnimationCurve = Curves.easeInOut;
  static const _stageAnchor = 0.49;
  static const _estimatedLineHeight = 74.0;
  static const _lyricsAnimationDuration = Duration(milliseconds: 200);
  static const _lyricsAnimationCurve = Curves.easeOutCubic;

  late final ScrollController _scrollController;
  final Map<int, GlobalKey> _lineKeys = <int, GlobalKey>{};
  final Map<int, double> _lineHeights = <int, double>{};
  final Map<int, double> _pendingLineHeights = <int, double>{};
  static const _highlightSyncDelay = Duration(milliseconds: 40);

  int _displayedActiveIndex = -1;
  double _stageOffset = 0;
  double? _timedLyricsWidth;
  int _lastAutoScrolledIndex = -1;
  bool _isAutoScrolling = false;
  bool _lineHeightFlushScheduled = false;
  int? _pendingAutoScrollIndex;
  Timer? _highlightSyncTimer;

  bool get _hasLyrics => widget.lyrics.trim().isNotEmpty;
  bool get _hasTimedLyrics => widget.timedLyrics.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _displayedActiveIndex = widget.activeIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _usesDesktopStageInCurrentContext()) return;
      _scheduleAutoScrollToActive(force: true);
    });
  }

  @override
  void didUpdateWidget(covariant LyricsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final usesDesktopStage = _usesDesktopStageInCurrentContext();
    if (!_hasTimedLyrics) {
      _lineKeys.clear();
      _lineHeights.clear();
      _pendingLineHeights.clear();
      _lineHeightFlushScheduled = false;
      _displayedActiveIndex = -1;
      _stageOffset = 0;
      _lastAutoScrolledIndex = -1;
      _pendingAutoScrollIndex = null;
      _isAutoScrolling = false;
      _highlightSyncTimer?.cancel();
      return;
    }

    if (oldWidget.timedLyrics != widget.timedLyrics) {
      _lineKeys.clear();
      _lineHeights.clear();
      _pendingLineHeights.clear();
      _lineHeightFlushScheduled = false;
      _displayedActiveIndex = widget.activeIndex;
      _stageOffset = 0;
      _lastAutoScrolledIndex = -1;
      _pendingAutoScrollIndex = null;
      _isAutoScrolling = false;
      _highlightSyncTimer?.cancel();
      // Jump to top instantly on track change — no visible scroll-back.
      if (!usesDesktopStage && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      if (!usesDesktopStage) {
        _scheduleAutoScrollToActive(force: true);
      }
      return;
    }

    if (widget.activeIndex != oldWidget.activeIndex) {
      _syncDisplayedActiveIndex(immediate: usesDesktopStage);
      if (!usesDesktopStage) {
        _scheduleAutoScrollToActive();
      }
    }
  }

  @override
  void dispose() {
    _highlightSyncTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncDisplayedActiveIndex({bool immediate = false}) {
    _highlightSyncTimer?.cancel();

    final targetIndex = widget.activeIndex;
    if (!mounted) return;
    if (_displayedActiveIndex == targetIndex) return;

    if (immediate || _usesDesktopStageInCurrentContext()) {
      setState(() {
        _displayedActiveIndex = targetIndex;
      });
      return;
    }

    if (_isAutoScrolling) {
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

  GlobalKey _keyForLine(int index) =>
      _lineKeys.putIfAbsent(index, GlobalKey.new);

  bool _usesDesktopStageInCurrentContext() {
    final width = _timedLyricsWidth ?? MediaQuery.maybeOf(context)?.size.width;
    if (width == null) return false;
    return _hasTimedLyrics && _isDesktopTimedLyrics(width);
  }

  void _queueLineHeight(int index, double height) {
    final currentHeight = _pendingLineHeights[index] ?? _lineHeights[index];
    if (currentHeight != null && (currentHeight - height).abs() < 0.5) {
      return;
    }

    _pendingLineHeights[index] = height;
    if (_lineHeightFlushScheduled) return;

    _lineHeightFlushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lineHeightFlushScheduled = false;
      if (!mounted || _pendingLineHeights.isEmpty) return;

      var hasChanges = false;
      for (final entry in _pendingLineHeights.entries) {
        final currentHeight = _lineHeights[entry.key];
        if (currentHeight != null &&
            (currentHeight - entry.value).abs() < 0.5) {
          continue;
        }
        _lineHeights[entry.key] = entry.value;
        hasChanges = true;
      }
      _pendingLineHeights.clear();

      if (!hasChanges) return;
      setState(() {});
    });
  }

  _StageMetrics _buildStageMetrics() {
    final lineTops = <double>[];
    var top = 0.0;
    for (var index = 0; index < widget.timedLyrics.length; index++) {
      lineTops.add(top);
      top += (_lineHeights[index] ?? _estimatedLineHeight) + _lineSpacing;
    }
    final contentHeight = lineTops.isEmpty ? 0.0 : top - _lineSpacing;
    return _StageMetrics(lineTops: lineTops, contentHeight: contentHeight);
  }

  double _computeStageOffset(
    _StageMetrics metrics,
    double viewportHeight,
  ) {
    final activeIndex = _displayedActiveIndex;
    if (activeIndex < 0 || activeIndex >= widget.timedLyrics.length) return 0;

    final lineTop = metrics.lineTops[activeIndex];
    final lineHeight = _lineHeights[activeIndex] ?? _estimatedLineHeight;
    final lineCenter = lineTop + lineHeight / 2;
    return viewportHeight * _stageAnchor - lineCenter;
  }

  void _syncStageOffset(_StageMetrics metrics, double viewportHeight) {
    final nextOffset = _computeStageOffset(metrics, viewportHeight);
    if ((_stageOffset - nextOffset).abs() < 0.5) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final refreshedMetrics = _buildStageMetrics();
      final refreshedOffset = _computeStageOffset(
        refreshedMetrics,
        viewportHeight,
      );
      if ((_stageOffset - refreshedOffset).abs() < 0.5) return;
      setState(() {
        _stageOffset = refreshedOffset;
      });
    });
  }

  bool _isDesktopTimedLyrics(double width) => width >= _desktopLyricsBreakpoint;

  double _approximateOffsetForIndex(int index) {
    if (!_scrollController.hasClients ||
        index < 0 ||
        widget.timedLyrics.isEmpty) {
      return 0;
    }
    final position = _scrollController.position;
    final minScrollExtent = position.minScrollExtent;
    final maxScrollExtent = position.maxScrollExtent;
    final maxIndex = widget.timedLyrics.length - 1;
    if (maxIndex <= 0) return minScrollExtent;

    // Estimate by list progress instead of a fixed line height so large
    // jumps, such as after a tab resumes, do not overshoot to the bottom.
    final progress = index / maxIndex;
    final target =
        (minScrollExtent + (maxScrollExtent - minScrollExtent) * progress)
            .clamp(minScrollExtent, maxScrollExtent)
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

      final topLeft =
          renderObject.localToGlobal(Offset.zero, ancestor: viewport);
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
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    _timedLyricsWidth = constraints.maxWidth;
                    if (_isDesktopTimedLyrics(constraints.maxWidth)) {
                      final metrics = _buildStageMetrics();
                      _syncStageOffset(metrics, constraints.maxHeight);
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.06),
                                    Colors.white.withValues(alpha: 0.01),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: ShaderMask(
                              key: const ValueKey<String>('lyrics-stage-mask'),
                              shaderCallback: (bounds) {
                                return const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.white,
                                    Colors.white,
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, 0.12, 0.84, 1.0],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.dstIn,
                              child: ClipRect(
                                child: AnimatedContainer(
                                  duration: _stageAnimationDuration,
                                  curve: _stageAnimationCurve,
                                  transform: Matrix4.translationValues(
                                    0,
                                    _stageOffset,
                                    0,
                                  ),
                                  child: SizedBox(
                                    key: const ValueKey<String>('lyrics-stage'),
                                    width: double.infinity,
                                    height: metrics.contentHeight,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        for (var index = 0;
                                            index < widget.timedLyrics.length;
                                            index++)
                                          Positioned(
                                            top: metrics.lineTops[index],
                                            left: 0,
                                            right: 0,
                                            child: _StageLineSizeListener(
                                              onSizeChanged: (size) =>
                                                  _queueLineHeight(
                                                index,
                                                size.height,
                                              ),
                                              child: _LyricLineItem(
                                                lineKey: ValueKey<String>(
                                                  'lyrics-line-$index',
                                                ),
                                                activeMarkerKey: index ==
                                                        _displayedActiveIndex
                                                    ? ValueKey<String>(
                                                        'lyrics-line-active-$index',
                                                      )
                                                    : null,
                                                line: widget.timedLyrics[index],
                                                isActive: index ==
                                                    _displayedActiveIndex,
                                                colorAlpha:
                                                    _colorAlphaForIndex(index),
                                                inactiveFontWeight:
                                                    _fontWeightForIndex(index),
                                                animationDuration:
                                                    _lyricsAnimationDuration,
                                                animationCurve:
                                                    _lyricsAnimationCurve,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: widget.timedLyrics.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.only(
                              top: index == 0 ? 0 : _mobileLineSpacing,
                            ),
                            child: _LyricLineItem(
                              lineKey: _keyForLine(index),
                              activeMarkerKey: null,
                              line: widget.timedLyrics[index],
                              isActive: index == _displayedActiveIndex,
                              colorAlpha: _colorAlphaForIndex(index),
                              inactiveFontWeight: _fontWeightForIndex(index),
                              animationDuration: _lyricsAnimationDuration,
                              animationCurve: _lyricsAnimationCurve,
                            ),
                          );
                        },
                      ),
                    );
                  },
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

  double _colorAlphaForIndex(int index) {
    final distance = _displayedActiveIndex < 0
        ? null
        : (index - _displayedActiveIndex).abs();
    return switch (distance) {
      null => 0.82,
      0 => 1.0,
      1 => 0.72,
      2 => 0.56,
      _ => 0.36,
    };
  }

  FontWeight _fontWeightForIndex(int index) {
    final distance = _displayedActiveIndex < 0
        ? null
        : (index - _displayedActiveIndex).abs();
    return switch (distance) {
      null => FontWeight.w400,
      0 => FontWeight.w600,
      1 => FontWeight.w500,
      _ => FontWeight.w400,
    };
  }
}

class _StageMetrics {
  const _StageMetrics({
    required this.lineTops,
    required this.contentHeight,
  });

  final List<double> lineTops;
  final double contentHeight;
}

class _LyricLineItem extends StatelessWidget {
  const _LyricLineItem({
    required this.lineKey,
    required this.activeMarkerKey,
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
  final Key? activeMarkerKey;
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
          if (activeMarkerKey != null)
            SizedBox(key: activeMarkerKey, width: 0, height: 0),
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
                    fontSize: textIndex == 0
                        ? _primaryFontSize
                        : _translationFontSize,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _StageLineSizeListener extends SingleChildRenderObjectWidget {
  const _StageLineSizeListener({
    required this.onSizeChanged,
    required this.child,
  });

  final ValueChanged<Size> onSizeChanged;
  final Widget child;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderStageLineSizeListener(onSizeChanged);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderStageLineSizeListener renderObject,
  ) {
    renderObject.onSizeChanged = onSizeChanged;
  }
}

class _RenderStageLineSizeListener extends RenderProxyBox {
  _RenderStageLineSizeListener(this.onSizeChanged);

  ValueChanged<Size> onSizeChanged;
  Size? _lastReportedSize;

  @override
  void performLayout() {
    super.performLayout();

    final nextSize = child?.size ?? size;
    if (_lastReportedSize == nextSize) return;

    _lastReportedSize = nextSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onSizeChanged(nextSize);
    });
  }
}
