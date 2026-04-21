import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import 'app_shell.dart';

/// Sidebar with optional collapsed state: expanded shows full nav + labels,
/// collapsed shows icon-only strip with chevron toggle (for web/mobile).
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.currentRoute,
    this.onNavigate,
    this.collapsed = false,
    this.onToggleCollapsed,
  });

  final ShellRoute currentRoute;
  final ValueChanged<ShellRoute>? onNavigate;
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;

  static const double widthExpanded = 256;
  static const double widthCollapsed = 80;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: collapsed ? widthCollapsed : widthExpanded,
      decoration: BoxDecoration(
        color: AppTheme.mikuDark,
        border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Stack(
        children: [
          // Expanded UI
          AnimatedOpacity(
            opacity: collapsed ? 0 : 1,
            duration: const Duration(milliseconds: 150),
            child: IgnorePointer(
              ignoring: collapsed,
              child: _buildExpanded(context),
            ),
          ),

          // Collapsed UI
          AnimatedOpacity(
            opacity: collapsed ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: IgnorePointer(
              ignoring: !collapsed,
              child: _buildCollapsed(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsed(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 24),
        _collapseButton(context, expanded: true),
        const SizedBox(height: 32),
        _navIconOnly(ShellRoute.albums, Icons.album_outlined),
        _navIconOnly(ShellRoute.producers, Icons.person_outline),
        _navIconOnly(ShellRoute.vocalists, Icons.mic_none),
        const SizedBox(height: 16),
        _navIconOnly(ShellRoute.playlists, Icons.queue_music),
        _navIconOnly(ShellRoute.favorites, Icons.favorite_border),
        _navIconOnly(ShellRoute.localMv, Icons.movie_outlined),
        _navIconOnly(ShellRoute.more, Icons.more_horiz),
      ],
    );
  }

  Widget _buildExpanded(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: SvgPicture.network(
                  '/icon.svg',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'MIKUDROME',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _collapseButton(context, expanded: false),
            ],
          ),
          const SizedBox(height: 32),
          _sectionLabel('Library'),
          const SizedBox(height: 8),
          _navItem(ShellRoute.albums, Icons.album_outlined, 'Albums'),
          _navItem(ShellRoute.producers, Icons.person_outline, 'Producers'),
          _navItem(ShellRoute.vocalists, Icons.mic_none, 'Vocalists'),
          const SizedBox(height: 24),
          _sectionLabel('Collections'),
          const SizedBox(height: 8),
          _navItem(ShellRoute.playlists, Icons.queue_music, 'Playlists'),
          _navItem(ShellRoute.favorites, Icons.favorite_border, 'Favorite Tracks'),
          _navItem(ShellRoute.localMv, Icons.movie_outlined, 'Local MV Gallery'),
          _navItem(ShellRoute.more, Icons.more_horiz, 'More'),
        ],
      ),
    );
  }

  Widget _collapseButton(BuildContext context, {required bool expanded}) {
    return IconButton(
      onPressed: onToggleCollapsed,
      icon: Icon(
        expanded ? Icons.chevron_right : Icons.chevron_left,
        color: AppTheme.textMuted,
        size: 22,
      ),
      style: IconButton.styleFrom(
        foregroundColor: AppTheme.textMuted,
      ),
      tooltip: expanded ? 'Expand sidebar' : 'Collapse sidebar',
    );
  }

  Widget _sectionLabel(String label) {
    if (collapsed) return const SizedBox.shrink();
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

  Widget _navIconOnly(ShellRoute route, IconData icon) {
    final active = currentRoute == route;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active
            ? AppTheme.mikuGreen.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => onNavigate?.call(route),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 22,
              color: active ? AppTheme.mikuGreen : AppTheme.textMuted,
            ),
          ),
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
