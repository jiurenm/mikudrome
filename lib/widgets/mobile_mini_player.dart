import 'package:flutter/material.dart';

import '../api/config.dart';
import '../models/track.dart';
import '../theme/app_theme.dart';

class MobileMiniPlayer extends StatelessWidget {
  const MobileMiniPlayer({
    super.key,
    required this.track,
    required this.coverUrl,
    required this.isPlaying,
    required this.progress,
    required this.onTap,
    required this.onPlayPause,
  });

  final Track track;
  final String coverUrl;
  final bool isPlaying;
  final double progress; // 0.0 to 1.0
  final VoidCallback onTap;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        color: AppTheme.footerBg,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        coverUrl,
                        headers: ApiConfig.defaultHeaders,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          color: AppTheme.cardBg,
                          child: const Icon(
                            Icons.music_note,
                            color: AppTheme.textMuted,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (track.vocal.isNotEmpty)
                            Text(
                              track.vocal,
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
                    IconButton(
                      onPressed: onPlayPause,
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: AppTheme.textPrimary,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.mikuGreen,
              ),
              minHeight: 2,
            ),
          ],
        ),
      ),
    );
  }
}
