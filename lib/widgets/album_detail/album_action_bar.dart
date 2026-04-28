import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../models/track.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../add_to_playlist_sheet.dart';

class AlbumActionBar extends StatelessWidget {
  const AlbumActionBar({
    super.key,
    required this.tracks,
    required this.onPlayAll,
    required this.onShuffle,
  });

  final List<Track> tracks;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    if (mobile) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MobileAlbumAction(
                  icon: Icons.favorite,
                  label: '已喜欢',
                  emphasized: true,
                  onPressed: tracks.isEmpty ? null : () {},
                ),
                _MobileAlbumAction(
                  icon: Icons.download,
                  label: '下载',
                  onPressed: tracks.isEmpty ? null : () {},
                ),
                _MobileAlbumAction(
                  icon: Icons.more_horiz,
                  label: '更多',
                  onPressed: tracks.isEmpty
                      ? null
                      : () {
                          AddToPlaylistSheet.show(
                            context: context,
                            trackIds: tracks.map((t) => t.id).toList(),
                            client: ApiClient(),
                          );
                        },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: tracks.isEmpty ? null : onPlayAll,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.mikuGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text(
                  '播放全部',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 16 : 40,
        vertical: mobile ? 16 : 24,
      ),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: tracks.isEmpty ? null : onPlayAll,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.mikuGreen,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            icon: const Icon(Icons.play_arrow, size: 20),
            label: const Text('PLAY ALL'),
          ),
          const SizedBox(width: 24),
          OutlinedButton(
            onPressed: tracks.isEmpty ? null : onShuffle,
            style: ButtonStyle(
              side: MaterialStateProperty.resolveWith<BorderSide>((states) {
                if (states.contains(MaterialState.hovered)) {
                  return const BorderSide(color: AppTheme.mikuGreen);
                }
                return const BorderSide(color: AppTheme.textMuted);
              }),
              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
                const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              foregroundColor: MaterialStateProperty.all<Color>(
                AppTheme.textPrimary,
              ),
            ),
            child: const Icon(Icons.shuffle, size: 22),
          ),
          const SizedBox(width: 24),
          IconButton(
            onPressed: tracks.isEmpty
                ? null
                : () {
                    AddToPlaylistSheet.show(
                      context: context,
                      trackIds: tracks.map((t) => t.id).toList(),
                      client: ApiClient(),
                    );
                  },
            style: IconButton.styleFrom(iconSize: 28).copyWith(
              overlayColor: MaterialStateProperty.resolveWith<Color?>((states) {
                if (states.contains(MaterialState.hovered)) {
                  return AppTheme.mikuGreen.withValues(alpha: 0.12);
                }
                return null;
              }),
              foregroundColor: MaterialStateProperty.resolveWith<Color>((
                states,
              ) {
                if (states.contains(MaterialState.hovered)) {
                  return AppTheme.mikuGreen;
                }
                return AppTheme.textMuted;
              }),
            ),
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Add album to playlist',
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _MobileAlbumAction extends StatelessWidget {
  const _MobileAlbumAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final iconColor = emphasized ? AppTheme.mikuGreen : AppTheme.textMuted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            foregroundColor: iconColor,
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
            disabledForegroundColor: AppTheme.textMuted.withValues(alpha: 0.55),
            fixedSize: const Size(44, 44),
            shape: const CircleBorder(),
          ),
          tooltip: label,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: iconColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
