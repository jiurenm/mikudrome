import 'playback_modes.dart';
import 'track.dart';

class PlaybackHistoryItem {
  const PlaybackHistoryItem({
    required this.track,
    required this.positionMs,
    required this.durationMs,
    required this.mode,
    required this.contextLabel,
    required this.playedAt,
  });

  factory PlaybackHistoryItem.fromJson(Map<String, dynamic> json) {
    final modeName = json['playback_mode'] as String? ?? '';
    return PlaybackHistoryItem(
      track: Track.fromJson(json['track'] as Map<String, dynamic>),
      positionMs: json['position_ms'] as int? ?? 0,
      durationMs: json['duration_ms'] as int? ?? 0,
      mode:
          PlaybackMode.values
              .where((mode) => mode.name == modeName)
              .firstOrNull ??
          PlaybackMode.audio,
      contextLabel: json['context_label'] as String? ?? '',
      playedAt: json['played_at'] as int? ?? 0,
    );
  }

  final Track track;
  final int positionMs;
  final int durationMs;
  final PlaybackMode mode;
  final String contextLabel;
  final int playedAt;
}
