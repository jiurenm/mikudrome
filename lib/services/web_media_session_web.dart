import 'dart:html' as html;

import 'package:flutter/foundation.dart';

import 'web_media_session_contract.dart';

WebMediaSessionService createWebMediaSessionService() =>
    _WebMediaSessionService(adapter: BrowserWebMediaSessionAdapter.tryCreate());

@visibleForTesting
WebMediaSessionService createWebMediaSessionServiceForTest({
  required WebMediaSessionAdapter? adapter,
}) =>
    _WebMediaSessionService(adapter: adapter);

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

  final dynamic _mediaSession;

  static BrowserWebMediaSessionAdapter? tryCreate() {
    try {
      final dynamic mediaSession =
          (html.window.navigator as dynamic).mediaSession;
      if (mediaSession == null) {
        return null;
      }
      return BrowserWebMediaSessionAdapter._(mediaSession);
    } catch (_) {
      return null;
    }
  }

  @override
  void clearMetadata() {
    _safe(() => _mediaSession.metadata = null);
  }

  @override
  void clearPlaybackState() {
    _safe(() => _mediaSession.playbackState = 'none');
  }

  @override
  void setActionHandler(String action, Object? handler) {
    _safe(() => _mediaSession.setActionHandler(action, handler));
  }

  @override
  void setMetadata({
    required String title,
    required String artist,
    String? album,
    String? artworkUrl,
  }) {
    _safe(() {
      final metadata = <String, Object?>{
        'title': title,
        'artist': artist,
        if (album != null && album.isNotEmpty) 'album': album,
        if (artworkUrl != null && artworkUrl.isNotEmpty)
          'artwork': <Map<String, String>>[
            <String, String>{'src': artworkUrl},
          ],
      };
      _mediaSession.metadata = metadata;
    });
  }

  @override
  void setPlaybackState({required bool isPlaying}) {
    _safe(() => _mediaSession.playbackState = isPlaying ? 'playing' : 'paused');
  }

  @override
  void setPositionState({
    required int positionMs,
    required int durationMs,
    required double playbackRate,
  }) {
    _safe(() {
      _mediaSession.setPositionState(<String, Object>{
        'duration': durationMs <= 0 ? 0 : durationMs / 1000,
        'playbackRate': playbackRate,
        'position': positionMs < 0 ? 0 : positionMs / 1000,
      });
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

Function _wrapVoidHandler(WebMediaSessionVoidHandler handler) {
  return () {
    handler();
  };
}

Function _wrapSeekHandler(WebMediaSessionSeekHandler handler) {
  return (dynamic details) {
    final dynamic seekTime = details?.seekTime;
    if (seekTime is num) {
      handler(seekTime.toDouble() * 1000);
    }
  };
}
