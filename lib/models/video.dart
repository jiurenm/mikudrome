/// Video model matching backend /api/videos response.
class Video {
  final int id;
  final String title;
  final String artist;
  final String thumbPath;
  final int durationSeconds;
  final int? trackId;
  final int? producerId;
  final String source;
  final String trackTitle;
  final String albumTitle;
  final String coverPath;

  const Video({
    required this.id,
    required this.title,
    this.artist = '',
    this.thumbPath = '',
    this.durationSeconds = 0,
    this.trackId,
    this.producerId,
    this.source = 'scan',
    this.trackTitle = '',
    this.albumTitle = '',
    this.coverPath = '',
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      thumbPath: json['thumb_path'] as String? ?? '',
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      trackId: json['track_id'] as int?,
      producerId: json['producer_id'] as int?,
      source: json['source'] as String? ?? 'scan',
      trackTitle: json['track_title'] as String? ?? '',
      albumTitle: json['album_title'] as String? ?? '',
      coverPath: json['cover_path'] as String? ?? '',
    );
  }

  bool get hasTrack => trackId != null;

  /// Duration formatted as "mm:ss" or "hh:mm:ss".
  String get durationFormatted {
    if (durationSeconds <= 0) return '--:--';
    final sec = durationSeconds % 60;
    final min = (durationSeconds ~/ 60) % 60;
    final hour = durationSeconds ~/ 3600;
    if (hour > 0) {
      return '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}
