import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/playback_modes.dart';
import '../models/track.dart';

/// Non-web playback storage implementation backed by shared preferences.
class PlaybackStorage {
  static const _keyQueue = 'mikudrome_queue';
  static const _keyIndex = 'mikudrome_index';
  static const _keyProgress = 'mikudrome_progress';
  static const _keyMode = 'mikudrome_mode';
  static const _keyOrderMode = 'mikudrome_order_mode';
  static const _keyContext = 'mikudrome_context';

  static SharedPreferences? _prefs;

  static Future<void> ensureInitialized() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static void save({
    required List<Track> queue,
    required int index,
    required double progress,
    required PlaybackMode mode,
    required PlaybackOrderMode orderMode,
    required String contextLabel,
  }) {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      prefs.setString(_keyQueue, jsonEncode(queue.map(_trackToJson).toList()));
      prefs.setString(_keyIndex, index.toString());
      prefs.setString(_keyProgress, progress.toString());
      prefs.setString(_keyMode, mode.name);
      prefs.setString(_keyOrderMode, orderMode.name);
      prefs.setString(_keyContext, contextLabel);
    } catch (_) {}
  }

  static PlaybackState? load() {
    final prefs = _prefs;
    if (prefs == null) return null;
    try {
      final queueRaw = prefs.getString(_keyQueue);
      if (queueRaw == null || queueRaw.isEmpty) return null;
      final list = jsonDecode(queueRaw) as List<dynamic>;
      final queue = list
          .map((e) => Track.fromJson(e as Map<String, dynamic>))
          .toList();
      if (queue.isEmpty) return null;
      final index = int.tryParse(prefs.getString(_keyIndex) ?? '') ?? 0;
      final progress =
          double.tryParse(prefs.getString(_keyProgress) ?? '') ?? 0;
      final modeName = prefs.getString(_keyMode) ?? '';
      final orderName = prefs.getString(_keyOrderMode) ?? '';
      final contextLabel = prefs.getString(_keyContext) ?? 'Now Playing';
      return PlaybackState(
        queue: queue,
        index: index.clamp(0, queue.length - 1),
        progress: progress.clamp(0.0, 1.0),
        mode:
            PlaybackMode.values.where((m) => m.name == modeName).firstOrNull ??
            PlaybackMode.audio,
        orderMode:
            PlaybackOrderMode.values
                .where((m) => m.name == orderName)
                .firstOrNull ??
            PlaybackOrderMode.sequential,
        contextLabel: contextLabel,
      );
    } catch (_) {
      return null;
    }
  }

  static void clear() {
    final prefs = _prefs;
    if (prefs == null) return;
    for (final key in [
      _keyQueue,
      _keyIndex,
      _keyProgress,
      _keyMode,
      _keyOrderMode,
      _keyContext,
    ]) {
      prefs.remove(key);
    }
  }

  static Map<String, dynamic> _trackToJson(Track t) => {
    'id': t.id,
    'title': t.title,
    'audio_path': t.audioPath,
    'video_path': t.videoPath,
    'video_thumb_path': t.videoThumbPath,
    'album_id': t.albumId,
    'disc_number': t.discNumber,
    'track_number': t.trackNumber,
    'artists': t.artists,
    'year': t.year,
    'duration_seconds': t.durationSeconds,
    'format': t.format,
    'composer': t.composer,
    'lyricist': t.lyricist,
    'arranger': t.arranger,
    'remix': t.remix,
    'vocal': t.vocal,
    'voice_manipulator': t.voiceManipulator,
    'illustrator': t.illustrator,
    'movie': t.movie,
    'source': t.source,
    'lyrics': t.lyrics,
    'comment': t.comment,
  };
}

class PlaybackState {
  const PlaybackState({
    required this.queue,
    required this.index,
    required this.progress,
    required this.mode,
    required this.orderMode,
    required this.contextLabel,
  });

  final List<Track> queue;
  final int index;
  final double progress;
  final PlaybackMode mode;
  final PlaybackOrderMode orderMode;
  final String contextLabel;
}
