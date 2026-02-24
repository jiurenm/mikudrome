/// Track model matching backend API.
class Track {
  final int id;
  final String title;
  final String audioPath;
  final String videoPath;

  const Track({
    required this.id,
    required this.title,
    required this.audioPath,
    required this.videoPath,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      audioPath: json['audio_path'] as String? ?? '',
      videoPath: json['video_path'] as String? ?? '',
    );
  }

  bool get hasVideo => videoPath.isNotEmpty;
}
