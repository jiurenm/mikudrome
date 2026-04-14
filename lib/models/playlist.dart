/// Playlist model matching backend API.
class Playlist {
  final int id;
  final String name;

  /// Ready-to-use URL path when non-empty, e.g. "/api/playlists/17/cover".
  final String coverPath;
  final int trackCount;
  final List<int> coverTrackIds;
  final List<int> coverAlbumIds;
  final int createdAt;
  final int updatedAt;

  const Playlist({
    required this.id,
    required this.name,
    this.coverPath = '',
    this.trackCount = 0,
    this.coverTrackIds = const [],
    this.coverAlbumIds = const [],
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      coverPath: json['cover_path'] as String? ?? '',
      trackCount: json['track_count'] as int? ?? 0,
      coverTrackIds: (json['cover_track_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      coverAlbumIds: (json['cover_album_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      createdAt: json['created_at'] as int? ?? 0,
      updatedAt: json['updated_at'] as int? ?? 0,
    );
  }
}
