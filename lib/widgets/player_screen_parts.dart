import 'package:flutter/material.dart';

import '../models/track.dart';
import '../screens/library_home_screen.dart';
import '../theme/app_theme.dart';

class ModeSwitcher extends StatelessWidget {
  const ModeSwitcher({
    super.key,
    required this.playbackMode,
    required this.canUseVideoMode,
    required this.onChanged,
  });

  final PlaybackMode playbackMode;
  final bool canUseVideoMode;
  final ValueChanged<PlaybackMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PlaybackMode>(
      segments: const [
        ButtonSegment<PlaybackMode>(
          value: PlaybackMode.video,
          label: Text('MV'),
          icon: Icon(Icons.movie),
        ),
        ButtonSegment<PlaybackMode>(
          value: PlaybackMode.audio,
          label: Text('Audio'),
          icon: Icon(Icons.music_note),
        ),
      ],
      selected: {playbackMode},
      onSelectionChanged: (selection) {
        final nextMode = selection.first;
        if (nextMode == PlaybackMode.video && !canUseVideoMode) return;
        onChanged(nextMode);
      },
      showSelectedIcon: false,
    );
  }
}

class CreditColumn extends StatelessWidget {
  const CreditColumn({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textMuted,
                letterSpacing: 1.5,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            color: AppTheme.mikuGreen,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class VocalBadgeColumn extends StatelessWidget {
  const VocalBadgeColumn({
    super.key,
    required this.vocalists,
  });

  final List<String> vocalists;

  @override
  Widget build(BuildContext context) {
    final values = vocalists.isNotEmpty ? vocalists : const ['Unknown'];
    return Column(
      children: [
        Text(
          'Vocalists',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textMuted,
                letterSpacing: 1.5,
              ),
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: values.map((value) => VocalBadge(label: value)).toList(),
        ),
      ],
    );
  }
}

class VocalBadge extends StatelessWidget {
  const VocalBadge({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.mikuGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.mikuGreen),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.mikuGreen,
        ),
      ),
    );
  }
}

class PlayerHeader extends StatelessWidget {
  const PlayerHeader({
    super.key,
    required this.contextLabel,
    required this.playbackMode,
    required this.canUseVideoMode,
    required this.showQueue,
    required this.onClose,
    required this.onChangedMode,
    required this.onToggleQueue,
    required this.onEnterFullscreen,
  });

  final String contextLabel;
  final PlaybackMode playbackMode;
  final bool canUseVideoMode;
  final bool showQueue;
  final VoidCallback onClose;
  final ValueChanged<PlaybackMode> onChangedMode;
  final VoidCallback onToggleQueue;
  final VoidCallback? onEnterFullscreen;

  bool get _isVideoMode => playbackMode == PlaybackMode.video;

  @override
  Widget build(BuildContext context) {
    final modeText = _isVideoMode ? 'Mode: MV Playback' : 'Mode: Audio Playback';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            tooltip: 'Back',
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.mikuGreen,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    _isVideoMode ? Icons.movie : Icons.music_note,
                    color: Colors.black,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'MIKUDROME',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: AppTheme.mikuGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    contextLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (!_isVideoMode) ...[
            Text(
              modeText,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
            const SizedBox(width: 10),
          ],
          ModeSwitcher(
            playbackMode: playbackMode,
            canUseVideoMode: canUseVideoMode,
            onChanged: onChangedMode,
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onToggleQueue,
            icon: Icon(
              showQueue ? Icons.queue_music : Icons.queue_music_outlined,
              color: showQueue ? AppTheme.mikuGreen : AppTheme.textMuted,
            ),
            tooltip: showQueue ? 'Hide queue' : 'Show queue',
          ),
          if (_isVideoMode)
            IconButton(
              onPressed: onEnterFullscreen,
              icon: const Icon(Icons.fullscreen, color: AppTheme.textMuted),
              tooltip: 'Fullscreen',
            ),
        ],
      ),
    );
  }
}

class QueuePanel extends StatelessWidget {
  const QueuePanel({
    super.key,
    required this.contextLabel,
    required this.queue,
    required this.currentIndex,
    required this.isVideoMode,
    required this.coverUrlForTrack,
    required this.onSelectTrack,
  });

  final String contextLabel;
  final List<Track> queue;
  final int currentIndex;
  final bool isVideoMode;
  final String Function(Track track) coverUrlForTrack;
  final ValueChanged<int> onSelectTrack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isVideoMode ? 320 : 280,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey.shade800)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                contextLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              Text(
                '${currentIndex + 1}/${queue.length}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.mikuGreen,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final track = queue[index];
                final subtitle = track.vocalLine.isNotEmpty
                    ? track.vocalLine
                    : 'Unknown credits';
                return TrackListItem(
                  track: track,
                  subtitle: subtitle,
                  coverUrl: coverUrlForTrack(track),
                  isActive: index == currentIndex,
                  onTap: () => onSelectTrack(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AudioArtworkCard extends StatelessWidget {
  const AudioArtworkCard({
    super.key,
    required this.albumCoverUrl,
    required this.placeholder,
  });

  final String albumCoverUrl;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: albumCoverUrl.isNotEmpty
                    ? Image.network(
                        albumCoverUrl,
                        height: 320,
                        width: 320,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => placeholder,
                      )
                    : placeholder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrackInfoSection extends StatelessWidget {
  const TrackInfoSection({
    super.key,
    required this.track,
  });

  final Track track;

  @override
  Widget build(BuildContext context) {
    final vocalists = track.vocalists;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        children: [
          Text(
            track.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 24,
            runSpacing: 12,
            children: [
              CreditColumn(
                label: 'Composer',
                value: track.composerDisplay,
              ),
              Container(
                width: 1,
                height: 32,
                color: Colors.grey.shade700,
              ),
              CreditColumn(
                label: 'Lyricist',
                value: track.lyricistDisplay,
              ),
              Container(
                width: 1,
                height: 32,
                color: Colors.grey.shade700,
              ),
              VocalBadgeColumn(vocalists: vocalists),
            ],
          ),
        ],
      ),
    );
  }
}

class VideoModeDetails extends StatelessWidget {
  const VideoModeDetails({
    super.key,
    required this.title,
    required this.subtitle,
    required this.showSideInfo,
  });

  final String title;
  final String subtitle;
  final bool showSideInfo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                  maxLines: showSideInfo ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!showSideInfo) ...[
            const SizedBox(width: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TrackListItem extends StatelessWidget {
  const TrackListItem({
    super.key,
    required this.track,
    required this.subtitle,
    required this.coverUrl,
    required this.isActive,
    required this.onTap,
  });

  final Track track;
  final String subtitle;
  final String coverUrl;
  final bool isActive;
  final VoidCallback onTap;

  Widget _coverPlaceholder() => Container(
        width: 48,
        height: 48,
        color: AppTheme.cardBg,
        alignment: Alignment.center,
        child: Icon(
          track.hasVideo ? Icons.movie : Icons.music_note,
          color: track.hasVideo ? AppTheme.mikuGreen : AppTheme.textMuted,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withValues(alpha: 0.03) : null,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? const Border(
                  left: BorderSide(color: AppTheme.mikuGreen, width: 4),
                )
              : null,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  if (coverUrl.isNotEmpty)
                    Image.network(
                      coverUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _coverPlaceholder(),
                    )
                  else
                    _coverPlaceholder(),
                  if (track.hasVideo)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'MV',
                          style: TextStyle(
                            color: AppTheme.mikuGreen,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? AppTheme.mikuGreen
                          : AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle.isNotEmpty ? subtitle : 'Unknown credits',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (track.hasVideo)
                  const Icon(Icons.movie, size: 14, color: AppTheme.mikuGreen)
                else
                  const Icon(Icons.music_note,
                      size: 14, color: AppTheme.textMuted),
                const SizedBox(height: 4),
                Text(
                  track.durationFormatted,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
