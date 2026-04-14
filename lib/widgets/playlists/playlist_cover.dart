import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../models/playlist.dart';
import '../../theme/app_theme.dart';

class PlaylistCover extends StatelessWidget {
  const PlaylistCover({
    super.key,
    required this.playlist,
    required this.client,
    this.size = 200,
  });

  final Playlist playlist;
  final ApiClient client;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Custom cover
    if (playlist.coverPath.isNotEmpty) {
      return Image.network(
        client.baseUrl + playlist.coverPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackIcon(),
      );
    }

    // Mosaic or fallback
    final trackIds = playlist.coverTrackIds;
    final albumIds = playlist.coverAlbumIds;
    if (trackIds.isEmpty) return _fallbackIcon();
    if (trackIds.length == 1) return _singleCover(trackIds[0], albumIds.isNotEmpty ? albumIds[0] : 0);
    if (trackIds.length == 2) return _twoCover(trackIds, albumIds);
    if (trackIds.length == 3) return _threeCover(trackIds, albumIds);
    return _fourCover(trackIds, albumIds);
  }

  Widget _fallbackIcon() {
    return Container(
      width: size,
      height: size,
      color: AppTheme.mikuGreen.withValues(alpha: 0.1),
      child: Icon(Icons.queue_music, size: size * 0.4, color: AppTheme.mikuGreen),
    );
  }

  Widget _singleCover(int trackId, int albumId) {
    return Image.network(
      client.streamThumbUrl(trackId),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        // Fallback to album cover if MV thumb not available
        if (albumId > 0) {
          return Image.network(
            client.albumCoverUrl(albumId.toString()),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackIcon(),
          );
        }
        return _fallbackIcon();
      },
    );
  }

  Widget _twoCover(List<int> ids, List<int> albumIds) {
    return SizedBox(
      width: size,
      height: size,
      child: Row(
        children: [
          Expanded(child: _coverTile(ids[0], albumIds.isNotEmpty ? albumIds[0] : 0)),
          Expanded(child: _coverTile(ids[1], albumIds.length > 1 ? albumIds[1] : 0)),
        ],
      ),
    );
  }

  Widget _threeCover(List<int> ids, List<int> albumIds) {
    return SizedBox(
      width: size,
      height: size,
      child: Row(
        children: [
          Expanded(child: _coverTile(ids[0], albumIds.isNotEmpty ? albumIds[0] : 0)),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _coverTile(ids[1], albumIds.length > 1 ? albumIds[1] : 0)),
                Expanded(child: _coverTile(ids[2], albumIds.length > 2 ? albumIds[2] : 0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fourCover(List<int> ids, List<int> albumIds) {
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _coverTile(ids[0], albumIds.isNotEmpty ? albumIds[0] : 0)),
                Expanded(child: _coverTile(ids[1], albumIds.length > 1 ? albumIds[1] : 0)),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _coverTile(ids[2], albumIds.length > 2 ? albumIds[2] : 0)),
                Expanded(child: _coverTile(ids[3], albumIds.length > 3 ? albumIds[3] : 0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverTile(int trackId, int albumId) {
    return Image.network(
      client.streamThumbUrl(trackId),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        // Fallback to album cover if MV thumb not available
        if (albumId > 0) {
          return Image.network(
            client.albumCoverUrl(albumId.toString()),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: AppTheme.cardBg),
          );
        }
        return Container(color: AppTheme.cardBg);
      },
    );
  }
}
