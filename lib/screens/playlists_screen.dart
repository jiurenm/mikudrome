import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/playlist.dart';
import '../services/playlist_repository.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/playlists/new_playlist_dialog.dart';
import '../widgets/playlists/playlist_grid_card.dart';
import '../widgets/playlists/rename_playlist_dialog.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({
    super.key,
    this.onPlaylistTap,
  });

  final ValueChanged<int>? onPlaylistTap;

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  final _client = ApiClient();
  bool _loading = false;
  bool _operationInProgress = false;

  // UI constants
  static const double _gridSpacing = 12.0;
  static const double _menuIconSize = 18.0;
  static const double _menuButtonSize = 32.0;

  @override
  void initState() {
    super.initState();
    PlaylistRepository.instance.initialize(_client);
    _loadPlaylists();
  }

  @override
  void dispose() {
    // ApiClient uses static http methods, no resources to dispose
    super.dispose();
  }

  String _getMimeType(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _loadPlaylists() async {
    setState(() => _loading = true);
    try {
      await PlaylistRepository.instance.refreshPlaylists(_client);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load playlists: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createPlaylist() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const NewPlaylistDialog(),
    );
    if (name == null || !mounted) return;

    setState(() => _operationInProgress = true);
    try {
      final playlist = await _client.createPlaylist(name);
      PlaylistRepository.instance.upsertPlaylist(playlist);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created playlist "$name"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create playlist: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _operationInProgress = false);
      }
    }
  }

  Future<void> _renamePlaylist(Playlist playlist) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => RenamePlaylistDialog(initialName: playlist.name),
    );
    if (newName == null || !mounted) return;

    setState(() => _operationInProgress = true);
    try {
      await _client.renamePlaylist(playlist.id, newName);
      final updated = await _client.getPlaylist(playlist.id);
      if (updated != null) {
        PlaylistRepository.instance.upsertPlaylist(updated);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Renamed to "$newName"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to rename playlist: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _operationInProgress = false);
      }
    }
  }

  Future<void> _deletePlaylist(Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Playlist'),
        content: Text('Delete "${playlist.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _operationInProgress = true);
    try {
      await _client.deletePlaylist(playlist.id);
      PlaylistRepository.instance.removePlaylist(playlist.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "${playlist.name}"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete playlist: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _operationInProgress = false);
      }
    }
  }

  Future<void> _uploadCover(Playlist playlist) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = kIsWeb ? file.bytes : await File(file.path!).readAsBytes();
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to read file')),
        );
        return;
      }

      setState(() => _operationInProgress = true);
      await _client.uploadPlaylistCover(
        playlist.id,
        bytes,
        file.name,
        _getMimeType(file.name),
      );
      final updated = await _client.getPlaylist(playlist.id);
      if (updated != null) {
        PlaylistRepository.instance.upsertPlaylist(updated);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cover uploaded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload cover: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _operationInProgress = false);
      }
    }
  }

  Future<void> _clearCover(Playlist playlist) async {
    setState(() => _operationInProgress = true);
    try {
      await _client.clearPlaylistCover(playlist.id);
      final updated = await _client.getPlaylist(playlist.id);
      if (updated != null) {
        PlaylistRepository.instance.upsertPlaylist(updated);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cover cleared')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear cover: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _operationInProgress = false);
      }
    }
  }

  void _showPlaylistMenu(Playlist playlist) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _renamePlaylist(playlist);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Upload cover'),
              onTap: () {
                Navigator.pop(context);
                _uploadCover(playlist);
              },
            ),
            if (playlist.coverPath.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.image_not_supported),
                title: const Text('Clear cover'),
                onTap: () {
                  Navigator.pop(context);
                  _clearCover(playlist);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deletePlaylist(playlist);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int playlistCount) {
    final titleWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Playlists',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          '$playlistCount playlists',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
              ),
        ),
      ],
    );

    final addButton = IconButton(
      icon: const Icon(Icons.add, color: AppTheme.textPrimary),
      onPressed: _createPlaylist,
      tooltip: 'Create playlist',
    );

    if (isMobile(context)) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: titleWidget),
          addButton,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        titleWidget,
        addButton,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isMobile(context)
          ? AppBar(
              title: const Text('Playlists'),
              backgroundColor: AppTheme.mikuDark,
            )
          : null,
      body: Stack(
        children: [
          ListenableBuilder(
            listenable: PlaylistRepository.instance,
            builder: (context, _) {
              if (_loading && PlaylistRepository.instance.playlists.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final playlists = PlaylistRepository.instance.playlists;

              return RefreshIndicator(
                onRefresh: _loadPlaylists,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(isMobile(context) ? 12.0 : 32.0),
                        child: _buildHeader(context, playlists.length),
                      ),
                    ),
                    if (playlists.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'No playlists yet. Tap + to create one.',
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            mainAxisSpacing: _gridSpacing,
                            crossAxisSpacing: _gridSpacing,
                            childAspectRatio: 0.85,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final playlist = playlists[index];
                              return GestureDetector(
                                onLongPress: () => _showPlaylistMenu(playlist),
                                child: Stack(
                                  children: [
                                    PlaylistGridCard(
                                      playlist: playlist,
                                      client: _client,
                                      onTap: () {
                                        widget.onPlaylistTap?.call(playlist.id);
                                      },
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Material(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(16),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.more_vert,
                                            color: Colors.white,
                                            size: _menuIconSize,
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(
                                            minWidth: _menuButtonSize,
                                            minHeight: _menuButtonSize,
                                          ),
                                          onPressed: () => _showPlaylistMenu(playlist),
                                          tooltip: 'Playlist options',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            childCount: playlists.length,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          if (_operationInProgress)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
