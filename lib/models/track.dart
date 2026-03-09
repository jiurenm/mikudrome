/// Track model matching backend API.
class Track {
  final int id;
  final String title;
  final String audioPath;
  final String videoPath;
  final String videoThumbPath; // MV thumbnail (same name as video or ffmpeg-generated)
  final int discNumber; // 碟号，多碟专辑时从元数据读取，默认 1
  final int trackNumber;
  final String producer; // P主
  final String vocal;
  final int year;
  final int durationSeconds;
  final String format; // 码率/格式，如 "24bit FLAC"

  const Track({
    required this.id,
    required this.title,
    required this.audioPath,
    required this.videoPath,
    this.videoThumbPath = '',
    this.discNumber = 1,
    this.trackNumber = 0,
    this.producer = '',
    this.vocal = '',
    this.year = 0,
    this.durationSeconds = 0,
    this.format = '',
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      audioPath: json['audio_path'] as String? ?? '',
      videoPath: json['video_path'] as String? ?? '',
      videoThumbPath: json['video_thumb_path'] as String? ?? '',
      discNumber: json['disc_number'] as int? ?? 1,
      trackNumber: json['track_number'] as int? ?? 0,
      producer: json['producer'] as String? ?? '',
      vocal: json['vocal'] as String? ?? '',
      year: json['year'] as int? ?? 0,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      format: json['format'] as String? ?? '',
    );
  }

  /// 曲目序号显示，多碟时显示 "1-1"，单碟时显示 "01"
  String displayNumber(int fallbackIndex) {
    final n = trackNumber > 0 ? trackNumber : fallbackIndex;
    if (discNumber > 1) {
      return '$discNumber-${n.toString().padLeft(2, '0')}';
    }
    return n.toString().padLeft(2, '0');
  }

  bool get hasVideo => videoPath.isNotEmpty;

  /// 时长格式化，如 "3:45" 或 "1:02:30"。
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
