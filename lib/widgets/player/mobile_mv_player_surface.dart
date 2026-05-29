import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../theme/app_theme.dart';
import '../favorite_button.dart';
import 'asset_slider_thumb_shape.dart';

class MobileMvPlayerSurface extends StatefulWidget {
  const MobileMvPlayerSurface({
    super.key,
    required this.title,
    required this.subtitle,
    required this.contextLabel,
    required this.video,
    required this.isInitializing,
    required this.error,
    required this.isPlaying,
    required this.progress,
    required this.elapsedLabel,
    required this.durationLabel,
    required this.canSeek,
    required this.hasPrevious,
    required this.hasNext,
    required this.trackId,
    required this.favoriteClient,
    required this.accentColor,
    required this.onCollapse,
    required this.onRetryVideo,
    this.canSwitchToAudio = true,
    required this.onSwitchToAudio,
    required this.onTogglePlayback,
    required this.onSeek,
    required this.onPrevious,
    required this.onNext,
    required this.playbackOrderButton,
    required this.onOpenQueue,
    required this.onEnterFullscreen,
  });

  final String title;
  final String subtitle;
  final String contextLabel;
  final Widget video;
  final bool isInitializing;
  final String? error;
  final bool isPlaying;
  final double progress;
  final String elapsedLabel;
  final String durationLabel;
  final bool canSeek;
  final bool hasPrevious;
  final bool hasNext;
  final int trackId;
  final ApiClient favoriteClient;
  final Color accentColor;
  final VoidCallback onCollapse;
  final VoidCallback onRetryVideo;
  final bool canSwitchToAudio;
  final VoidCallback onSwitchToAudio;
  final VoidCallback onTogglePlayback;
  final ValueChanged<double> onSeek;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Widget playbackOrderButton;
  final VoidCallback onOpenQueue;
  final VoidCallback onEnterFullscreen;

  @override
  State<MobileMvPlayerSurface> createState() => _MobileMvPlayerSurfaceState();
}

class _MobileMvPlayerSurfaceState extends State<MobileMvPlayerSurface> {
  bool _showChrome = true;

  void _toggleChrome() {
    setState(() {
      _showChrome = !_showChrome;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('mobile-mv-player-surface'),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: Column(
            children: [
              _buildTopBar(context),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildVideoFrame(context),
                        const SizedBox(height: 20),
                        AnimatedOpacity(
                          opacity: _showChrome ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: IgnorePointer(
                            ignoring: !_showChrome,
                            child: _buildChrome(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return AnimatedOpacity(
      opacity: _showChrome ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      child: IgnorePointer(
        ignoring: !_showChrome,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onCollapse,
                icon: const Icon(Icons.keyboard_arrow_down, size: 32),
                color: Colors.white,
                tooltip: '收起',
              ),
              Expanded(
                child: Text(
                  widget.contextLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textMuted,
                    letterSpacing: 0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 48, height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoFrame(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleChrome,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF050505),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            key: const ValueKey('mobile-mv-video-frame'),
            aspectRatio: 16 / 9,
            child: _buildVideoContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoContent(BuildContext context) {
    final error = widget.error;
    if (widget.isInitializing) {
      return Center(
        child: CircularProgressIndicator(color: widget.accentColor),
      );
    }

    if (error != null) {
      return _buildVideoError(context, error);
    }

    return widget.video;
  }

  Widget _buildVideoError(BuildContext context, String error) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact =
            constraints.maxWidth < 320 || constraints.maxHeight < 180;
        final padding = EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 18,
          vertical: isCompact ? 8 : 18,
        );
        final minContentHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - padding.vertical).clamp(
                0.0,
                constraints.maxHeight,
              )
            : 0.0;
        final buttonStyle = ButtonStyle(
          visualDensity: isCompact ? VisualDensity.compact : null,
          tapTargetSize: isCompact
              ? MaterialTapTargetSize.shrinkWrap
              : MaterialTapTargetSize.padded,
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 16,
              vertical: isCompact ? 7 : 10,
            ),
          ),
        );

        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minContentHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: widget.accentColor,
                    size: isCompact ? 24 : 34,
                  ),
                  SizedBox(height: isCompact ? 6 : 10),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontSize: isCompact ? 13 : null,
                    ),
                    maxLines: isCompact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isCompact ? 8 : 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: isCompact ? 8 : 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        style: buttonStyle,
                        onPressed: widget.onRetryVideo,
                        child: const Text('重试 MV'),
                      ),
                      if (widget.canSwitchToAudio)
                        OutlinedButton(
                          style: buttonStyle,
                          onPressed: widget.onSwitchToAudio,
                          child: const Text('切到音频'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChrome(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTrackHeader(context),
        const SizedBox(height: 14),
        _buildProgress(context),
        const SizedBox(height: 8),
        _buildPlaybackControls(),
      ],
    );
  }

  Widget _buildTrackHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white60,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FavoriteButton(
          trackId: widget.trackId,
          client: widget.favoriteClient,
          size: 28,
        ),
        IconButton(
          key: const ValueKey('mobile-mv-queue-button'),
          onPressed: widget.onOpenQueue,
          icon: const Icon(Icons.queue_music_outlined, size: 28),
          color: Colors.white70,
          tooltip: '播放队列',
        ),
      ],
    );
  }

  Widget _buildProgress(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: widget.accentColor,
            inactiveTrackColor: Colors.white24,
            thumbColor: widget.accentColor,
            overlayColor: widget.accentColor.withValues(alpha: 0.15),
            trackHeight: 4,
            thumbShape: const AssetSliderThumbShape(
              image: AssetImage('lib/assets/thumb.png'),
              size: 18,
            ),
          ),
          child: Slider(
            value: widget.progress.clamp(0.0, 1.0),
            onChanged: widget.canSeek ? widget.onSeek : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.elapsedLabel,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white),
              ),
              Text(
                widget.durationLabel,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox.square(
          dimension: 48,
          child: Center(child: widget.playbackOrderButton),
        ),
        IconButton(
          onPressed: widget.hasPrevious ? widget.onPrevious : null,
          icon: const Icon(Icons.skip_previous, size: 30),
          color: Colors.white,
          disabledColor: Colors.white24,
        ),
        IconButton(
          onPressed: widget.onTogglePlayback,
          icon: Icon(
            widget.isPlaying ? Icons.pause_circle_filled : Icons.play_circle,
            size: 58,
          ),
          color: widget.accentColor,
          style: IconButton.styleFrom(minimumSize: const Size(70, 70)),
        ),
        IconButton(
          onPressed: widget.hasNext ? widget.onNext : null,
          icon: const Icon(Icons.skip_next, size: 30),
          color: Colors.white,
          disabledColor: Colors.white24,
        ),
        IconButton(
          onPressed: widget.onEnterFullscreen,
          icon: const Icon(Icons.fullscreen, size: 28),
          color: Colors.white70,
          tooltip: '全屏',
        ),
      ],
    );
  }
}
