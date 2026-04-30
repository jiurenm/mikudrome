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
    this.framed = true,
  });

  final String lyrics;
  final List<TimedLyricLine> timedLyrics;
  final int activeIndex;
  final bool framed;

  @override
  State<LyricsSection> createState() => _LyricsSectionState();
}

class _LyricsSectionState extends State<LyricsSection> {
  static const _lineSpacing = 12.0;
  static const _mobileLineSpacing = 8.0;
  static const _stageAnimationDuration = Duration(milliseconds: 320);
  static const _stageAnimationCurve = Curves.easeInOut;
  static const _stageAnchor = 0.49;
  static const _estimatedLineHeight = 68.0;
  static const _lyricsAnimationDuration = Duration(milliseconds: 200);
  static const _lyricsAnimationCurve = Curves.easeOutCubic;

  late final ScrollController _scrollController;
  final Map<int, GlobalKey> _lineKeys = <int, GlobalKey>{};
  final Map<int, double> _lineHeights = <int, double>{};
  final Map<int, double> _pendingLineHeights = <int, double>{};
  static const _highlightSyncDelay = Duration(milliseconds: 40);

  int _displayedActiveIndex = -1;
  double _stageOffset = 0;
  bool? _lastTimedLyricsDesktopMode;
  int _lastAutoScrolledIndex = -1;
  bool _isAutoScrolling = false;
  bool _lineHeightFlushScheduled = false;
  int? _pendingAutoScrollIndex;
  Timer? _highlightSyncTimer;

  bool get _hasLyrics => widget.lyrics.trim().isNotEmpty;
  bool get _hasTimedLyrics => widget.timedLyrics.isNotEmpty;
  bool get _hasActiveTimedLine =>
      widget.activeIndex >= 0 && widget.activeIndex < widget.timedLyrics.length;

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
      _lastTimedLyricsDesktopMode = null;
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
      _lastTimedLyricsDesktopMode = null;
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
    return _usesDesktopStage;
  }

  bool get _usesDesktopStage {
    return _hasTimedLyrics && _isDesktopPlatform(Theme.of(context).platform);
  }

  void _trackTimedLyricsLayoutMode() {
    final usesDesktopStage = _usesDesktopStage;
    final previousMode = _lastTimedLyricsDesktopMode;
    _lastTimedLyricsDesktopMode = usesDesktopStage;

    if (previousMode == null || previousMode == usesDesktopStage) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasTimedLyrics) return;
      final currentMode = _usesDesktopStageInCurrentContext();
      if (currentMode != usesDesktopStage) return;

      if (usesDesktopStage) {
        _syncDisplayedActiveIndex(immediate: true);
        return;
      }

      _scheduleAutoScrollToActive(force: true);
    });
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
    final focusIndex = _stageFocusIndex;
    if (focusIndex == null) return 0;

    final lineTop = metrics.lineTops[focusIndex];
    final lineHeight = _lineHeights[focusIndex] ?? _estimatedLineHeight;
    final lineCenter = lineTop + lineHeight / 2;
    return viewportHeight * _stageAnchor - lineCenter;
  }

  int? get _stageFocusIndex {
    if (!_hasTimedLyrics) return null;
    if (_hasActiveTimedLine) return _displayedActiveIndex;
    return 0;
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

  bool _isDesktopPlatform(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows =>
        true,
      _ => false,
    };
  }

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
    if (!_hasLyrics) {
      return _buildLyricsContainer(
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            'No lyrics available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ),
      );
    }

    if (_hasTimedLyrics) {
      return LayoutBuilder(
        builder: (context, constraints) {
          _trackTimedLyricsLayoutMode();
          if (_usesDesktopStage) {
            return _buildDesktopStage(constraints);
          }

          return _buildLyricsContainer(
            child: Scrollbar(
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
                      activeGlowKey: null,
                      line: widget.timedLyrics[index],
                      isActive: index == _displayedActiveIndex,
                      visualStyle: _mobileVisualStyleForIndex(index),
                      animationDuration: _lyricsAnimationDuration,
                      animationCurve: _lyricsAnimationCurve,
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
    }

    return _buildLyricsContainer(
      child: Scrollbar(
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

  Widget _buildLyricsContainer({required Widget child}) {
    if (widget.framed) {
      return _buildFramedContainer(child: child);
    }

    return SizedBox.expand(
      child: ShaderMask(
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
            stops: [0.0, 0.12, 0.86, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: child,
        ),
      ),
    );
  }

  Widget _buildFramedContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }

  Widget _buildDesktopStage(BoxConstraints constraints) {
    final metrics = _buildStageMetrics();
    _syncStageOffset(metrics, constraints.maxHeight);
    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
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
              stops: [0.0, 0.18, 0.82, 1.0],
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
                          onSizeChanged: (size) => _queueLineHeight(
                            index,
                            size.height,
                          ),
                          child: _LyricLineItem(
                            lineKey: ValueKey<String>(
                              'lyrics-line-$index',
                            ),
                            activeMarkerKey: index == _displayedActiveIndex
                                ? ValueKey<String>(
                                    'lyrics-line-active-$index',
                                  )
                                : null,
                            activeGlowKey: index == _displayedActiveIndex
                                ? ValueKey<String>(
                                    'lyrics-line-glow-$index',
                                  )
                                : null,
                            line: widget.timedLyrics[index],
                            isActive: index == _displayedActiveIndex,
                            visualStyle: _desktopVisualStyleForIndex(index),
                            animationDuration: _lyricsAnimationDuration,
                            animationCurve: _lyricsAnimationCurve,
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
    );
  }

  _LyricLineVisualStyle _desktopVisualStyleForIndex(int index) {
    final distance = _displayedActiveIndex < 0
        ? null
        : (index - _displayedActiveIndex).abs();
    return switch (distance) {
      null => const _LyricLineVisualStyle(
          primaryAlpha: 0.82,
          secondaryAlpha: 0.43,
          primaryFontWeight: FontWeight.w400,
          secondaryFontWeight: FontWeight.w400,
          primaryFontSize: 22,
          secondaryFontSize: 15,
          primaryLineHeight: 1.45,
          secondaryLineHeight: 1.12,
        ),
      0 => const _LyricLineVisualStyle(
          primaryAlpha: 1.0,
          secondaryAlpha: 0.72,
          primaryFontWeight: FontWeight.w500,
          secondaryFontWeight: FontWeight.w400,
          primaryFontSize: 28,
          secondaryFontSize: 15,
          primaryLineHeight: 1.38,
          secondaryLineHeight: 1.08,
        ),
      1 => const _LyricLineVisualStyle(
          primaryAlpha: 0.68,
          secondaryAlpha: 0.38,
          primaryFontWeight: FontWeight.w500,
          secondaryFontWeight: FontWeight.w400,
          primaryFontSize: 22,
          secondaryFontSize: 15,
          primaryLineHeight: 1.45,
          secondaryLineHeight: 1.12,
        ),
      2 => const _LyricLineVisualStyle(
          primaryAlpha: 0.58,
          secondaryAlpha: 0.32,
          primaryFontWeight: FontWeight.w400,
          secondaryFontWeight: FontWeight.w400,
          primaryFontSize: 21,
          secondaryFontSize: 14,
          primaryLineHeight: 1.45,
          secondaryLineHeight: 1.12,
        ),
      _ => const _LyricLineVisualStyle(
          primaryAlpha: 0.36,
          secondaryAlpha: 0.2,
          primaryFontWeight: FontWeight.w400,
          secondaryFontWeight: FontWeight.w400,
          primaryFontSize: 20,
          secondaryFontSize: 14,
          primaryLineHeight: 1.45,
          secondaryLineHeight: 1.12,
        ),
    };
  }

  _LyricLineVisualStyle _mobileVisualStyleForIndex(int index) {
    final distance = _displayedActiveIndex < 0
        ? null
        : (index - _displayedActiveIndex).abs();
    return switch (distance) {
      null => const _LyricLineVisualStyle(
          primaryAlpha: 0.82,
          secondaryAlpha: 0.4264,
          primaryFontWeight: FontWeight.w400,
          secondaryFontWeight: FontWeight.w400,
          primaryFontSize: 22,
          secondaryFontSize: 15,
          primaryLineHeight: 1.7,
          secondaryLineHeight: 1.18,
        ),
      0 => const _LyricLineVisualStyle(
          primaryAlpha: 1.0,
          secondaryAlpha: 0.62,
          primaryFontWeight: FontWeight.w700,
          secondaryFontWeight: FontWeight.w400,
          primaryFontSize: 22,
          secondaryFontSize: 15,
          primaryLineHeight: 1.7,
          secondaryLineHeight: 1.18,
        ),
      1 => const _LyricLineVisualStyle(
          primaryAlpha: 0.72,
          secondaryAlpha: 0.3744,
          primaryFontWeight: FontWeight.w500,
          secondaryFontWeight: FontWeight.w500,
          primaryFontSize: 22,
          secondaryFontSize: 15,
          primaryLineHeight: 1.7,
          secondaryLineHeight: 1.18,
        ),
      2 => const _LyricLineVisualStyle(
          primaryAlpha: 0.56,
          secondaryAlpha: 0.2912,
          primaryFontWeight: FontWeight.w400,
          secondaryFontWeight: FontWeight.w400,
          primaryFontSize: 22,
          secondaryFontSize: 15,
          primaryLineHeight: 1.7,
          secondaryLineHeight: 1.18,
        ),
      _ => const _LyricLineVisualStyle(
          primaryAlpha: 0.36,
          secondaryAlpha: 0.1872,
          primaryFontWeight: FontWeight.w400,
          secondaryFontWeight: FontWeight.w400,
          primaryFontSize: 22,
          secondaryFontSize: 15,
          primaryLineHeight: 1.7,
          secondaryLineHeight: 1.18,
        ),
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

class _LyricLineVisualStyle {
  const _LyricLineVisualStyle({
    required this.primaryAlpha,
    required this.secondaryAlpha,
    required this.primaryFontWeight,
    required this.secondaryFontWeight,
    required this.primaryFontSize,
    required this.secondaryFontSize,
    required this.primaryLineHeight,
    required this.secondaryLineHeight,
  });

  final double primaryAlpha;
  final double secondaryAlpha;
  final FontWeight primaryFontWeight;
  final FontWeight secondaryFontWeight;
  final double primaryFontSize;
  final double secondaryFontSize;
  final double primaryLineHeight;
  final double secondaryLineHeight;
}

class _LyricLineItem extends StatelessWidget {
  const _LyricLineItem({
    required this.lineKey,
    required this.activeMarkerKey,
    required this.activeGlowKey,
    required this.line,
    required this.isActive,
    required this.visualStyle,
    required this.animationDuration,
    required this.animationCurve,
  });

  final Key lineKey;
  final Key? activeMarkerKey;
  final Key? activeGlowKey;
  final TimedLyricLine line;
  final bool isActive;
  final _LyricLineVisualStyle visualStyle;
  final Duration animationDuration;
  final Curve animationCurve;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyLarge!;
    final showFocusGlow = isActive && activeGlowKey != null;
    final activeHighlight = Color.lerp(AppTheme.mikuGreen, Colors.white, 0.18)!;
    final glow = <Shadow>[
      Shadow(
        color: Colors.white.withValues(alpha: 0.28),
        blurRadius: 3,
        offset: const Offset(0.6, 0),
      ),
      Shadow(
        color: activeHighlight.withValues(alpha: 0.42),
        blurRadius: 8,
        offset: const Offset(1.0, 0),
      ),
      Shadow(
        color: AppTheme.mikuGreen.withValues(alpha: 0.24),
        blurRadius: 14,
        offset: const Offset(1.4, 0),
      ),
    ];
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var textIndex = 0; textIndex < line.texts.length; textIndex++)
          TweenAnimationBuilder<Color?>(
            duration: animationDuration,
            curve: animationCurve,
            tween: ColorTween(
              end: isActive
                  ? activeHighlight.withValues(
                      alpha: textIndex == 0
                          ? visualStyle.primaryAlpha
                          : visualStyle.secondaryAlpha,
                    )
                  : AppTheme.textPrimary.withValues(
                      alpha: textIndex == 0
                          ? visualStyle.primaryAlpha
                          : visualStyle.secondaryAlpha,
                    ),
            ),
            builder: (context, color, child) {
              return Text(
                line.texts[textIndex],
                style: baseStyle.copyWith(
                  color: color,
                  height: line.texts.length > 1
                      ? (textIndex == 0
                          ? visualStyle.primaryLineHeight
                          : visualStyle.secondaryLineHeight)
                      : visualStyle.primaryLineHeight,
                  fontWeight: textIndex == 0
                      ? visualStyle.primaryFontWeight
                      : visualStyle.secondaryFontWeight,
                  fontSize: textIndex == 0
                      ? visualStyle.primaryFontSize
                      : visualStyle.secondaryFontSize,
                  shadows: showFocusGlow ? glow : null,
                ),
              );
            },
          ),
      ],
    );

    if (showFocusGlow && activeGlowKey != null) {
      content = Container(
        key: activeGlowKey,
        child: AnimatedScale(
          duration: animationDuration,
          curve: animationCurve,
          alignment: Alignment.centerLeft,
          scale: 1.1,
          child: content,
        ),
      );
    }

    return Container(
      key: lineKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activeMarkerKey != null)
            SizedBox(key: activeMarkerKey, width: 0, height: 0),
          content,
        ],
      ),
    );
  }
}

class _StageLineSizeListener extends SingleChildRenderObjectWidget {
  const _StageLineSizeListener({
    required this.onSizeChanged,
    super.child,
  });

  final ValueChanged<Size> onSizeChanged;

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
