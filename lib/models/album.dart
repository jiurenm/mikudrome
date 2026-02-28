/// Album from backend API (media/Artist/Album folder).
class Album {
  const Album({
    required this.id,
    required this.title,
    required this.producerName,
    this.year = 0,
    required this.trackCount,
    required this.coverUrl,
  });

  final String id;
  final String title;
  final String producerName;
  final int year;
  final int trackCount;
  final String coverUrl;

  factory Album.fromJson(Map<String, dynamic> json, String baseUrl) {
    final id = json['id'] as int;
    return Album(
      id: id.toString(),
      title: json['title'] as String? ?? '',
      producerName: json['artist'] as String? ?? '',
      year: json['year'] as int? ?? 0,
      trackCount: json['track_count'] as int? ?? 0,
      coverUrl: '$baseUrl/api/albums/$id/cover',
    );
  }
}
