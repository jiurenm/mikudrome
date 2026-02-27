import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Persistent bottom bar: now playing + controls + progress + MV indicator.
class NowPlayingBar extends StatelessWidget {
  const NowPlayingBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: AppTheme.footerBg,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          _buildLeft(context),
          Expanded(child: _buildCenter(context)),
          _buildRight(context),
        ],
      ),
    );
  }

  Widget _buildLeft(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width * 0.25,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              'https://api.dicebear.com/7.x/identicon/svg?seed=nowplaying',
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 56,
                height: 56,
                color: AppTheme.cardBg,
                child: const Icon(Icons.music_note, color: AppTheme.textMuted),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ノンブレス・オブリージュ',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'ピノキオピー • 初音ミク',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.mikuGreen,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border, color: AppTheme.textMuted, size: 22),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildCenter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shuffle, color: AppTheme.textMuted, size: 20),
                onPressed: () {},
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.skip_previous, color: AppTheme.textPrimary, size: 28),
                onPressed: () {},
              ),
              const SizedBox(width: 16),
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () {},
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.play_arrow, color: Colors.black, size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.skip_next, color: AppTheme.textPrimary, size: 28),
                onPressed: () {},
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.repeat, color: AppTheme.textMuted, size: 20),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '01:24',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMuted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: 0.33,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.mikuGreen),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '03:52',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMuted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRight(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width * 0.25,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.movie, color: AppTheme.mikuGreen, size: 22),
              const SizedBox(height: 2),
              Text(
                'MV ACTIVE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.mikuGreen,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          IconButton(
            icon: const Icon(Icons.queue_music, color: AppTheme.textMuted),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          const Icon(Icons.volume_up, color: AppTheme.textMuted, size: 20),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: 0.66,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.textMuted),
                minHeight: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
