/// Track model matching backend API.
class Track {
  final int id;
  final String title;
  final String audioPath;
  final String videoPath;
  final String
  videoThumbPath; // MV thumbnail (same name as video or ffmpeg-generated)
  final int albumId;
  final int discNumber; // 碟号，多碟专辑时从元数据读取，默认 1
  final int trackNumber;
  final String artists; // 艺术家，可能包含多个（如 "初音ミク, 镜音リン"）
  final int year;
  final int durationSeconds;
  final String format; // 码率/格式，如 "24bit FLAC"
  // Extended metadata fields
  final String composer; // 作曲
  final String lyricist; // 作词
  final String arranger; // 编曲
  final String remix; // Remix
  final String vocal; // Vocal（如 "初音ミク"）
  final String voiceManipulator; // 调教
  final String illustrator; // 插画
  final String movie; // PV制作
  final String source; // 投稿平台/视频链接
  final String lyrics; // 歌词
  final String comment; // 备注
  final String albumArtist;

  /// Whether this track is in the user's favorites. Populated by the backend
  /// on track responses; not persisted in localStorage.
  final bool isFavorite;

  /// When set, the player uses this URL for video streaming instead of
  /// computing it from the track ID. Used for standalone MV playback.
  final String? videoStreamOverrideUrl;

  /// When set, the player uses this URL as cover art instead of the album cover.
  final String? coverOverrideUrl;

  const Track({
    required this.id,
    required this.title,
    required this.audioPath,
    required this.videoPath,
    this.videoThumbPath = '',
    this.albumId = 0,
    this.discNumber = 1,
    this.trackNumber = 0,
    this.artists = '',
    this.year = 0,
    this.durationSeconds = 0,
    this.format = '',
    this.composer = '',
    this.lyricist = '',
    this.arranger = '',
    this.remix = '',
    this.vocal = '',
    this.voiceManipulator = '',
    this.illustrator = '',
    this.movie = '',
    this.source = '',
    this.lyrics = '',
    this.comment = '',
    this.albumArtist = '',
    this.isFavorite = false,
    this.videoStreamOverrideUrl,
    this.coverOverrideUrl,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      audioPath: json['audio_path'] as String? ?? '',
      videoPath: json['video_path'] as String? ?? '',
      videoThumbPath: json['video_thumb_path'] as String? ?? '',
      albumId: json['album_id'] as int? ?? 0,
      discNumber: json['disc_number'] as int? ?? 1,
      trackNumber: json['track_number'] as int? ?? 0,
      artists: json['artists'] as String? ?? '',
      year: json['year'] as int? ?? 0,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      format: json['format'] as String? ?? '',
      composer: json['composer'] as String? ?? '',
      lyricist: json['lyricist'] as String? ?? '',
      arranger: json['arranger'] as String? ?? '',
      remix: json['remix'] as String? ?? '',
      vocal: json['vocal'] as String? ?? '',
      voiceManipulator: json['voice_manipulator'] as String? ?? '',
      illustrator: json['illustrator'] as String? ?? '',
      movie: json['movie'] as String? ?? '',
      source: json['source'] as String? ?? '',
      lyrics: json['lyrics'] as String? ?? '',
      comment: json['comment'] as String? ?? '',
      albumArtist: json['album_artist'] as String? ?? '',
      isFavorite: json['is_favorite'] as bool? ?? false,
    );
  }

  /// 曲目序号显示，显示 "01", "02" 等
  String displayNumber(int fallbackIndex) {
    final n = trackNumber > 0 ? trackNumber : fallbackIndex;
    return n.toString().padLeft(2, '0');
  }

  bool get hasVideo => videoPath.isNotEmpty;
  bool get hasAudio => audioPath.isNotEmpty;

  List<String> _splitCredits(String value) {
    return value
        .split(RegExp(r'\s*[;,，；/／]+\s*'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  List<String> _dedupeCredits(Iterable<String> credits) {
    final seen = <String>{};
    final result = <String>[];
    for (final credit in credits) {
      if (seen.add(credit)) {
        result.add(credit);
      }
    }
    return result;
  }

  List<String> get composers => _dedupeCredits(_splitCredits(composer));

  List<String> get lyricists => _dedupeCredits(_splitCredits(lyricist));

  List<String> get remixers => _dedupeCredits(_splitCredits(remix));

  List<String> get vocalists => _dedupeCredits(_splitCredits(vocal));

  String get composerDisplay {
    if (composers.isNotEmpty) return composers.join(' x ');
    if (artists.isNotEmpty) {
      final artistCredits = _dedupeCredits(_splitCredits(artists));
      if (artistCredits.isNotEmpty) return artistCredits.join(' x ');
      return artists;
    }
    return '-';
  }

  String get lyricistDisplay {
    if (lyricists.isNotEmpty) return lyricists.join(' x ');
    return '-';
  }

  String get vocalLine {
    var peopleCredits = remixers;
    if (peopleCredits.isEmpty) {
      peopleCredits = _dedupeCredits([
        ..._splitCredits(composer),
        ..._splitCredits(lyricist),
      ]);
    }
    if (peopleCredits.isEmpty && artists.isNotEmpty) {
      peopleCredits = _dedupeCredits(_splitCredits(artists));
    }
    final vocalCredits = _dedupeCredits(_splitCredits(vocal));

    final parts = <String>[];

    if (peopleCredits.isNotEmpty) {
      parts.add(peopleCredits.join(', '));
    }

    if (vocalCredits.isNotEmpty) {
      final vocalText = vocalCredits.join(', ');
      parts.add(parts.isNotEmpty ? 'feat. $vocalText' : vocalText);
    }

    return parts.join(' ');
  }

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
