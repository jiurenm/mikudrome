import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../models/producer.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

class ProducerHeroSection extends StatelessWidget {
  const ProducerHeroSection({
    super.key,
    required this.producer,
    required this.baseUrl,
    required this.onPlayAll,
    required this.onShuffle,
    required this.hasTracks,
    this.albumCount,
    this.trackCount,
    this.mvCount = 0,
  });

  final Producer producer;
  final String baseUrl;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;
  final bool hasTracks;
  final int? albumCount;
  final int? trackCount;
  final int mvCount;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = ApiClient(
      baseUrl: baseUrl,
    ).producerAvatarUrl(producer.id);
    final mobile = isMobile(context);
    final avatarSize = mobile ? 80.0 : 192.0;

    Widget avatarWidget = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.mikuGreen.withValues(alpha: 0.2),
          width: mobile ? 3 : 4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          avatarUrl,
          headers: ApiConfig.defaultHeaders,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppTheme.cardBg,
            child: Icon(
              Icons.person,
              color: AppTheme.textMuted,
              size: mobile ? 40 : 64,
            ),
          ),
        ),
      ),
    );

    Widget nameWidget = SelectableText(
      producer.name,
      style: Theme.of(context).textTheme.displayLarge?.copyWith(
        color: AppTheme.textPrimary,
        fontWeight: FontWeight.w900,
        letterSpacing: -1,
        fontSize: mobile ? 24 : null,
      ),
      textAlign: mobile ? TextAlign.center : TextAlign.start,
    );

    Widget statsWidget = Text(
      '${producer.trackCount} Tracks across ${producer.albumCount} Albums in your NAS.',
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
      textAlign: mobile ? TextAlign.center : TextAlign.start,
    );

    Widget shuffleButton = FilledButton.icon(
      onPressed: hasTracks ? onShuffle : null,
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.mikuGreen,
        foregroundColor: Colors.black,
        padding: EdgeInsets.symmetric(
          horizontal: mobile ? 24 : 32,
          vertical: mobile ? 14 : 18,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      icon: const Icon(Icons.shuffle),
      label: const Text('SHUFFLE CREATOR'),
    );

    if (mobile) {
      final loadedTrackCount = trackCount ?? producer.trackCount;
      final loadedAlbumCount = albumCount ?? producer.albumCount;

      return Container(
        key: const ValueKey('producer-detail-mobile-hero'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            avatarWidget,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    producer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$loadedTrackCount 首歌曲 · $loadedAlbumCount 张专辑 · $mvCount 个MV',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: hasTracks ? onPlayAll : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.mikuGreen,
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
                        icon: const Icon(Icons.play_arrow, size: 20),
                        label: const Text('播放全部'),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        key: const ValueKey('producer-detail-mobile-shuffle'),
                        onPressed: hasTracks ? onShuffle : null,
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.mikuGreen.withValues(
                            alpha: 0.16,
                          ),
                          foregroundColor: AppTheme.mikuGreen,
                          disabledBackgroundColor: Colors.white.withValues(
                            alpha: 0.04,
                          ),
                          disabledForegroundColor: AppTheme.textMuted,
                        ),
                        tooltip: '随机播放',
                        icon: const Icon(Icons.shuffle),
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

    return Stack(
      children: [
        SizedBox(
          height: 384,
          width: double.infinity,
          child: Image.network(
            avatarUrl,
            headers: ApiConfig.defaultHeaders,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: AppTheme.cardBg),
          ),
        ),
        Container(
          height: 384,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.mikuDark.withValues(alpha: 0.5),
                AppTheme.mikuDark,
              ],
            ),
          ),
        ),
        Positioned(
          left: 48,
          right: 48,
          bottom: 32,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              avatarWidget,
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    nameWidget,
                    const SizedBox(height: 16),
                    statsWidget,
                  ],
                ),
              ),
              shuffleButton,
            ],
          ),
        ),
      ],
    );
  }
}
