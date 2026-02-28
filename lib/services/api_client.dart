import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/album.dart';
import '../models/track.dart';

/// API client for Mikudrome backend.
class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;

  String get _tracksUrl => '$baseUrl/api/tracks';
  String get _albumsUrl => '$baseUrl/api/albums';

  Future<List<Album>> getAlbums() async {
    final res = await http.get(Uri.parse(_albumsUrl));
    if (res.statusCode != 200) {
      throw Exception('Failed to load albums: ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = data['albums'] as List<dynamic>? ?? [];
    return list
        .map((e) => Album.fromJson(e as Map<String, dynamic>, baseUrl))
        .toList();
  }

  Future<({Album album, List<Track> tracks})?> getAlbum(String id) async {
    final res = await http.get(Uri.parse('$_albumsUrl/$id'));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception('Failed to load album: ${res.statusCode}');
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

  Future<List<Track>> getTracks() async {
    final res = await http.get(Uri.parse(_tracksUrl));
    if (res.statusCode != 200) {
      throw Exception('Failed to load tracks: ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = data['tracks'] as List<dynamic>? ?? [];
    return list.map((e) => Track.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Track?> getTrack(int id) async {
    final res = await http.get(Uri.parse('$_tracksUrl/$id'));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception('Failed to load track: ${res.statusCode}');
    }
    return Track.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// URL to stream audio for a track.
  String streamAudioUrl(int trackId) => '$baseUrl/api/stream/$trackId/audio';

  /// URL to stream video (MV) for a track.
  String streamVideoUrl(int trackId) => '$baseUrl/api/stream/$trackId/video';
}
