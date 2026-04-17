import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum PlaylistDisplayMode { list, cover }

class PlaylistDisplayModeSwitch extends StatelessWidget {
  const PlaylistDisplayModeSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PlaylistDisplayMode value;
  final ValueChanged<PlaylistDisplayMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PlaylistDisplayMode>(
      key: const ValueKey('playlist-display-mode-switch'),
      segments: const [
        ButtonSegment<PlaylistDisplayMode>(
          value: PlaylistDisplayMode.list,
          icon: Icon(
            Icons.view_list_rounded,
            key: ValueKey('playlist-display-mode-list-icon'),
            size: 18,
          ),
          tooltip: '歌单',
        ),
        ButtonSegment<PlaylistDisplayMode>(
          value: PlaylistDisplayMode.cover,
          icon: Icon(
            Icons.grid_view_rounded,
            key: ValueKey('playlist-display-mode-cover-icon'),
            size: 18,
          ),
          tooltip: '封面',
        ),
      ],
      selected: {value},
      showSelectedIcon: false,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 40)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTheme.mikuGreen.withValues(alpha: 0.16);
          }
          return AppTheme.cardBg;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTheme.textPrimary;
          }
          return AppTheme.textMuted;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? AppTheme.mikuGreen.withValues(alpha: 0.42)
              : Colors.white.withValues(alpha: 0.08);
          return BorderSide(color: color);
        }),
      ),
      onSelectionChanged: (selection) {
        onChanged(selection.first);
      },
    );
  }
}
