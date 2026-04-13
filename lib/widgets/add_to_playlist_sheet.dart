import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/playlist.dart';
import '../services/playlist_repository.dart';
import 'playlists/new_playlist_dialog.dart';
import 'playlists/playlist_cover.dart';

class AddToPlaylistSheet extends StatefulWidget {
  const AddToPlaylistSheet({
    super.key,
    required this.trackIds,
    required this.client,
  });

  final List<int> trackIds;
  final ApiClient client;

  static Future<void> show({
    required BuildContext context,
    required List<int> trackIds,
    required ApiClient client,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) => AddToPlaylistSheet(
        trackIds: trackIds,
        client: client,
      ),
    );
  }

  @override
  State<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<AddToPlaylistSheet> {
  static const double _coverSize = 48.0;
  static const double _maxListHeight = 400.0;

  bool _isLoading = false;

  String _formatSuccessMessage(int added, int skipped) {
    if (skipped > 0) {
      return 'Added $added tracks ($skipped already in playlist)';
    } else {
      return 'Added $added tracks';
    }
  }

  Future<void> _createNewPlaylistAndAdd(BuildContext context) async {
    if (widget.trackIds.isEmpty || _isLoading) return;

    setState(() => _isLoading = true);

    final name = await showDialog<String>(
      context: context,
      builder: (context) => const NewPlaylistDialog(),
    );

    if (name == null || !context.mounted) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Create the playlist
      final playlist = await widget.client.createPlaylist(name);
      PlaylistRepository.instance.upsertPlaylist(playlist);

      // Add tracks to it
      final added = await widget.client.addTracksToPlaylist(playlist.id, widget.trackIds);
      final skipped = widget.trackIds.length - added;

      if (!context.mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatSuccessMessage(added, skipped))),
      );
    } catch (e) {
      debugPrint('Error creating playlist and adding tracks: $e');
      if (!context.mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add tracks. Please try again.')),
      );
      // Don't close sheet on error
    }
  }

  Future<void> _addToPlaylist(BuildContext context, Playlist playlist) async {
    if (widget.trackIds.isEmpty || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      final added = await widget.client.addTracksToPlaylist(playlist.id, widget.trackIds);
      final skipped = widget.trackIds.length - added;

      if (!context.mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatSuccessMessage(added, skipped))),
      );
    } catch (e) {
      debugPrint('Error adding tracks to playlist: $e');
      if (!context.mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add tracks. Please try again.')),
      );
      // Don't close sheet on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Add to Playlist',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              // New playlist item
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('New playlist'),
                onTap: _isLoading ? null : () => _createNewPlaylistAndAdd(context),
                enabled: !_isLoading,
              ),
              const Divider(),
              // Playlist list
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: _maxListHeight),
                  child: ListenableBuilder(
                    listenable: PlaylistRepository.instance,
                    builder: (context, _) {
                      final playlists = PlaylistRepository.instance.playlists;
                      if (playlists.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: playlists.length,
                        itemBuilder: (context, index) {
                          final playlist = playlists[index];
                          return ListTile(
                            leading: SizedBox(
                              width: _coverSize,
                              height: _coverSize,
                              child: PlaylistCover(
                                playlist: playlist,
                                client: widget.client,
                                size: _coverSize,
                              ),
                            ),
                            title: Text(playlist.name),
                            subtitle: Text('${playlist.trackCount} tracks'),
                            onTap: _isLoading ? null : () => _addToPlaylist(context, playlist),
                            enabled: !_isLoading,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
