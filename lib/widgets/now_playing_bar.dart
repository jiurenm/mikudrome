import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/track.dart';
import '../theme/app_theme.dart';
import '../theme/vocal_theme.dart';
import '../widgets/player/asset_slider_thumb_shape.dart';
import '../screens/library_home_screen.dart';

/// Persistent bottom bar: now playing + controls + progress + MV indicator.
class NowPlayingBar extends StatelessWidget {
  const NowPlayingBar({
    super.key,
    this.track,
    this.queue = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.progress = 0,
    this.elapsedLabel = '--:--',
    this.durationLabel = '--:--',
    this.playbackMode = PlaybackMode.audio,
    this.onTogglePlay,
    this.onPrevious,
    this.onNext,
    this.onSeekProgress,
    this.onOpenPlayer,
    this.onSelectQueueTrack,
  });

  final Track? track;
  final List<Track> queue;
  final int currentIndex;
  final bool isPlaying;
  final double progress;
  final String elapsedLabel;
  final String durationLabel;
  final PlaybackMode playbackMode;
  final VoidCallback? onTogglePlay;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<double>? onSeekProgress;
  final VoidCallback? onOpenPlayer;
  final ValueChanged<int>? onSelectQueueTrack;

  bool get _hasTrack => track != null;

  @override
  Widget build(BuildContext context) {
    final accentColor = VocalThemeProvider.of(context);
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: AppTheme.footerBg,
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          _buildLeft(context, accentColor),
          Expanded(child: _buildCenter(context, accentColor)),
          _buildRight(context, accentColor),
        ],
      ),
    );
  }

  Widget _buildLeft(BuildContext context, Color accentColor) {
    final currentTrack = track;
    final title = currentTrack?.title ?? 'Nothing playing';
    final subtitle = currentTrack == null
        ? 'Select a track from albums or producers'
        : currentTrack.vocalLine;
    final coverUrl = currentTrack != null && currentTrack.albumId > 0
        ? ApiClient().albumCoverUrl(currentTrack.albumId.toString())
        : '';

    return SizedBox(
      width: MediaQuery.sizeOf(context).width * 0.25,
      child: InkWell(
        onTap: _hasTrack ? onOpenPlayer : null,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            _buildCoverAvatar(coverUrl, accentColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: currentTrack != null
                              ? accentColor
                              : AppTheme.textMuted,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverAvatar(String coverUrl, Color accentColor) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.cardBg,
      ),
      child: ClipOval(
        child: coverUrl.isEmpty
            ? Icon(
                playbackMode == PlaybackMode.video
                    ? Icons.movie
                    : Icons.music_note,
                color: _hasTrack ? accentColor : AppTheme.textMuted,
              )
            : Image.network(
                coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  playbackMode == PlaybackMode.video
                      ? Icons.movie
                      : Icons.music_note,
                  color: _hasTrack ? accentColor : AppTheme.textMuted,
                ),
              ),
      ),
    );
  }

  Widget _buildCenter(BuildContext context, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous,
                    color: AppTheme.textPrimary, size: 28),
                onPressed: _hasTrack ? onPrevious : null,
              ),
              const SizedBox(width: 16),
              Material(
                color: _hasTrack ? Colors.white : AppTheme.cardBg,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _hasTrack ? onTogglePlay : null,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: _hasTrack ? Colors.black : AppTheme.textMuted,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.skip_next,
                    color: AppTheme.textPrimary, size: 28),
                onPressed: _hasTrack ? onNext : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                elapsedLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: accentColor,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                    thumbColor: accentColor,
                    overlayColor: accentColor.withValues(alpha: 0.15),
                    trackHeight: 3,
                    thumbShape: const AssetSliderThumbShape(
                      image: AssetImage('lib/assets/thumb.png'),
                      size: 12,
                    ),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                    padding: EdgeInsets.zero,
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: _hasTrack ? onSeekProgress : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                durationLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showQueuePopover(BuildContext buttonContext, Color accentColor) async {
    if (!_hasTrack || queue.isEmpty || onSelectQueueTrack == null) return;
    final buttonBox = buttonContext.findRenderObject();
    final overlayBox = Overlay.of(buttonContext).context.findRenderObject();
    if (buttonBox is! RenderBox || overlayBox is! RenderBox) return;

    final buttonOffset =
        buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final buttonRect = Rect.fromLTWH(
      buttonOffset.dx,
      buttonOffset.dy,
      buttonBox.size.width,
      buttonBox.size.height,
    );
    const menuWidth = 360.0;
    const menuMaxHeight = 420.0;
    final contentHeight = (queue.length * 58.0).clamp(0.0, menuMaxHeight);
    final estimatedMenuHeight = 45.0 + contentHeight;
    final desiredTop = buttonRect.top - estimatedMenuHeight - 8;
    final top = desiredTop.clamp(
        12.0, overlayBox.size.height - estimatedMenuHeight - 12);
    final left = (buttonRect.right - menuWidth)
        .clamp(12.0, overlayBox.size.width - menuWidth - 12);

    final selectedIndex = await showMenu<int>(
      context: buttonContext,
      color: AppTheme.footerBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      constraints: const BoxConstraints.tightFor(width: menuWidth),
      position: RelativeRect.fromLTRB(
        left,
        top,
        (overlayBox.size.width - left - menuWidth).clamp(12.0, double.infinity),
        (overlayBox.size.height - top - estimatedMenuHeight)
            .clamp(12.0, double.infinity),
      ),
      items: [
        PopupMenuItem<int>(
          enabled: false,
          height: 44,
          child: Row(
            children: [
              Text(
                '当前队列',
                style: Theme.of(buttonContext).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Text(
                '${queue.length} tracks',
                style: Theme.of(buttonContext).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<int>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: menuMaxHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...queue.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isCurrent = index == currentIndex;
                    return InkWell(
                      onTap: () => Navigator.of(buttonContext).pop(index),
                      child: SizedBox(
                        height: 58,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(
                                isCurrent
                                    ? (isPlaying
                                        ? Icons.graphic_eq
                                        : Icons.pause)
                                    : Icons.music_note,
                                color: isCurrent
                                    ? accentColor
                                    : AppTheme.textMuted,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(buttonContext)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: isCurrent
                                                ? accentColor
                                                : AppTheme.textPrimary,
                                            fontWeight: isCurrent
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                    ),
                                    if (item.vocalLine.isNotEmpty)
                                      Text(
                                        item.vocalLine,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(buttonContext)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: AppTheme.textMuted,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.durationFormatted,
                                style: Theme.of(buttonContext)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppTheme.textMuted,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (selectedIndex != null) {
      onSelectQueueTrack?.call(selectedIndex);
    }
  }

  Widget _buildRight(BuildContext context, Color accentColor) {
    final activeLabel = !_hasTrack
        ? 'IDLE'
        : playbackMode == PlaybackMode.video
            ? 'MV ACTIVE'
            : 'AUDIO ACTIVE';
    final activeIcon =
        playbackMode == PlaybackMode.video ? Icons.movie : Icons.music_note;

    return SizedBox(
      width: MediaQuery.sizeOf(context).width * 0.25,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Builder(
            builder: (buttonContext) => IconButton(
              onPressed:
                  _hasTrack ? () => _showQueuePopover(buttonContext, accentColor) : null,
              tooltip: '当前列表',
              icon: const Icon(Icons.queue_music, size: 22),
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.open_in_full, size: 22),
            onPressed: _hasTrack ? onOpenPlayer : null,
            tooltip: 'Open player',
            color: AppTheme.textMuted,
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                activeIcon,
                color: _hasTrack ? accentColor : AppTheme.textMuted,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                activeLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color:
                          _hasTrack ? accentColor : AppTheme.textMuted,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
