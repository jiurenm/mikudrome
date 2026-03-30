import 'package:flutter/material.dart';

/// A single-line text widget that scrolls horizontally when the text overflows.
///
/// When [active] is true (or always, if omitted) and the text is wider than
/// the available width, it animates back and forth with a short pause at each
/// end. When [active] is false, it falls back to [TextOverflow.ellipsis].
class AutoScrollText extends StatefulWidget {
  const AutoScrollText({
    super.key,
    required this.text,
    required this.style,
    this.active = true,
    this.textAlign = TextAlign.left,
  });

  final String text;
  final TextStyle style;
  final bool active;
  final TextAlign textAlign;

  @override
  State<AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<AutoScrollText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double>? _offsetAnimation;
  double _overflow = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void didUpdateWidget(covariant AutoScrollText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
    }
    if (oldWidget.active != widget.active) {
      _syncPlayback();
    }
  }

  void _recalculate() {
    if (!mounted) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final availableWidth = renderBox.size.width;

    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();

    final nextOverflow =
        (textPainter.width - availableWidth).clamp(0, double.infinity).toDouble();

    if ((nextOverflow - _overflow).abs() < 0.5) {
      _syncPlayback();
      return;
    }

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

    _syncPlayback();
    if (mounted) setState(() {});
  }

  void _syncPlayback() {
    if (_overflow <= 0 || _offsetAnimation == null) return;
    if (widget.active) {
      if (!_controller.isAnimating) {
        _controller
          ..reset()
          ..repeat();
      }
    } else {
      _controller.stop();
      _controller.reset();
    }
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
      overflow: _overflow > 0 && widget.active ? TextOverflow.visible : TextOverflow.ellipsis,
      softWrap: false,
      textAlign: widget.textAlign,
    );

    if (_overflow <= 0 || _offsetAnimation == null || !widget.active) {
      return textWidget;
    }

    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final dx = _offsetAnimation?.value ?? 0;
          return Transform.translate(
            offset: Offset(-dx, 0),
            child: child,
          );
        },
        child: textWidget,
      ),
    );
  }
}
