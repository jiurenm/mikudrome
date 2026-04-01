import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_shell.dart';

class MobileBottomNav extends StatelessWidget {
  const MobileBottomNav({
    super.key,
    required this.currentRoute,
    required this.onNavigate,
  });

  final ShellRoute currentRoute;
  final ValueChanged<ShellRoute> onNavigate;

  int _routeToIndex(ShellRoute route) {
    switch (route) {
      case ShellRoute.albums:
        return 0;
      case ShellRoute.producers:
        return 1;
      case ShellRoute.vocalists:
        return 2;
      default:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _routeToIndex(currentRoute),
      onTap: (index) {
        switch (index) {
          case 0:
            onNavigate(ShellRoute.albums);
            break;
          case 1:
            onNavigate(ShellRoute.producers);
            break;
          case 2:
            onNavigate(ShellRoute.vocalists);
            break;
          case 3:
            onNavigate(ShellRoute.nasFolders);
            break;
        }
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppTheme.footerBg,
      selectedItemColor: AppTheme.mikuGreen,
      unselectedItemColor: AppTheme.textMuted,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.album),
          label: 'Albums',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Producers',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.mic),
          label: 'Vocalists',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.more_horiz),
          label: 'More',
        ),
      ],
    );
  }
}
