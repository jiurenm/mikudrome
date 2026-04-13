import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/playlist.dart';
import '../services/playlist_repository.dart';
import 'playlists/new_playlist_dialog.dart';
import 'playlists/playlist_cover.dart';

class AddToPlaylistSheet extends StatelessWidget {
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

  Future<void> _createNewPlaylistAndAdd(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const NewPlaylistDialog(),
    );
    if (name == null || !context.mounted) return;

    try {
      // Create the playlist
      final playlist = await client.createPlaylist(name);
      PlaylistRepository.instance.upsertPlaylist(playlist);

      // Add tracks to it
      final added = await client.addTracksToPlaylist(playlist.id, trackIds);
      final skipped = trackIds.length - added;

      if (!context.mounted) return;
      Navigator.of(context).pop();

      String message;
      if (skipped > 0) {
        message = 'Added $added tracks ($skipped already in playlist)';
      } else {
        message = 'Added $added tracks';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add tracks: $e')),
      );
      // Don't close sheet on error
    }
  }

  Future<void> _addToPlaylist(BuildContext context, Playlist playlist) async {
    try {
      final added = await client.addTracksToPlaylist(playlist.id, trackIds);
      final skipped = trackIds.length - added;

      if (!context.mounted) return;
      Navigator.of(context).pop();

      String message;
      if (skipped > 0) {
        message = 'Added $added tracks ($skipped already in playlist)';
      } else {
        message = 'Added $added tracks';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add tracks: $e')),
      );
      // Don't close sheet on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
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
            onTap: () => _createNewPlaylistAndAdd(context),
          ),
          const Divider(),
          // Playlist list
          ListenableBuilder(
            listenable: PlaylistRepository.instance,
            builder: (context, _) {
              final playlists = PlaylistRepository.instance.playlists;
              if (playlists.isEmpty) {
                return const SizedBox.shrink();
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return ListTile(
                    leading: SizedBox(
                      width: 48,
                      height: 48,
                      child: PlaylistCover(
                        playlist: playlist,
                        client: client,
                        size: 48,
                      ),
                    ),
                    title: Text(playlist.name),
                    subtitle: Text('${playlist.trackCount} tracks'),
                    onTap: () => _addToPlaylist(context, playlist),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
