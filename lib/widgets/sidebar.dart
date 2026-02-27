import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_shell.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.currentRoute,
    this.onNavigate,
  });

  final ShellRoute currentRoute;
  final ValueChanged<ShellRoute>? onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 256,
      decoration: BoxDecoration(
        color: AppTheme.mikuDark,
        border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppTheme.mikuGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'MIKUDROME',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _sectionLabel('Library'),
          const SizedBox(height: 8),
          _navItem(ShellRoute.albums, Icons.album_outlined, 'Albums'),
          _navItem(ShellRoute.producers, Icons.person_outline, 'Producers'),
          _navItem(ShellRoute.vocalists, Icons.mic_none, 'Vocalists'),
          _navItem(ShellRoute.nasFolders, Icons.folder_outlined, 'NAS Folders'),
          const SizedBox(height: 24),
          _sectionLabel('Collections'),
          const SizedBox(height: 8),
          _navItem(ShellRoute.favorites, Icons.favorite_border, 'Favorite Tracks'),
          _navItem(ShellRoute.localMv, Icons.movie_outlined, 'Local MV Gallery'),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 2,
          color: AppTheme.textMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _navItem(ShellRoute route, IconData icon, String label) {
    final active = currentRoute == route;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active
            ? AppTheme.mikuGreen.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
        child: InkWell(
          onTap: () => onNavigate?.call(route),
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(4),
            bottomRight: Radius.circular(4),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              border: active
                  ? const Border(right: BorderSide(color: AppTheme.mikuGreen, width: 3))
                  : null,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: active ? AppTheme.mikuGreen : AppTheme.textMuted,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: active ? AppTheme.mikuGreen : AppTheme.textMuted,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
