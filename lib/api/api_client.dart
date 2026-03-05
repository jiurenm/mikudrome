import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/album.dart';
import '../models/producer.dart';
import '../models/track.dart';
import 'config.dart';
import 'endpoints.dart';

/// Single entry point for all backend API communication.
/// Use [ApiConfig.defaultBaseUrl] or pass a custom [baseUrl].
class ApiClient {
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.defaultBaseUrl;

  final String baseUrl;

  String _url(String path) => '$baseUrl$path';

  // --- Tracks ---

  Future<List<Track>> getTracks() async {
    final res = await http.get(Uri.parse(_url(ApiEndpoints.tracks)));
    if (res.statusCode != 200) {
      throw ApiException('Failed to load tracks', res.statusCode);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = data['tracks'] as List<dynamic>? ?? [];
    return list.map((e) => Track.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Track?> getTrack(int id) async {
    final res = await http.get(Uri.parse(_url(ApiEndpoints.track(id))));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw ApiException('Failed to load track', res.statusCode);
    }
    return Track.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Download MV for a track from [url] (e.g. YouTube) via backend yt-dlp, then associate with track.
  /// Returns the updated track's video_path and video_thumb_path on success.
  Future<({String videoPath, String videoThumbPath})> downloadTrackMv(int trackId, String url) async {
    final res = await http.post(
      Uri.parse(_url(ApiEndpoints.trackDownloadMv(trackId))),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': url}),
    );
    if (res.statusCode != 200) {
      final msg = res.body.isNotEmpty ? res.body : 'Download failed';
      throw ApiException(msg, res.statusCode);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      videoPath: data['video_path'] as String? ?? '',
      videoThumbPath: data['video_thumb_path'] as String? ?? '',
    );
  }

  // --- Albums ---

  Future<List<Album>> getAlbums() async {
    final res = await http.get(Uri.parse(_url(ApiEndpoints.albums)));
    if (res.statusCode != 200) {
      throw ApiException('Failed to load albums', res.statusCode);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = data['albums'] as List<dynamic>? ?? [];
    return list
        .map((e) => Album.fromJson(e as Map<String, dynamic>, baseUrl))
        .toList();
  }

  // --- Producers ---

  Future<List<Producer>> getProducers() async {
    final res = await http.get(Uri.parse(_url(ApiEndpoints.producers)));
    if (res.statusCode != 200) {
      throw ApiException('Failed to load producers', res.statusCode);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = data['producers'] as List<dynamic>? ?? [];
    return list
        .map((e) => Producer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<({Producer producer, List<Track> tracks, List<Album> albums})?> getProducer(
    String name,
  ) async {
    final res = await http.get(Uri.parse(_url(ApiEndpoints.producer(name))));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw ApiException('Failed to load producer', res.statusCode);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final producerJson = data['producer'] as Map<String, dynamic>;
    final tracksList = data['tracks'] as List<dynamic>? ?? [];
    final albumsList = data['albums'] as List<dynamic>? ?? [];
    final producer = Producer.fromJson(producerJson);
    final tracks = tracksList
        .map((e) => Track.fromJson(e as Map<String, dynamic>))
        .toList();
    final albums = albumsList
        .map((e) => Album.fromJson(e as Map<String, dynamic>, baseUrl))
        .toList();
    return (producer: producer, tracks: tracks, albums: albums);
  }

  Future<({Album album, List<Track> tracks})?> getAlbum(String id) async {
    final res = await http.get(Uri.parse(_url(ApiEndpoints.album(id))));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw ApiException('Failed to load album', res.statusCode);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final albumJson = data['album'] as Map<String, dynamic>;
    final tracksList = data['tracks'] as List<dynamic>? ?? [];
    final album = Album.fromJson(albumJson, baseUrl);
    final tracks = tracksList
        .map((e) => Track.fromJson(e as Map<String, dynamic>))
        .toList();
    return (album: album, tracks: tracks);
  }

  // --- Stream URLs (no HTTP call, just URL builder) ---

  String streamAudioUrl(int trackId) =>
      _url(ApiEndpoints.streamAudio(trackId));

  String streamVideoUrl(int trackId) =>
      _url(ApiEndpoints.streamVideo(trackId));

  /// Full URL for MV thumbnail. 404 if not set.
  String streamThumbUrl(int trackId) =>
      _url(ApiEndpoints.streamThumb(trackId));

  /// Full URL for album cover image.
  String albumCoverUrl(String albumId) =>
      _url(ApiEndpoints.albumCover(albumId));

  /// Full URL for producer avatar (artist.jpg in P主 folder). 404 if not set.
  String producerAvatarUrl(String producerName) =>
      _url(ApiEndpoints.producerAvatar(producerName));

  // --- DB (optional, for future use) ---

  /// URL to download DB backup. Backend: GET /api/db/backup
  String get dbBackupUrl => _url(ApiEndpoints.dbBackup);
}

/// Thrown when an API request fails (non-2xx status).
class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}
