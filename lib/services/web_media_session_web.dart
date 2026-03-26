import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'web_media_session_contract.dart';

WebMediaSessionService createWebMediaSessionService() =>
    _WebMediaSessionService(adapter: BrowserWebMediaSessionAdapter.tryCreate());

@visibleForTesting
WebMediaSessionService createWebMediaSessionServiceForTest({
  required WebMediaSessionAdapter? adapter,
}) =>
    _WebMediaSessionService(adapter: adapter);

@visibleForTesting
BrowserWebMediaSessionAdapter createBrowserWebMediaSessionAdapterForTest({
  required JSObject mediaSession,
}) =>
    BrowserWebMediaSessionAdapter._(mediaSession);

abstract interface class WebMediaSessionAdapter {
  void setMetadata({
    required String title,
    required String artist,
    String? album,
    String? artworkUrl,
  });

  void clearMetadata();

  void setPlaybackState({required bool isPlaying});

  void clearPlaybackState();

  void setPositionState({
    required int positionMs,
    required int durationMs,
    required double playbackRate,
  });

  void setActionHandler(String action, Object? handler);
}

final class _WebMediaSessionService implements WebMediaSessionService {
  _WebMediaSessionService({required WebMediaSessionAdapter? adapter})
      : _adapter = adapter;

  final WebMediaSessionAdapter? _adapter;

  @override
  void setMetadata({
    required String title,
    required String artist,
    String? album,
    String? artworkUrl,
  }) {
    _adapter?.setMetadata(
      title: title,
      artist: artist,
      album: album,
      artworkUrl: artworkUrl,
    );
  }

  @override
  void setPlaybackState({required bool isPlaying}) {
    _adapter?.setPlaybackState(isPlaying: isPlaying);
  }

  @override
  void setPositionState({
    required int positionMs,
    required int durationMs,
    required double playbackRate,
  }) {
    _adapter?.setPositionState(
      positionMs: positionMs,
      durationMs: durationMs,
      playbackRate: playbackRate,
    );
  }

  @override
  void setActionHandlers({
    required WebMediaSessionVoidHandler onPlay,
    required WebMediaSessionVoidHandler onPause,
    WebMediaSessionVoidHandler? onPrevious,
    WebMediaSessionVoidHandler? onNext,
    WebMediaSessionSeekHandler? onSeekTo,
  }) {
    final adapter = _adapter;
    if (adapter == null) {
      return;
    }

    adapter.setActionHandler('play', _wrapVoidHandler(onPlay));
    adapter.setActionHandler('pause', _wrapVoidHandler(onPause));

    if (onPrevious == null) {
      adapter.setActionHandler('previoustrack', null);
    } else {
      adapter.setActionHandler('previoustrack', _wrapVoidHandler(onPrevious));
    }

    if (onNext == null) {
      adapter.setActionHandler('nexttrack', null);
    } else {
      adapter.setActionHandler('nexttrack', _wrapVoidHandler(onNext));
    }

    if (onSeekTo == null) {
      adapter.setActionHandler('seekto', null);
    } else {
      adapter.setActionHandler('seekto', _wrapSeekHandler(onSeekTo));
    }
  }

  @override
  void clear() {
    final adapter = _adapter;
    if (adapter == null) {
      return;
    }

    adapter.setActionHandler('play', null);
    adapter.setActionHandler('pause', null);
    adapter.setActionHandler('previoustrack', null);
    adapter.setActionHandler('nexttrack', null);
    adapter.setActionHandler('seekto', null);
    adapter.clearMetadata();
    adapter.clearPlaybackState();
  }
}

final class BrowserWebMediaSessionAdapter implements WebMediaSessionAdapter {
  BrowserWebMediaSessionAdapter._(this._mediaSession);

  final JSObject _mediaSession;

  static BrowserWebMediaSessionAdapter? tryCreate() {
    try {
      final mediaSession = (web.window.navigator as JSObject)['mediaSession'];
      if (mediaSession == null) {
        return null;
      }
      return BrowserWebMediaSessionAdapter._(mediaSession as JSObject);
    } catch (_) {
      return null;
    }
  }

  @override
  void clearMetadata() {
    _safe(() {
      _mediaSession['metadata'] = null;
    });
  }

  @override
  void clearPlaybackState() {
    _safe(() {
      _mediaSession['playbackState'] = 'none'.toJS;
    });
  }

  @override
  void setActionHandler(String action, Object? handler) {
    _safe(() {
      _mediaSession.callMethodVarArgs(
        'setActionHandler'.toJS,
        <JSAny?>[action.toJS, handler as JSFunction?],
      );
    });
  }

  @override
  void setMetadata({
    required String title,
    required String artist,
    String? album,
    String? artworkUrl,
  }) {
    _safe(() {
      final metadataInit = web.MediaMetadataInit(title: title, artist: artist);
      if (album != null && album.isNotEmpty) {
        metadataInit.album = album;
      }
      if (artworkUrl != null && artworkUrl.isNotEmpty) {
        metadataInit.artwork =
            <web.MediaImage>[web.MediaImage(src: artworkUrl)].toJS;
      }

      _mediaSession['metadata'] = web.MediaMetadata(metadataInit);
    });
  }

  @override
  void setPlaybackState({required bool isPlaying}) {
    _safe(() {
      _mediaSession['playbackState'] = (isPlaying ? 'playing' : 'paused').toJS;
    });
  }

  @override
  void setPositionState({
    required int positionMs,
    required int durationMs,
    required double playbackRate,
  }) {
    _safe(() {
      final normalized = web.MediaPositionState(
        duration: durationMs <= 0 ? 0 : durationMs / 1000,
        playbackRate: playbackRate,
        position: positionMs < 0 ? 0 : positionMs / 1000,
      );
      _mediaSession.callMethodVarArgs('setPositionState'.toJS, <JSAny?>[
        normalized,
      ]);
    });
  }

  void _safe(void Function() operation) {
    try {
      operation();
    } catch (_) {
      return;
    }
  }
}

JSFunction _wrapVoidHandler(WebMediaSessionVoidHandler handler) {
  return () {
    handler();
  }.toJS;
}

JSFunction _wrapSeekHandler(WebMediaSessionSeekHandler handler) {
  return ((JSAny? details) {
    if (details == null) {
      return;
    }

    final seekTimeAny = (details as JSObject)['seekTime'];
    if (seekTimeAny case JSNumber seekTime) {
      final seekTimeSeconds = seekTime.toDartDouble;
      handler(seekTimeSeconds * 1000);
    }
  }).toJS;
}
