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
      case ShellRoute.localMv:
        return 1;
      default:
        return 0;
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
            onNavigate(ShellRoute.localMv);
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
          icon: Icon(Icons.movie_outlined),
          label: 'MV Gallery',
        ),
      ],
    );
  }
}
