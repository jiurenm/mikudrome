import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

class PlaylistEditBar extends StatelessWidget {
  const PlaylistEditBar({
    super.key,
    required this.onDone,
    required this.onAddGroup,
  });

  final VoidCallback onDone;
  final VoidCallback onAddGroup;

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 16 : 40,
        vertical: mobile ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardBg.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          FilledButton.tonalIcon(
            onPressed: onAddGroup,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('ADD GROUP'),
            style: FilledButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              Semantics(
                label: 'Drag to reorder',
                child: const Icon(
                  Icons.drag_handle,
                  size: 20,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Drag to reorder',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
            ],
          ),
          const Spacer(),
          FilledButton(
            onPressed: onDone,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.mikuGreen,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(
                horizontal: mobile ? 20 : 24,
                vertical: mobile ? 10 : 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('DONE'),
          ),
        ],
      ),
    );
  }
}
