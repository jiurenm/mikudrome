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
          label: Text('歌单'),
          icon: Icon(Icons.view_list_rounded),
        ),
        ButtonSegment<PlaylistDisplayMode>(
          value: PlaylistDisplayMode.cover,
          label: Text('封面'),
          icon: Icon(Icons.grid_view_rounded),
        ),
      ],
      selected: {value},
      showSelectedIcon: false,
      style: ButtonStyle(
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
