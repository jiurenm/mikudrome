import '../models/track.dart';
import '../screens/library_home_screen.dart';

/// Non-web playback storage implementation. Safe no-op on VM/mobile tests.
class PlaybackStorage {
  static void save({
    required List<Track> queue,
    required int index,
    required double progress,
    required PlaybackMode mode,
    required PlaybackOrderMode orderMode,
    required String contextLabel,
  }) {}

  static PlaybackState? load() => null;

  static void clear() {}
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
