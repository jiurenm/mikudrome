/// Vocalist model — aggregated from tracks.vocal field.
class Vocalist {
  final String name;
  final int trackCount;
  final int albumCount;

  const Vocalist({
    required this.name,
    this.trackCount = 0,
    this.albumCount = 0,
  });

  factory Vocalist.fromJson(Map<String, dynamic> json) {
    return Vocalist(
      name: json['name'] as String? ?? '',
      trackCount: json['track_count'] as int? ?? 0,
      albumCount: json['album_count'] as int? ?? 0,
    );
  }
}
