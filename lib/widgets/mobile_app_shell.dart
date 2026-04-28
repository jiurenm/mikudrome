import 'package:flutter/material.dart';

import '../api/config.dart';
import '../theme/app_theme.dart';
import 'discover_screen.dart';
import 'my_music_screen.dart';
import 'settings_screen.dart';

enum MobileAppTab { discover, myMusic, settings }

class MobileAppShell extends StatefulWidget {
  const MobileAppShell({
    super.key,
    this.currentTab,
    this.onTabChanged,
    this.discover,
    this.myMusic,
    this.settings,
  });

  final MobileAppTab? currentTab;
  final ValueChanged<MobileAppTab>? onTabChanged;
  final Widget? discover;
  final Widget? myMusic;
  final Widget? settings;

  @override
  State<MobileAppShell> createState() => _MobileAppShellState();
}

class _MobileAppShellState extends State<MobileAppShell> {
  MobileAppTab _tab = MobileAppTab.discover;

  MobileAppTab get _currentTab => widget.currentTab ?? _tab;

  int _tabToIndex(MobileAppTab tab) {
    return switch (tab) {
      MobileAppTab.discover => 0,
      MobileAppTab.myMusic => 1,
      MobileAppTab.settings => 2,
    };
  }

  MobileAppTab _indexToTab(int index) {
    return switch (index) {
      1 => MobileAppTab.myMusic,
      2 => MobileAppTab.settings,
      _ => MobileAppTab.discover,
    };
  }

  void _selectTab(int index) {
    final tab = _indexToTab(index);
    widget.onTabChanged?.call(tab);
    if (widget.currentTab == null) {
      setState(() {
        _tab = tab;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = _currentTab;

    return Scaffold(
      backgroundColor: AppTheme.mikuDark,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tabToIndex(currentTab),
          children: [
            widget.discover ?? const DiscoverScreen(),
            widget.myMusic ?? const MyMusicScreen(),
            widget.settings ??
                SettingsScreen(
                  serverUrl: ApiConfig.defaultBaseUrl,
                  hasServerCookie: ApiConfig.defaultHeaders.containsKey(
                    'Cookie',
                  ),
                ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _tabToIndex(currentTab),
          onTap: _selectTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.footerBg,
          selectedItemColor: AppTheme.mikuGreen,
          unselectedItemColor: AppTheme.textMuted,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: '发现',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.library_music_outlined),
              activeIcon: Icon(Icons.library_music),
              label: '我的音乐',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: '设置',
            ),
          ],
        ),
      ),
    );
  }
}
