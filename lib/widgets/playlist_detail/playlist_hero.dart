import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/playlist.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../playlists/playlist_cover.dart';

class PlaylistHero extends StatelessWidget {
  const PlaylistHero({
    super.key,
    required this.playlist,
    required this.client,
    required this.onPlay,
    required this.onEdit,
  });

  final Playlist playlist;
  final ApiClient client;
  final VoidCallback onPlay;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);

    final gradient = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.mikuGreen.withValues(alpha: 0.2),
          AppTheme.mikuDark,
        ],
      ),
    );

    if (mobile) {
      return _buildMobileLayout(context, gradient);
    }
    return _buildDesktopLayout(context, gradient);
  }

  Widget _buildMobileLayout(BuildContext context, BoxDecoration gradient) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final coverSize = screenWidth * 0.6;

    return Container(
      decoration: gradient,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: PlaylistCover(
              playlist: playlist,
              client: client,
              size: coverSize,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'PLAYLIST',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.mikuGreen,
                ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            playlist.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            '${playlist.trackCount} tracks',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: playlist.trackCount > 0 ? onPlay : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.mikuGreen,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text('PLAY'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: onEdit,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.textMuted),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  foregroundColor: AppTheme.textPrimary,
                ),
                child: const Text('EDIT'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, BoxDecoration gradient) {
    return Container(
      height: 320,
      decoration: gradient,
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: PlaylistCover(
              playlist: playlist,
              client: client,
              size: 224,
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PLAYLIST',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.mikuGreen,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    playlist.name,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        '${playlist.trackCount} tracks',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                      ),
                      const SizedBox(width: 24),
                      FilledButton.icon(
                        onPressed: playlist.trackCount > 0 ? onPlay : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.mikuGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow, size: 20),
                        label: const Text('PLAY'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: onEdit,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.textMuted),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                          foregroundColor: AppTheme.textPrimary,
                        ),
                        child: const Text('EDIT'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
