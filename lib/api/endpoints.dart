/// Centralized API path constants. Must match backend routes in internal/api/api.go.
abstract final class ApiEndpoints {
  ApiEndpoints._();

  static const String _prefix = '/api';

  // Tracks
  static const String tracks = '$_prefix/tracks';
  static String track(int id) => '$_prefix/tracks/$id';
  static String trackDownloadMv(int id) => '$_prefix/tracks/$id/download-mv';

  // Albums
  static const String albums = '$_prefix/albums';
  static String album(String id) => '$_prefix/albums/$id';
  static String albumCover(String id) => '$_prefix/albums/$id/cover';

  // Producers
  static const String producers = '$_prefix/producers';
  static String producer(int id) => '$_prefix/producers/$id';
  static String producerAvatar(int id) => '$_prefix/producers/$id/avatar';

  // Vocalists
  static const String vocalists = '$_prefix/vocalists';
  static String vocalistTracks(String name) =>
      '$_prefix/vocalists/${Uri.encodeComponent(name)}/tracks';

  // Stream (audio / video / thumb)
  static String streamAudio(int trackId) => '$_prefix/stream/$trackId/audio';
  static String streamVideo(int trackId) => '$_prefix/stream/$trackId/video';
  static String streamThumb(int trackId) => '$_prefix/stream/$trackId/thumb';

  // Videos
  static const String videos = '$_prefix/videos';
  static String video(int id) => '$_prefix/videos/$id';
  static String videoStream(int id) => '$_prefix/videos/$id/stream';
  static String videoThumb(int id) => '$_prefix/videos/$id/thumb';

  // DB
  static const String dbBackup = '$_prefix/db/backup';
}
