import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_shell.dart';

class MyMusicScreen extends StatelessWidget {
  const MyMusicScreen({
    super.key,
    this.onNavigate,
    this.onRecentPlayed,
    this.onQueue,
  });

  final ValueChanged<ShellRoute>? onNavigate;
  final VoidCallback? onRecentPlayed;
  final VoidCallback? onQueue;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        _MusicItem(
          icon: Icons.favorite_outline,
          label: '收藏',
          onTap: () => onNavigate?.call(ShellRoute.favorites),
        ),
        _MusicItem(
          icon: Icons.queue_music_outlined,
          label: '歌单',
          onTap: () => onNavigate?.call(ShellRoute.playlists),
        ),
        _MusicItem(icon: Icons.history, label: '最近播放', onTap: onRecentPlayed),
        _MusicItem(icon: Icons.playlist_play, label: '当前队列', onTap: onQueue),
      ],
    );
  }
}

class _MusicItem extends StatelessWidget {
  const _MusicItem({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: onTap != null,
      leading: Icon(
        icon,
        color: onTap == null ? AppTheme.textMuted : AppTheme.textPrimary,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: onTap == null ? AppTheme.textMuted : AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: onTap == null ? Colors.transparent : AppTheme.textMuted,
      ),
      onTap: onTap,
    );
  }
}
