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
    this.expanded = false,
    this.onExpandedChanged,
  });

  final Track track;
  final String coverUrl;
  final bool isPlaying;
  final double progress;
  final VoidCallback onPlayPause;
  final double bottomPadding; // Tab bar height + safe area
  final Widget Function(VoidCallback onClose) playerBuilder;
  final bool expanded;
  final ValueChanged<bool>? onExpandedChanged;

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
      value: widget.expanded ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(MobilePlayerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // React to external expanded state changes (e.g. user taps play on a track)
    if (widget.expanded != oldWidget.expanded) {
      if (widget.expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _expand() {
    _controller.forward();
    widget.onExpandedChanged?.call(true);
  }

  void _collapse() {
    _controller.reverse();
    widget.onExpandedChanged?.call(false);
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
        final isExpanded = _controller.value > 0.1;
        return Positioned(
          top: top,
          left: 0,
          right: 0,
          bottom: widget.bottomPadding,
          child: Material(
            color: AppTheme.mikuDark,
            child: Column(
              children: [
                // Mini player bar — always in the tree, hidden via Offstage
                // when expanded to keep Column children stable.
                Offstage(
                  offstage: isExpanded,
                  child: GestureDetector(
                    onVerticalDragUpdate: _handleDragUpdate,
                    onVerticalDragEnd: _handleDragEnd,
                    child: MobileMiniPlayer(
                      track: widget.track,
                      coverUrl: widget.coverUrl,
                      isPlaying: widget.isPlaying,
                      progress: widget.progress,
                      onTap: _expand,
                      onPlayPause: widget.onPlayPause,
                    ),
                  ),
                ),
                // Player — always mounted with consistent widget types.
                // GestureDetector stays in tree; IgnorePointer disables
                // drag when collapsed so offstage player can't intercept.
                Expanded(
                  child: GestureDetector(
                    onVerticalDragUpdate:
                        isExpanded ? _handleDragUpdate : null,
                    onVerticalDragEnd: isExpanded ? _handleDragEnd : null,
                    child: Offstage(
                      offstage: !isExpanded,
                      child: child!,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      // Build playerBuilder once as `child` — AnimatedBuilder preserves
      // the child across rebuilds, preventing PlayerScreen recreation.
      child: widget.playerBuilder(_collapse),
    );
  }
}
