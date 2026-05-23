import 'track.dart';

class DailyRecommendations {
  const DailyRecommendations({required this.date, required this.tracks});

  final String date;
  final List<Track> tracks;

  factory DailyRecommendations.fromJson(Map<String, dynamic> json) {
    final list = json['tracks'] as List<dynamic>? ?? const [];
    return DailyRecommendations(
      date: json['date'] as String? ?? '',
      tracks: list
          .map((item) => Track.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
