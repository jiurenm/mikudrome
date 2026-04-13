import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../models/playlist.dart';
import '../../theme/app_theme.dart';
import 'playlist_cover.dart';

class PlaylistGridCard extends StatelessWidget {
  const PlaylistGridCard({
    super.key,
    required this.playlist,
    required this.client,
    required this.onTap,
  });

  final Playlist playlist;
  final ApiClient client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: PlaylistCover(
                playlist: playlist,
                client: client,
                size: 160,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              playlist.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${playlist.trackCount} tracks',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
