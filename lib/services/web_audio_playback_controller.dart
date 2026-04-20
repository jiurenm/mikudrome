import '../models/track.dart';
import 'web_audio_player.dart';
import 'web_audio_player_contract.dart';

class WebAudioPlaybackController {
  WebAudioPlaybackController() : _player = createWebAudioPlayer();

  final WebAudioPlayer _player;

  WebAudioPlayer get player => _player;
  bool get isAvailable => _player.isAvailable;

  int? _currentTrackId;
  String? _currentUrl;

  Future<void> activateTrack({
    required Track track,
    required String url,
    required Duration initialPosition,
    required bool autoplay,
  }) async {
    final isSameTrack = _currentTrackId == track.id && _currentUrl == url;
    if (isSameTrack && _player.value.isInitialized) {
      if (initialPosition > Duration.zero) {
        await _player.seekTo(initialPosition);
      }
      if (autoplay && !_player.value.isPlaying) {
        await _player.play();
      }
      return;
    }

    _currentTrackId = track.id;
    _currentUrl = url;
    await _player.load(
      url: url,
      initialPosition: initialPosition,
      autoplay: autoplay,
    );
  }
}
