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
    final ids = playlist.coverTrackIds;
    if (ids.isEmpty) return _fallbackIcon();
    if (ids.length == 1) return _singleCover(ids[0]);
    if (ids.length == 2) return _twoCover(ids);
    if (ids.length == 3) return _threeCover(ids);
    return _fourCover(ids);
  }

  Widget _fallbackIcon() {
    return Container(
      width: size,
      height: size,
      color: AppTheme.mikuGreen.withValues(alpha: 0.1),
      child: Icon(Icons.queue_music, size: size * 0.4, color: AppTheme.mikuGreen),
    );
  }

  Widget _singleCover(int trackId) {
    return Image.network(
      client.streamThumbUrl(trackId),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallbackIcon(),
    );
  }

  Widget _twoCover(List<int> ids) {
    return SizedBox(
      width: size,
      height: size,
      child: Row(
        children: [
          Expanded(child: _coverTile(ids[0])),
          Expanded(child: _coverTile(ids[1])),
        ],
      ),
    );
  }

  Widget _threeCover(List<int> ids) {
    return SizedBox(
      width: size,
      height: size,
      child: Row(
        children: [
          Expanded(child: _coverTile(ids[0])),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _coverTile(ids[1])),
                Expanded(child: _coverTile(ids[2])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fourCover(List<int> ids) {
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _coverTile(ids[0])),
                Expanded(child: _coverTile(ids[1])),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _coverTile(ids[2])),
                Expanded(child: _coverTile(ids[3])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverTile(int trackId) {
    return Image.network(
      client.streamThumbUrl(trackId),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: AppTheme.cardBg),
    );
  }
}
