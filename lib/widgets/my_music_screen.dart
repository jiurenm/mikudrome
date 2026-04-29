import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/config.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../services/playlist_repository.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';
import 'playlists/playlist_cover.dart';

class MyMusicScreen extends StatelessWidget {
  const MyMusicScreen({
    super.key,
    this.onNavigate,
    this.onPlaylistTap,
    this.onRecentPlayed,
    this.onQueue,
    this.playlists,
    this.currentTrack,
    this.client,
  });

  final ValueChanged<ShellRoute>? onNavigate;
  final ValueChanged<int>? onPlaylistTap;
  final VoidCallback? onRecentPlayed;
  final VoidCallback? onQueue;
  final List<Playlist>? playlists;
  final Track? currentTrack;
  final ApiClient? client;

  @override
  Widget build(BuildContext context) {
    final providedPlaylists = playlists;
    final resolvedClient = client ?? ApiClient();

    if (providedPlaylists != null) {
      return _MyMusicContent(
        playlists: providedPlaylists,
        client: resolvedClient,
        onNavigate: onNavigate,
        onPlaylistTap: onPlaylistTap,
        onRecentPlayed: onRecentPlayed,
        onQueue: onQueue,
        currentTrack: currentTrack,
      );
    }

    return AnimatedBuilder(
      animation: PlaylistRepository.instance,
      builder: (context, _) => _MyMusicContent(
        playlists: PlaylistRepository.instance.playlists,
        client: resolvedClient,
        onNavigate: onNavigate,
        onPlaylistTap: onPlaylistTap,
        onRecentPlayed: onRecentPlayed,
        onQueue: onQueue,
        currentTrack: currentTrack,
      ),
    );
  }
}

class _MyMusicContent extends StatelessWidget {
  const _MyMusicContent({
    required this.playlists,
    required this.client,
    this.onNavigate,
    this.onPlaylistTap,
    this.onRecentPlayed,
    this.onQueue,
    this.currentTrack,
  });

  final List<Playlist> playlists;
  final ApiClient client;
  final ValueChanged<ShellRoute>? onNavigate;
  final ValueChanged<int>? onPlaylistTap;
  final VoidCallback? onRecentPlayed;
  final VoidCallback? onQueue;
  final Track? currentTrack;

  @override
  Widget build(BuildContext context) {
    final favoriteTap = onNavigate == null
        ? null
        : () => onNavigate?.call(ShellRoute.favorites);
    final playlistTap = onNavigate == null
        ? null
        : () => onNavigate?.call(ShellRoute.playlists);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 96),
      children: [
        const Text(
          '我的音乐',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 2.35,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _QuickActionCard(
              icon: Icons.favorite,
              iconColor: const Color(0xFFFF4D7D),
              title: '收藏',
              subtitle: '收藏的歌曲',
              onTap: favoriteTap,
            ),
            _QuickActionCard(
              icon: Icons.music_note,
              iconColor: AppTheme.mikuGreen,
              title: '歌单',
              subtitle: '${playlists.length} 个歌单',
              onTap: playlistTap,
            ),
            _QuickActionCard(
              icon: Icons.history,
              iconColor: const Color(0xFF48A9D8),
              title: '最近播放',
              subtitle: '继续听歌',
              onTap: onRecentPlayed ?? onQueue,
            ),
            const _QuickActionCard(
              icon: Icons.download_rounded,
              iconColor: Color(0xFF9D8CFF),
              title: '下载管理',
              subtitle: '离线歌曲',
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SectionHeader(title: '最近播放', actionLabel: '更多', onTap: onQueue),
        const SizedBox(height: 10),
        if (currentTrack == null)
          _RecentPlaceholder(onTap: onQueue)
        else
          _RecentTrackCard(
            track: currentTrack!,
            client: client,
            onTap: onQueue,
          ),
        const SizedBox(height: 24),
        _SectionHeader(title: '创建的歌单', onTap: playlistTap),
        const SizedBox(height: 12),
        if (playlists.isEmpty)
          const _EmptyPlaylistState()
        else
          LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              width: constraints.maxWidth,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 18,
                children: [
                  for (final playlist in playlists)
                    _PlaylistPreviewCard(
                      playlist: playlist,
                      client: client,
                      onTap: onPlaylistTap == null
                          ? playlistTap
                          : () => onPlaylistTap?.call(playlist.id),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardBg.withValues(alpha: enabled ? 0.92 : 0.62),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Row(
            children: [
              Icon(icon, color: enabled ? iconColor : AppTheme.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: enabled
                            ? AppTheme.textPrimary
                            : AppTheme.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
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
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onTap});

  final String title;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton.icon(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textMuted,
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            label: Text(actionLabel!),
            icon: const Icon(Icons.chevron_right, size: 18),
            iconAlignment: IconAlignment.end,
          ),
      ],
    );
  }
}

class _RecentTrackCard extends StatelessWidget {
  const _RecentTrackCard({
    required this.track,
    required this.client,
    this.onTap,
  });

  final Track track;
  final ApiClient client;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final coverUrl =
        track.coverOverrideUrl ??
        (track.albumId > 0
            ? client.albumCoverUrl(track.albumId.toString())
            : '');
    final subtitle = track.vocalLine.isNotEmpty
        ? track.vocalLine
        : (track.artists.isNotEmpty ? track.artists : '未知艺术家');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.cardBg.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: coverUrl.isEmpty
                  ? const _RecentCoverFallback()
                  : Image.network(
                      coverUrl,
                      headers: ApiConfig.defaultHeaders,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const _RecentCoverFallback(),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.graphic_eq, color: AppTheme.mikuGreen, size: 18),
          ],
        ),
      ),
    );
  }
}

class _RecentCoverFallback extends StatelessWidget {
  const _RecentCoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      color: AppTheme.mikuGreen.withValues(alpha: 0.12),
      child: const Icon(Icons.music_note, color: AppTheme.mikuGreen, size: 22),
    );
  }
}

class _RecentPlaceholder extends StatelessWidget {
  const _RecentPlaceholder({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: const Row(
          children: [
            Icon(Icons.history, color: AppTheme.textMuted, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '暂无最近播放记录',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistPreviewCard extends StatelessWidget {
  const _PlaylistPreviewCard({
    required this.playlist,
    required this.client,
    this.onTap,
  });

  static const double _width = 104;
  static const double _height = 104;
  static const double _coverSize = 104;

  final Playlist playlist;
  final ApiClient client;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: _height,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PlaylistCover(
                playlist: playlist,
                client: client,
                size: _coverSize,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 18, 8, 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        playlist.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${playlist.trackCount} 首',
                        style: TextStyle(
                          color: AppTheme.textPrimary.withValues(alpha: 0.72),
                          fontSize: 10,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPlaylistState extends StatelessWidget {
  const _EmptyPlaylistState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: AppTheme.cardBg.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: const Text(
        '还没有创建歌单',
        style: TextStyle(
          color: AppTheme.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
