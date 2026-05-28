import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class VocalistTabBar extends StatelessWidget {
  const VocalistTabBar({
    super.key,
    required this.index,
    required this.onTap,
    required this.albumCount,
    required this.trackCount,
    required this.mvCount,
    required this.color,
  });

  final int index;
  final ValueChanged<int> onTap;
  final int albumCount;
  final int trackCount;
  final int mvCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final labels = ['专辑 $albumCount', '歌曲 $trackCount', 'MV $mvCount'];

    return Container(
      key: const ValueKey('vocalist-detail-mobile-tabs'),
      color: AppTheme.mikuDark,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Material(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: List.generate(labels.length, (i) {
              final isActive = index == i;
              return Expanded(
                child: Material(
                  color: isActive ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 9,
                      ),
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: isActive
                                  ? Colors.black
                                  : AppTheme.textMuted,
                              fontWeight: isActive
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
