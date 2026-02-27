import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'sidebar.dart';
import 'now_playing_bar.dart';

enum ShellRoute { albums, producers, vocalists, nasFolders, favorites, localMv }

/// Main layout: sidebar + content + persistent bottom player bar.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.child,
    this.currentRoute = ShellRoute.albums,
    this.onNavigate,
  });

  final Widget child;
  final ShellRoute currentRoute;
  final ValueChanged<ShellRoute>? onNavigate;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
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
