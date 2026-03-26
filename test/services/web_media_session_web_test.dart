@TestOn('browser')

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/services/web_media_session_web.dart';
import 'package:web/web.dart' as web;

class _FakeMediaSessionAdapter implements WebMediaSessionAdapter {
  final Map<String, Object?> handlers = <String, Object?>{};

  String? metadataTitle;
  String? metadataArtist;
  String? metadataAlbum;
  String? metadataArtworkUrl;
  bool metadataCleared = false;

  bool? isPlaying;
  bool playbackCleared = false;

  int? positionMs;
  int? durationMs;
  double? playbackRate;

  @override
  void clearMetadata() {
    metadataCleared = true;
  }

  @override
  void clearPlaybackState() {
    playbackCleared = true;
  }

  @override
  void setActionHandler(String action, Object? handler) {
    handlers[action] = handler;
  }

  @override
  void setMetadata({
    required String title,
    required String artist,
    String? album,
    String? artworkUrl,
  }) {
    metadataTitle = title;
    metadataArtist = artist;
    metadataAlbum = album;
    metadataArtworkUrl = artworkUrl;
  }

  @override
  void setPlaybackState({required bool isPlaying}) {
    this.isPlaying = isPlaying;
  }

  @override
  void setPositionState({
    required int positionMs,
    required int durationMs,
    required double playbackRate,
  }) {
    this.positionMs = positionMs;
    this.durationMs = durationMs;
    this.playbackRate = playbackRate;
  }
}

JSObject _createFakeMediaSession({
  required void Function(String action, JSFunction? handler) onSetActionHandler,
  required void Function(web.MediaPositionState state) onSetPositionState,
}) {
  final session = JSObject();
  session['setActionHandler'] = ((JSString action, JSFunction? handler) {
    onSetActionHandler(action.toDart, handler);
  }).toJS;
  session['setPositionState'] = ((web.MediaPositionState state) {
    onSetPositionState(state);
  }).toJS;
  return session;
}

void main() {
  Future<void> noop() async {}

  group('Web media session capability registration', () {
    test('removes previous/next/seek handlers when capability is unavailable',
        () {
      final adapter = _FakeMediaSessionAdapter();
      final service = createWebMediaSessionServiceForTest(adapter: adapter);

      service.setActionHandlers(
        onPlay: noop,
        onPause: noop,
        onPrevious: null,
        onNext: null,
        onSeekTo: null,
      );

      expect(adapter.handlers['play'], isNotNull);
      expect(adapter.handlers['pause'], isNotNull);
      expect(adapter.handlers['previoustrack'], isNull);
      expect(adapter.handlers['nexttrack'], isNull);
      expect(adapter.handlers['seekto'], isNull);
    });

    test('clear removes all action handlers', () {
      final adapter = _FakeMediaSessionAdapter();
      final service = createWebMediaSessionServiceForTest(adapter: adapter);

      service.setActionHandlers(
        onPlay: noop,
        onPause: noop,
        onPrevious: noop,
        onNext: noop,
        onSeekTo: (_) async {},
      );

      service.clear();

      expect(adapter.handlers['play'], isNull);
      expect(adapter.handlers['pause'], isNull);
      expect(adapter.handlers['previoustrack'], isNull);
      expect(adapter.handlers['nexttrack'], isNull);
      expect(adapter.handlers['seekto'], isNull);
    });

    test('service is safe when adapter is unavailable', () {
      final service = createWebMediaSessionServiceForTest(adapter: null);

      expect(
        () => service.setActionHandlers(
          onPlay: noop,
          onPause: noop,
          onPrevious: null,
          onNext: null,
          onSeekTo: null,
        ),
        returnsNormally,
      );
      expect(
        () => service.setPlaybackState(isPlaying: true),
        returnsNormally,
      );
      expect(
        () => service.setPositionState(
          positionMs: 0,
          durationMs: 1000,
          playbackRate: 1,
        ),
        returnsNormally,
      );
      expect(() => service.clear(), returnsNormally);
    });
  });

  group('Web media session mapping to adapter', () {
    test('service forwards metadata payload to adapter', () {
      final adapter = _FakeMediaSessionAdapter();
      final service = createWebMediaSessionServiceForTest(adapter: adapter);

      service.setMetadata(
        title: 'World is Mine',
        artist: 'ryo',
        album: 'supercell',
        artworkUrl: 'https://example.com/cover.jpg',
      );

      expect(adapter.metadataTitle, 'World is Mine');
      expect(adapter.metadataArtist, 'ryo');
      expect(adapter.metadataAlbum, 'supercell');
      expect(adapter.metadataArtworkUrl, 'https://example.com/cover.jpg');
    });

    test('service forwards playback state mapping to adapter', () {
      final adapter = _FakeMediaSessionAdapter();
      final service = createWebMediaSessionServiceForTest(adapter: adapter);

      service.setPlaybackState(isPlaying: true);
      expect(adapter.isPlaying, isTrue);

      service.setPlaybackState(isPlaying: false);
      expect(adapter.isPlaying, isFalse);
    });
  });

  group('Browser adapter mapping behavior', () {
    test('browser adapter maps metadata payload to MediaMetadata', () {
      late JSObject mediaSession;
      mediaSession = _createFakeMediaSession(
        onSetActionHandler: (_, __) {},
        onSetPositionState: (_) {},
      );
      final adapter = createBrowserWebMediaSessionAdapterForTest(
        mediaSession: mediaSession,
      );

      adapter.setMetadata(
        title: 'Tell Your World',
        artist: 'livetune',
        album: 'Tell Your World EP',
        artworkUrl: 'https://example.com/artwork.png',
      );

      final metadataAny = mediaSession['metadata'];
      expect(metadataAny, isNotNull);

      final metadata = metadataAny as web.MediaMetadata;
      expect(metadata.title, 'Tell Your World');
      expect(metadata.artist, 'livetune');
      expect(metadata.album, 'Tell Your World EP');
      expect(metadata.artwork.toDart, hasLength(1));
      expect(
          metadata.artwork.toDart.first.src, 'https://example.com/artwork.png');
    });

    test('browser adapter maps playback state to media session values', () {
      late JSObject mediaSession;
      mediaSession = _createFakeMediaSession(
        onSetActionHandler: (_, __) {},
        onSetPositionState: (_) {},
      );
      final adapter = createBrowserWebMediaSessionAdapterForTest(
        mediaSession: mediaSession,
      );

      adapter.setPlaybackState(isPlaying: true);
      expect((mediaSession['playbackState'] as JSString?)?.toDart, 'playing');

      adapter.setPlaybackState(isPlaying: false);
      expect((mediaSession['playbackState'] as JSString?)?.toDart, 'paused');
    });

    test('browser adapter normalizes position state payload', () {
      web.MediaPositionState? capturedState;
      final mediaSession = _createFakeMediaSession(
        onSetActionHandler: (_, __) {},
        onSetPositionState: (state) => capturedState = state,
      );
      final adapter = createBrowserWebMediaSessionAdapterForTest(
        mediaSession: mediaSession,
      );

      adapter.setPositionState(
        positionMs: -500,
        durationMs: 3200,
        playbackRate: 1.25,
      );

      expect(capturedState, isNotNull);
      expect(capturedState!.duration, 3.2);
      expect(capturedState!.position, 0);
      expect(capturedState!.playbackRate, 1.25);
    });
  });
}
