import '../api/endpoints.dart';

/// Album from backend API.
class Album {
  const Album({
    required this.id,
    required this.title,
    this.producerId = 0,
    this.producerName = '',
    this.year = 0,
    required this.trackCount,
    required this.coverUrl,
  });

  final String id;
  final String title;
  final int producerId;
  final String producerName;
  final int year;
  final int trackCount;
  final String coverUrl;

  factory Album.fromJson(Map<String, dynamic> json, String baseUrl) {
    final id = json['id'] as int;
    final idStr = id.toString();
    return Album(
      id: idStr,
      title: json['title'] as String? ?? '',
      producerId: json['producer_id'] as int? ?? 0,
      producerName: json['producer_name'] as String? ?? '',
      year: json['year'] as int? ?? 0,
      trackCount: json['track_count'] as int? ?? 0,
      coverUrl: '$baseUrl${ApiEndpoints.albumCover(idStr)}',
    );
  }
}
