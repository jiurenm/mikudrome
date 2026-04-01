import 'package:flutter/material.dart';

import '../models/track.dart';
import '../theme/app_theme.dart';
import 'mobile_mini_player.dart';

class MobilePlayerSheet extends StatefulWidget {
  const MobilePlayerSheet({
    super.key,
    required this.track,
    required this.coverUrl,
    required this.isPlaying,
    required this.progress,
    required this.onPlayPause,
    required this.bottomPadding,
    required this.playerBuilder,
  });

  final Track track;
  final String coverUrl;
  final bool isPlaying;
  final double progress;
  final VoidCallback onPlayPause;
  final double bottomPadding; // Tab bar height + safe area
  final Widget Function(VoidCallback onClose) playerBuilder;

  @override
  State<MobilePlayerSheet> createState() => _MobilePlayerSheetState();
}

class _MobilePlayerSheetState extends State<MobilePlayerSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _expand() {
    _controller.forward();
  }

  void _collapse() {
    _controller.reverse();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _controller.value -=
        details.primaryDelta! / MediaQuery.sizeOf(context).height;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_controller.value > 0.5) {
      _expand();
    } else {
      _collapse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    const miniPlayerHeight = 64.0;
    final collapsedTop =
        screenHeight - miniPlayerHeight - widget.bottomPadding;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final top = collapsedTop * (1 - _controller.value);
        return Positioned(
          top: top,
          left: 0,
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onVerticalDragUpdate: _handleDragUpdate,
            onVerticalDragEnd: _handleDragEnd,
            child: Material(
              color: AppTheme.mikuDark,
              child: _controller.value < 0.1
                  ? MobileMiniPlayer(
                      track: widget.track,
                      coverUrl: widget.coverUrl,
                      isPlaying: widget.isPlaying,
                      progress: widget.progress,
                      onTap: _expand,
                      onPlayPause: widget.onPlayPause,
                    )
                  : widget.playerBuilder(_collapse),
            ),
          ),
        );
      },
    );
  }
}
