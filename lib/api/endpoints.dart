/// Centralized API path constants. Must match backend routes in internal/api/api.go.
abstract final class ApiEndpoints {
  ApiEndpoints._();

  static const String _prefix = '/api';

  // Tracks
  static const String tracks = '$_prefix/tracks';
  static String track(int id) => '$_prefix/tracks/$id';

  // Albums
  static const String albums = '$_prefix/albums';
  static String album(String id) => '$_prefix/albums/$id';
  static String albumCover(String id) => '$_prefix/albums/$id/cover';

  // Producers
  static const String producers = '$_prefix/producers';
  static String producer(String name) => '$_prefix/producers/${Uri.encodeComponent(name)}';
  static String producerAvatar(String name) => '$_prefix/producers/${Uri.encodeComponent(name)}/avatar';

  // Stream (audio / video / thumb)
  static String streamAudio(int trackId) => '$_prefix/stream/$trackId/audio';
  static String streamVideo(int trackId) => '$_prefix/stream/$trackId/video';
  static String streamThumb(int trackId) => '$_prefix/stream/$trackId/thumb';

  // DB
  static const String dbBackup = '$_prefix/db/backup';
}
