import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/track.dart';
import '../../theme/app_theme.dart';

/// Floating Picture-in-Picture mini-player for MV playback.
///
/// Displays a draggable video thumbnail positioned bottom-right,
/// with hover overlay showing track title and playback controls.
class PipMiniPlayer extends StatefulWidget {
  const PipMiniPlayer({
    super.key,
    required this.controller,
    required this.track,
    required this.isPlaying,
    required this.onTap,
    required this.onTogglePlay,
    required this.onClose,
  });

  final VideoPlayerController controller;
  final Track track;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onTogglePlay;
  final VoidCallback onClose;

  @override
  State<PipMiniPlayer> createState() => _PipMiniPlayerState();
}

class _PipMiniPlayerState extends State<PipMiniPlayer> {
  static const double _width = 300;
  static const double _margin = 16;
  static const double _bottomOffset = 80; // above NowPlayingBar

  Offset? _position;
  bool _hovering = false;

  double get _aspectRatio {
    final ar = widget.controller.value.aspectRatio;
    return ar > 0 ? ar : 16 / 9;
  }

  double get _height => _width / _aspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final areaWidth = constraints.maxWidth;
        final areaHeight = constraints.maxHeight;
        final pos = _position ??
            Offset(
              areaWidth - _width - _margin,
              areaHeight - _height - _bottomOffset - _margin,
            );

        return Stack(
          children: [
            Positioned(
              left: pos.dx,
              top: pos.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _position = Offset(
                      (pos.dx + details.delta.dx)
                          .clamp(0, areaWidth - _width),
                      (pos.dy + details.delta.dy)
                          .clamp(0, areaHeight - _height),
                    );
                  });
                },
                onTap: widget.onTap,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _hovering = true),
                  onExit: (_) => setState(() => _hovering = false),
                  child: _buildPlayer(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlayer() {
    return Container(
      width: _width,
      height: _height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(widget.controller),
            if (_hovering) _buildOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
          stops: [0.3, 1.0],
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.track.title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _overlayButton(
                icon: widget.isPlaying ? Icons.pause : Icons.play_arrow,
                onTap: widget.onTogglePlay,
              ),
              const Spacer(),
              _overlayButton(
                icon: Icons.close,
                onTap: widget.onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overlayButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: AppTheme.textPrimary, size: 22),
      ),
    );
  }
}
