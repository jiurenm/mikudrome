import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class ProducerTabBar extends StatelessWidget {
  const ProducerTabBar({
    super.key,
    required this.index,
    required this.onTap,
    this.mvCount = 0,
  });

  final int index;
  final ValueChanged<int> onTap;
  final int mvCount;

  @override
  Widget build(BuildContext context) {
    const tabs = ['ALBUMS', 'ALL TRACKS', 'LOCAL MVs'];
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.mikuDark,
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
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
                        bottom: BorderSide(color: AppTheme.mikuGreen, width: 2))
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: isActive
                              ? AppTheme.mikuGreen
                              : AppTheme.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (showBadge) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
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
