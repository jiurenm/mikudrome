import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import 'albums_screen.dart';
import 'producers_screen.dart';

/// Root screen: app shell + route-based content (Albums / Producers / etc.).
class LibraryHomeScreen extends StatefulWidget {
  const LibraryHomeScreen({super.key});

  @override
  State<LibraryHomeScreen> createState() => _LibraryHomeScreenState();
}

class _LibraryHomeScreenState extends State<LibraryHomeScreen> {
  ShellRoute _route = ShellRoute.albums;

  Widget _contentForRoute(ShellRoute route) {
    switch (route) {
      case ShellRoute.albums:
        return const AlbumsScreen();
      case ShellRoute.producers:
        return const ProducersScreen();
      case ShellRoute.vocalists:
        return _PlaceholderScreen(
          title: 'Vocalists',
          subtitle: 'Browse by vocalist (e.g. 初音ミク)',
        );
      case ShellRoute.nasFolders:
        return _PlaceholderScreen(
          title: 'NAS Folders',
          subtitle: 'Browse by folder structure',
        );
      case ShellRoute.favorites:
        return _PlaceholderScreen(
          title: 'Favorite Tracks',
          subtitle: 'Your liked tracks',
        );
      case ShellRoute.localMv:
        return _PlaceholderScreen(
          title: 'Local MV Gallery',
          subtitle: 'All tracks with local MV',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: _route,
      onNavigate: (r) => setState(() => _route = r),
      child: _contentForRoute(_route),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}
