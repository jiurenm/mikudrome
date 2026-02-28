import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'sidebar.dart';
import 'now_playing_bar.dart';

enum ShellRoute { albums, producers, vocalists, nasFolders, favorites, localMv }

/// Breakpoint for responsive layout: below this width, sidebar starts collapsed
/// (e.g. tablet/mobile). Can be overridden via [initialSidebarCollapsed].
const double kShellSidebarBreakpoint = 768;

/// Main layout: collapsible sidebar + content + persistent bottom player bar.
/// Web: sidebar can be toggled; narrow viewports start with sidebar collapsed.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.child,
    this.currentRoute = ShellRoute.albums,
    this.onNavigate,
    this.initialSidebarCollapsed,
  });

  final Widget child;
  final ShellRoute currentRoute;
  final ValueChanged<ShellRoute>? onNavigate;
  /// If null, uses breakpoint: collapsed when width < [kShellSidebarBreakpoint].
  final bool? initialSidebarCollapsed;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool? _sidebarCollapsedOverride;

  bool _sidebarCollapsed(BuildContext context) {
    if (_sidebarCollapsedOverride != null) return _sidebarCollapsedOverride!;
    final width = MediaQuery.sizeOf(context).width;
    return width < kShellSidebarBreakpoint;
  }

  void _toggleSidebar(BuildContext context) {
    setState(() {
      _sidebarCollapsedOverride = !_sidebarCollapsed(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = _sidebarCollapsed(context);
    return Scaffold(
      backgroundColor: AppTheme.mikuDark,
      body: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Sidebar(
                  currentRoute: widget.currentRoute,
                  onNavigate: widget.onNavigate,
                  collapsed: collapsed,
                  onToggleCollapsed: () => _toggleSidebar(context),
                ),
                Expanded(
                  child: Material(
                    color: AppTheme.mikuDark,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
          const NowPlayingBar(),
        ],
      ),
    );
  }
}
