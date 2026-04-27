import '../models/track.dart';

Duration effectiveTimelineDuration({
  required Track track,
  required Duration mediaDuration,
  required bool usesWebAudioPlayer,
}) {
  if (usesWebAudioPlayer &&
      track.durationSeconds > 0 &&
      _usesBrowserTranscodedAudio(track)) {
    return Duration(seconds: track.durationSeconds);
  }
  return mediaDuration;
}

bool _usesBrowserTranscodedAudio(Track track) {
  final path = track.audioPath.toLowerCase();
  return path.endsWith('.m4a') && track.format.toUpperCase().contains('ALAC');
}
