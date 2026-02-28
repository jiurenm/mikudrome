import 'package:flutter/material.dart';

import '../models/album.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import 'album_detail_screen.dart';
import 'albums_screen.dart';
import 'producers_screen.dart';

const String _kDefaultBaseUrl = 'http://127.0.0.1:8081';

/// Root screen: app shell + route-based content. Album detail is shown in-shell (sidebar stays).
class LibraryHomeScreen extends StatefulWidget {
  const LibraryHomeScreen({super.key});

  @override
  State<LibraryHomeScreen> createState() => _LibraryHomeScreenState();
}

class _LibraryHomeScreenState extends State<LibraryHomeScreen> {
  ShellRoute _route = ShellRoute.albums;
  Album? _selectedAlbum;

  Widget _contentForRoute(ShellRoute route) {
    switch (route) {
      case ShellRoute.albums:
        return AlbumsScreen(
          baseUrl: _kDefaultBaseUrl,
          onAlbumTap: (album) => setState(() => _selectedAlbum = album),
        );
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
    final Widget content = _selectedAlbum != null
        ? AlbumDetailScreen(
            album: _selectedAlbum!,
            baseUrl: _kDefaultBaseUrl,
          )
        : _contentForRoute(_route);

    return AppShell(
      currentRoute: _route,
      onNavigate: (r) => setState(() {
        _route = r;
        _selectedAlbum = null;
      }),
      child: content,
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
