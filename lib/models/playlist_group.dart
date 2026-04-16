import 'playlist_item.dart';

/// Playlist group with playlist-local items.
class PlaylistGroup {
  final int id;
  final int playlistId;
  final String title;
  final int position;
  final bool isSystem;
  final int createdAt;
  final int updatedAt;
  final List<PlaylistItem> items;

  const PlaylistGroup({
    required this.id,
    required this.playlistId,
    required this.title,
    this.position = 0,
    this.isSystem = false,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.items = const [],
  });

  factory PlaylistGroup.fromJson(Map<String, dynamic> json) {
    return PlaylistGroup(
      id: json['id'] as int,
      playlistId: json['playlist_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      position: json['position'] as int? ?? 0,
      isSystem: json['is_system'] as bool? ?? false,
      createdAt: json['created_at'] as int? ?? 0,
      updatedAt: json['updated_at'] as int? ?? 0,
      items: (json['items'] as List<dynamic>?)
              ?.map(
                (item) => PlaylistItem.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }
}
