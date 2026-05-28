import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../theme/app_theme.dart';

class VocalistHeroSection extends StatelessWidget {
  const VocalistHeroSection({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.color,
    required this.trackCount,
    required this.albumCount,
    required this.mvCount,
    required this.hasTracks,
    required this.onPlayAll,
    required this.onShuffle,
  });

  final String name;
  final String avatarUrl;
  final Color color;
  final int trackCount;
  final int albumCount;
  final int mvCount;
  final bool hasTracks;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    final mutedColor = color.withValues(alpha: 0.14);
    final borderColor = color.withValues(alpha: 0.24);

    return Container(
      key: const ValueKey('vocalist-detail-mobile-hero'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            AppTheme.cardBg,
            AppTheme.cardBg,
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: mutedColor,
              border: Border.all(color: borderColor, width: 3),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.22),
                  blurRadius: 28,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              avatarUrl,
              headers: ApiConfig.defaultHeaders,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: mutedColor,
                child: Icon(Icons.mic_rounded, color: color, size: 42),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$trackCount 首歌曲 · $albumCount 张专辑 · $mvCount 个MV',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: hasTracks ? onPlayAll : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.white.withValues(
                          alpha: 0.08,
                        ),
                        disabledForegroundColor: AppTheme.textMuted,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('播放全部'),
                    ),
                    IconButton.filled(
                      key: const ValueKey('vocalist-detail-mobile-shuffle'),
                      onPressed: hasTracks ? onShuffle : null,
                      style: IconButton.styleFrom(
                        backgroundColor: color.withValues(alpha: 0.16),
                        foregroundColor: color,
                        disabledBackgroundColor: Colors.white.withValues(
                          alpha: 0.04,
                        ),
                        disabledForegroundColor: AppTheme.textMuted,
                      ),
                      tooltip: '随机播放',
                      icon: const Icon(Icons.shuffle_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
