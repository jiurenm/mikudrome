import 'package:flutter/material.dart';

import '../models/track.dart';
import '../theme/app_theme.dart';
import '../screens/library_home_screen.dart';

/// Persistent bottom bar: now playing + controls + progress + MV indicator.
class NowPlayingBar extends StatelessWidget {
  const NowPlayingBar({
    super.key,
    this.track,
    this.isPlaying = false,
    this.progress = 0,
    this.elapsedLabel = '--:--',
    this.durationLabel = '--:--',
    this.playbackMode = PlaybackMode.audio,
    this.onTogglePlay,
    this.onPrevious,
    this.onNext,
    this.onOpenPlayer,
  });

  final Track? track;
  final bool isPlaying;
  final double progress;
  final String elapsedLabel;
  final String durationLabel;
  final PlaybackMode playbackMode;
  final VoidCallback? onTogglePlay;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onOpenPlayer;

  bool get _hasTrack => track != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: AppTheme.footerBg,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          _buildLeft(context),
          Expanded(child: _buildCenter(context)),
          _buildRight(context),
        ],
      ),
    );
  }

  Widget _buildLeft(BuildContext context) {
    final currentTrack = track;
    final title = currentTrack?.title ?? 'Nothing playing';
    final subtitle = currentTrack == null
        ? 'Select a track from albums or producers'
        : currentTrack.vocalists.isNotEmpty
            ? currentTrack.vocalists.join(', ')
            : currentTrack.composerDisplay;

    return SizedBox(
      width: MediaQuery.sizeOf(context).width * 0.25,
      child: InkWell(
        onTap: _hasTrack ? onOpenPlayer : null,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                playbackMode == PlaybackMode.video ? Icons.movie : Icons.music_note,
                color: _hasTrack ? AppTheme.mikuGreen : AppTheme.textMuted,
              ),
            ),
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
                              ? AppTheme.mikuGreen
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
            IconButton(
              icon: const Icon(Icons.open_in_full,
                  color: AppTheme.textMuted, size: 22),
              onPressed: _hasTrack ? onOpenPlayer : null,
              tooltip: 'Open player',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenter(BuildContext context) {
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
          const SizedBox(height: 8),
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppTheme.mikuGreen),
                    minHeight: 4,
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

  Widget _buildRight(BuildContext context) {
    final activeLabel = !_hasTrack
        ? 'IDLE'
        : playbackMode == PlaybackMode.video
            ? 'MV ACTIVE'
            : 'AUDIO ACTIVE';
    final activeIcon = playbackMode == PlaybackMode.video
        ? Icons.movie
        : Icons.music_note;

    return SizedBox(
      width: MediaQuery.sizeOf(context).width * 0.25,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                activeIcon,
                color: _hasTrack ? AppTheme.mikuGreen : AppTheme.textMuted,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                activeLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _hasTrack ? AppTheme.mikuGreen : AppTheme.textMuted,
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
