import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

class ProducerTabBar extends StatelessWidget {
  const ProducerTabBar({
    super.key,
    required this.index,
    required this.onTap,
    this.albumCount = 0,
    this.trackCount = 0,
    this.mvCount = 0,
  });

  final int index;
  final ValueChanged<int> onTap;
  final int albumCount;
  final int trackCount;
  final int mvCount;

  @override
  Widget build(BuildContext context) {
    if (isMobile(context)) {
      return _MobileProducerTabBar(
        index: index,
        onTap: onTap,
        albumCount: albumCount,
        trackCount: trackCount,
        mvCount: mvCount,
      );
    }

    const tabs = ['ALBUMS', 'ALL TRACKS', 'LOCAL MVs'];
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.mikuDark,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isActive = index == i;
          final label = tabs[i];
          final showBadge = i == 2 && mvCount > 0;
          return InkWell(
            onTap: () => onTap(i),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              margin: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                border: isActive
                    ? const Border(
                        bottom: BorderSide(color: AppTheme.mikuGreen, width: 2),
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isActive ? AppTheme.mikuGreen : AppTheme.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (showBadge) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.mikuGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$mvCount',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.black,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MobileProducerTabBar extends StatelessWidget {
  const _MobileProducerTabBar({
    required this.index,
    required this.onTap,
    required this.albumCount,
    required this.trackCount,
    required this.mvCount,
  });

  final int index;
  final ValueChanged<int> onTap;
  final int albumCount;
  final int trackCount;
  final int mvCount;

  @override
  Widget build(BuildContext context) {
    final labels = ['专辑 $albumCount', '歌曲 $trackCount', 'MV $mvCount'];
    return Container(
      key: const ValueKey('producer-detail-mobile-tabs'),
      color: AppTheme.mikuDark,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: List.generate(labels.length, (i) {
            final isActive = index == i;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.mikuGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isActive ? Colors.black : AppTheme.textMuted,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
