import 'package:flutter/material.dart';

import '../../models/track.dart';
import '../../theme/app_theme.dart';

class AlbumActionBar extends StatelessWidget {
  const AlbumActionBar({
    super.key,
    required this.tracks,
    required this.onPlayAll,
  });

  final List<Track> tracks;
  final VoidCallback onPlayAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
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
            onPressed: () {},
            style: ButtonStyle(
              side: MaterialStateProperty.resolveWith<BorderSide>((states) {
                if (states.contains(MaterialState.hovered)) {
                  return const BorderSide(color: AppTheme.mikuGreen);
                }
                return const BorderSide(color: AppTheme.textMuted);
              }),
              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
                const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              foregroundColor:
                  MaterialStateProperty.all<Color>(AppTheme.textPrimary),
            ),
            child: const Icon(Icons.shuffle, size: 22),
          ),
          const SizedBox(width: 24),
          IconButton(
            onPressed: () {},
            style: IconButton.styleFrom(
              iconSize: 28,
            ).copyWith(
              overlayColor: MaterialStateProperty.resolveWith<Color?>((states) {
                if (states.contains(MaterialState.hovered)) {
                  return AppTheme.mikuGreen.withValues(alpha: 0.12);
                }
                return null;
              }),
              foregroundColor:
                  MaterialStateProperty.resolveWith<Color>((states) {
                if (states.contains(MaterialState.hovered)) {
                  return AppTheme.mikuGreen;
                }
                return AppTheme.textMuted;
              }),
            ),
            icon: const Icon(Icons.favorite_border),
          ),
        ],
      ),
    );
  }
}
