import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_shell.dart';

class MobileMoreScreen extends StatelessWidget {
  const MobileMoreScreen({
    super.key,
    required this.onNavigate,
  });

  final ValueChanged<ShellRoute> onNavigate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        _MoreItem(
          icon: Icons.folder_outlined,
          label: 'NAS Folders',
          onTap: () => onNavigate(ShellRoute.nasFolders),
        ),
        _MoreItem(
          icon: Icons.favorite_outline,
          label: 'Favorites',
          onTap: () => onNavigate(ShellRoute.favorites),
        ),
        _MoreItem(
          icon: Icons.video_library_outlined,
          label: 'Local MV Gallery',
          onTap: () => onNavigate(ShellRoute.localMv),
        ),
      ],
    );
  }
}

class _MoreItem extends StatelessWidget {
  const _MoreItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.textPrimary),
      title: Text(
        label,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
      ),
      onTap: onTap,
    );
  }
}
