import 'dart:convert';

import 'package:web/web.dart' as web;

import '../models/track.dart';
import '../screens/library_home_screen.dart';

/// Persists playback state to browser localStorage for session continuity.
class PlaybackStorage {
  static const _keyQueue = 'mikudrome_queue';
  static const _keyIndex = 'mikudrome_index';
  static const _keyProgress = 'mikudrome_progress';
  static const _keyMode = 'mikudrome_mode';
  static const _keyOrderMode = 'mikudrome_order_mode';
  static const _keyContext = 'mikudrome_context';

  static web.Storage? get _storage {
    try {
      return web.window.localStorage;
    } catch (_) {
      return null;
    }
  }

  static void save({
    required List<Track> queue,
    required int index,
    required double progress,
    required PlaybackMode mode,
    required PlaybackOrderMode orderMode,
    required String contextLabel,
  }) {
    final storage = _storage;
    if (storage == null) return;
    try {
      final queueJson = jsonEncode(queue.map(_trackToJson).toList());
      storage.setItem(_keyQueue, queueJson);
      storage.setItem(_keyIndex, index.toString());
      storage.setItem(_keyProgress, progress.toString());
      storage.setItem(_keyMode, mode.name);
      storage.setItem(_keyOrderMode, orderMode.name);
      storage.setItem(_keyContext, contextLabel);
    } catch (_) {}
  }

  static PlaybackState? load() {
    final storage = _storage;
    if (storage == null) return null;
    try {
      final queueRaw = storage.getItem(_keyQueue);
      if (queueRaw == null || queueRaw.isEmpty) return null;
      final list = jsonDecode(queueRaw) as List<dynamic>;
      final queue =
          list.map((e) => Track.fromJson(e as Map<String, dynamic>)).toList();
      if (queue.isEmpty) return null;
      final index = int.tryParse(storage.getItem(_keyIndex) ?? '') ?? 0;
      final progress =
          double.tryParse(storage.getItem(_keyProgress) ?? '') ?? 0;
      final modeName = storage.getItem(_keyMode) ?? '';
      final orderName = storage.getItem(_keyOrderMode) ?? '';
      final contextLabel = storage.getItem(_keyContext) ?? 'Now Playing';
      return PlaybackState(
        queue: queue,
        index: index.clamp(0, queue.length - 1),
        progress: progress.clamp(0.0, 1.0),
        mode:
            PlaybackMode.values.where((m) => m.name == modeName).firstOrNull ??
                PlaybackMode.audio,
        orderMode: PlaybackOrderMode.values
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
    final storage = _storage;
    if (storage == null) return;
    for (final key in [
      _keyQueue,
      _keyIndex,
      _keyProgress,
      _keyMode,
      _keyOrderMode,
      _keyContext,
    ]) {
      storage.removeItem(key);
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
