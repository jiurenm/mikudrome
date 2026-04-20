import 'web_audio_player_contract.dart';

final WebAudioPlayer _sharedPlayer = _NoopWebAudioPlayer();

WebAudioPlayer createWebAudioPlayer() => _sharedPlayer;

WebAudioPlayer createWebAudioPlayerForTest({
  required WebAudioElementAdapter? adapter,
}) =>
    adapter == null
        ? _NoopWebAudioPlayer()
        : AdapterBackedWebAudioPlayer(adapter: adapter);

final class _NoopWebAudioPlayer implements WebAudioPlayer {
  @override
  bool get isAvailable => false;

  @override
  WebAudioPlayerValue get value => const WebAudioPlayerValue();

  @override
  void addListener(listener) {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> load({
    required String url,
    required Duration initialPosition,
    required bool autoplay,
  }) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  void removeListener(listener) {}

  @override
  Future<void> seekTo(Duration position) async {}
}
