import 'dart:math';

import 'package:flutter/material.dart';

/// Animated equalizer bars icon, used to indicate active playback.
class AnimatedEqualizer extends StatefulWidget {
  const AnimatedEqualizer({
    super.key,
    this.color = Colors.white,
    this.size = 18.0,
    this.barCount = 3,
  });

  final Color color;
  final double size;
  final int barCount;

  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barWidth = widget.size / (widget.barCount * 2 - 1);
    final gap = barWidth;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.barCount, (i) {
              // Offset each bar's phase so they animate out of sync
              final phase = i * 0.3;
              final t = (_controller.value + phase) % 1.0;
              final height =
                  widget.size * (0.3 + 0.7 * sin(t * pi).abs());
              return Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : gap),
                child: Container(
                  width: barWidth,
                  height: height,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(barWidth / 2),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
