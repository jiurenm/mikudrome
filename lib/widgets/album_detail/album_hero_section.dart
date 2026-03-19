import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../models/album.dart';
import '../../models/producer.dart';
import '../../models/track.dart';
import '../../theme/app_theme.dart';

class AlbumHeroSection extends StatelessWidget {
  const AlbumHeroSection({
    super.key,
    required this.album,
    this.tracks = const [],
    required this.baseUrl,
    this.onProducerTap,
  });

  final Album album;
  final List<Track> tracks;
  final String baseUrl;
  final ValueChanged<Producer>? onProducerTap;

  static int _earliestYear(List<Track> tracks) {
    int minYear = 0;
    for (final t in tracks) {
      if (t.year > 0 && (minYear == 0 || t.year < minYear)) {
        minYear = t.year;
      }
    }
    return minYear;
  }

  static int _totalDurationSeconds(List<Track> tracks) {
    return tracks.fold(0, (s, t) => s + t.durationSeconds);
  }

  static String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '';
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h > 0) {
      return '${h} h ${m} min';
    }
    return '$m min';
  }

  @override
  Widget build(BuildContext context) {
    final year = tracks.isNotEmpty ? _earliestYear(tracks) : album.year;
    final totalSec = _totalDurationSeconds(tracks);
    final durationStr = _formatDuration(totalSec);

    return Container(
      height: 320,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.mikuGreen.withValues(alpha: 0.2),
            AppTheme.mikuDark,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              album.coverUrl,
              width: 224,
              height: 224,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 224,
                height: 224,
                color: AppTheme.cardBg,
                child: const Icon(Icons.album,
                    color: AppTheme.textMuted, size: 64),
              ),
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
                    'ALBUM',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.mikuGreen,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    album.title,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (album.producerName.isNotEmpty) ...[
                        MouseRegion(
                          cursor: album.producerId > 0 && onProducerTap != null
                              ? SystemMouseCursors.click
                              : SystemMouseCursors.basic,
                          child: GestureDetector(
                            onTap: album.producerId > 0 && onProducerTap != null
                                ? () => onProducerTap!(Producer(
                                      id: album.producerId,
                                      name: album.producerName,
                                      trackCount: 0,
                                      albumCount: 0,
                                    ))
                                : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipOval(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: album.producerId == 0
                                        ? const ColoredBox(
                                            color: AppTheme.cardBg,
                                            child: Icon(
                                              Icons.person,
                                              size: 16,
                                              color: AppTheme.textMuted,
                                            ),
                                          )
                                        : Image.network(
                                            ApiClient(baseUrl: baseUrl)
                                                .producerAvatarUrl(
                                                    album.producerId),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const ColoredBox(
                                              color: AppTheme.cardBg,
                                              child: Icon(
                                                Icons.person,
                                                size: 16,
                                                color: AppTheme.textMuted,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  album.producerName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: album.producerId > 0 &&
                                                onProducerTap != null
                                            ? AppTheme.mikuGreen
                                            : AppTheme.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        decoration: album.producerId > 0 &&
                                                onProducerTap != null
                                            ? TextDecoration.underline
                                            : null,
                                        decorationColor: AppTheme.mikuGreen,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (year > 0) ...[
                        Text(
                          '• $year',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textMuted,
                                  ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        durationStr.isNotEmpty
                            ? '• ${album.trackCount} Songs, $durationStr'
                            : '• ${album.trackCount} Songs',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                            ),
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
