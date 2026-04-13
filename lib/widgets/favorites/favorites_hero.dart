import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

class FavoritesHero extends StatelessWidget {
  const FavoritesHero({
    super.key,
    required this.trackCount,
    required this.onPlay,
  });

  final int trackCount;
  final VoidCallback onPlay;

  static final _gradient = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.pink.shade900.withValues(alpha: 0.3),
        AppTheme.mikuDark,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);

    if (mobile) {
      return _buildMobileLayout(context, _gradient);
    }
    return _buildDesktopLayout(context, _gradient);
  }

  Widget _buildMobileLayout(BuildContext context, BoxDecoration gradient) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final iconSize = screenWidth * 0.3;

    return Container(
      decoration: gradient,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.pink.shade400,
                  Colors.red.shade600,
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.favorite,
              size: iconSize * 0.6,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'FAVORITES',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.pink.shade300,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Favorite Tracks',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            '$trackCount tracks',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
          const SizedBox(height: 16),
          Semantics(
            label: 'Play all favorites',
            button: true,
            child: FilledButton.icon(
              onPressed: trackCount > 0 ? onPlay : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.pink.shade600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text('PLAY'),
            ),
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
          Container(
            width: 224,
            height: 224,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.pink.shade400,
                  Colors.red.shade600,
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.favorite,
              size: 120,
              color: Colors.white,
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
                    'FAVORITES',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.pink.shade300,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Favorite Tracks',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        '$trackCount tracks',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                      ),
                      const SizedBox(width: 24),
                      Semantics(
                        label: 'Play all favorites',
                        button: true,
                        child: FilledButton.icon(
                          onPressed: trackCount > 0 ? onPlay : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.pink.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow, size: 20),
                          label: const Text('PLAY'),
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
