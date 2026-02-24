import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/track.dart';

/// API client for Mikudrome backend.
class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;

  String get _tracksUrl => '$baseUrl/api/tracks';

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
