import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../models/track.dart';
import '../../services/playlist_repository.dart';
import '../../theme/app_theme.dart';
import '../add_to_playlist_sheet.dart';
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

  void _showTrackMenu(BuildContext context, Track track) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Add to playlist'),
              onTap: () {
                Navigator.pop(context);
                AddToPlaylistSheet.show(
                  context: context,
                  trackIds: [track.id],
                  client: ApiClient(),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Add to favorites'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await PlaylistRepository.instance.toggleFavorite(
                    track.id,
                    ApiClient(),
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to update favorite')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

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
                return Row(
                  children: [
                    Expanded(
                      child: TrackListItem(
                        track: track,
                        subtitle: subtitle,
                        coverUrl: coverUrlForTrack(track),
                        isActive: index == currentIndex,
                        onTap: () => onSelectTrack(index),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, size: 20),
                      color: AppTheme.textMuted,
                      onPressed: () => _showTrackMenu(context, track),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
