import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

import 'web_audio_player_contract.dart';

WebAudioPlayer? _sharedPlayer;

WebAudioPlayer createWebAudioPlayer() =>
    _sharedPlayer ??= AdapterBackedWebAudioPlayer(
      adapter: BrowserWebAudioElementAdapter(),
    );

WebAudioPlayer createWebAudioPlayerForTest({
  required WebAudioElementAdapter? adapter,
}) =>
    adapter == null
        ? throw ArgumentError.notNull('adapter')
        : AdapterBackedWebAudioPlayer(adapter: adapter);

final class BrowserWebAudioElementAdapter implements WebAudioElementAdapter {
  BrowserWebAudioElementAdapter() : _audio = web.HTMLAudioElement() {
    _audio.preload = 'auto';
  }

  final web.HTMLAudioElement _audio;

  @override
  String get src => _audio.src;

  @override
  set src(String value) {
    _audio.src = value;
  }

  @override
  Duration get currentPosition =>
      Duration(milliseconds: (_audio.currentTime * 1000).round());

  @override
  set currentPosition(Duration value) {
    _audio.currentTime = value.inMilliseconds / 1000;
  }

  @override
  Duration get duration {
    final seconds = _audio.duration;
    if (!seconds.isFinite || seconds.isNaN || seconds < 0) {
      return Duration.zero;
    }
    return Duration(milliseconds: (seconds * 1000).round());
  }

  @override
  Future<void> play() => _audio.play().toDart;

  @override
  void pause() {
    _audio.pause();
  }

  @override
  void load() {
    _audio.load();
  }

  @override
  void dispose() {
    _audio.pause();
    _audio.src = '';
    _audio.load();
    _audio.remove();
  }

  @override
  Stream<void> get onEnded => _audio.onEnded.map((_) {});

  @override
  Stream<String?> get onError => _audio.onError.map((_) {
        final error = _audio.error;
        if (error == null) {
          return 'Failed to play audio.';
        }
        return error.message.isEmpty ? 'Failed to play audio.' : error.message;
      });

  @override
  Stream<void> get onLoadedMetadata => _audio.onLoadedMetadata.map((_) {});

  @override
  Stream<void> get onPause => _audio.onPause.map((_) {});

  @override
  Stream<void> get onPlay => _audio.onPlay.map((_) {});

  @override
  Stream<void> get onTimeUpdate => _audio.onTimeUpdate.map((_) {});
}
