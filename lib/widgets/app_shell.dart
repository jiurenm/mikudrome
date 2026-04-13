import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'mobile_bottom_nav.dart';
import 'sidebar.dart';
import 'now_playing_bar.dart';

enum ShellRoute { albums, producers, vocalists, playlists, favorites, localMv, more }

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
    this.forceSidebarCollapsed = false,
    this.nowPlayingBar = const NowPlayingBar(),
  });

  final Widget child;
  final ShellRoute currentRoute;
  final ValueChanged<ShellRoute>? onNavigate;
  /// If null, uses breakpoint: collapsed when width < [kShellSidebarBreakpoint].
  final bool? initialSidebarCollapsed;
  final bool forceSidebarCollapsed;
  final Widget nowPlayingBar;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool? _sidebarCollapsedOverride;

  bool _sidebarCollapsed(BuildContext context) {
    if (widget.forceSidebarCollapsed) return true;
    if (_sidebarCollapsedOverride != null) return _sidebarCollapsedOverride!;
    if (widget.initialSidebarCollapsed != null) {
      return widget.initialSidebarCollapsed!;
    }
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
    if (isMobile(context)) {
      // Mobile layout: content + bottom tab bar only.
      // NowPlayingBar is NOT rendered here (replaced by MobilePlayerSheet
      // in LibraryHomeScreen). Sidebar is not rendered.
      return Scaffold(
        backgroundColor: AppTheme.mikuDark,
        body: widget.child,
        bottomNavigationBar: SafeArea(
          child: MobileBottomNav(
            currentRoute: widget.currentRoute,
            onNavigate: widget.onNavigate ?? (_) {},
          ),
        ),
      );
    }

    // --- existing desktop layout below (unchanged) ---
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
          widget.nowPlayingBar,
        ],
      ),
    );
  }
}
