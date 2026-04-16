import 'playlist.dart';
import 'playlist_group.dart';

/// Grouped playlist detail payload returned by the playlist items API.
class PlaylistDetailData {
  final Playlist playlist;
  final List<PlaylistGroup> groups;

  const PlaylistDetailData({
    required this.playlist,
    this.groups = const [],
  });

  factory PlaylistDetailData.fromJson(Map<String, dynamic> json) {
    return PlaylistDetailData(
      playlist: Playlist.fromJson(json['playlist'] as Map<String, dynamic>),
      groups: (json['groups'] as List<dynamic>?)
              ?.map(
                (group) =>
                    PlaylistGroup.fromJson(group as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }
}
