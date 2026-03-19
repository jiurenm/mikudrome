import 'package:flutter/material.dart';

import '../../models/track.dart';
import '../../theme/app_theme.dart';
import '../player_screen_parts.dart';

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
