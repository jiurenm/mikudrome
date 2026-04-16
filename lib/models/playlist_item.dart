import 'track.dart';

/// Playlist-local item data for a track entry inside a playlist group.
class PlaylistItem {
  final int id;
  final int playlistId;
  final int trackId;
  final int groupId;
  final int position;
  final String note;
  final String coverMode;
  final String libraryCoverId;
  final String cachedCoverUrl;
  final String customCoverPath;
  final int createdAt;
  final int updatedAt;
  final Track track;

  const PlaylistItem({
    required this.id,
    required this.playlistId,
    required this.trackId,
    required this.groupId,
    this.position = 0,
    this.note = '',
    this.coverMode = 'default',
    this.libraryCoverId = '',
    this.cachedCoverUrl = '',
    this.customCoverPath = '',
    this.createdAt = 0,
    this.updatedAt = 0,
    required this.track,
  });

  factory PlaylistItem.fromJson(Map<String, dynamic> json) {
    return PlaylistItem(
      id: json['id'] as int,
      playlistId: json['playlist_id'] as int? ?? 0,
      trackId: json['track_id'] as int? ?? 0,
      groupId: json['group_id'] as int? ?? 0,
      position: json['position'] as int? ?? 0,
      note: json['note'] as String? ?? '',
      coverMode: json['cover_mode'] as String? ?? 'default',
      libraryCoverId: json['library_cover_id'] as String? ?? '',
      cachedCoverUrl: json['cached_cover_url'] as String? ?? '',
      customCoverPath: json['custom_cover_path'] as String? ?? '',
      createdAt: json['created_at'] as int? ?? 0,
      updatedAt: json['updated_at'] as int? ?? 0,
      track: Track.fromJson(json['track'] as Map<String, dynamic>),
    );
  }
}
