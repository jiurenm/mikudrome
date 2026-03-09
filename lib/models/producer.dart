/// Producer (P主) from backend API or placeholder.
class Producer {
  const Producer({
    required this.id,
    required this.name,
    this.trackCount = 0,
    this.albumCount = 0,
    this.avatarSeed,
  });

  final int id;
  final String name;
  final int trackCount;
  final int albumCount;
  final String? avatarSeed;

  String get avatarUrl =>
      'https://api.dicebear.com/7.x/identicon/svg?seed=${avatarSeed ?? id}';

  factory Producer.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int? ?? 0;
    final name = json['name'] as String? ?? '';
    return Producer(
      id: id,
      name: name,
      trackCount: json['track_count'] as int? ?? 0,
      albumCount: json['album_count'] as int? ?? 0,
      avatarSeed: name.isEmpty ? null : name,
    );
  }
}
