import 'dart:async';

import 'package:flutter/foundation.dart';

class WebAudioPlayerValue {
  const WebAudioPlayerValue({
    this.isInitialized = false,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isCompleted = false,
    this.errorDescription,
  });

  final bool isInitialized;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isCompleted;
  final String? errorDescription;

  WebAudioPlayerValue copyWith({
    bool? isInitialized,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isCompleted,
    String? errorDescription,
    bool clearErrorDescription = false,
  }) {
    return WebAudioPlayerValue(
      isInitialized: isInitialized ?? this.isInitialized,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isCompleted: isCompleted ?? this.isCompleted,
      errorDescription: clearErrorDescription
          ? null
          : errorDescription ?? this.errorDescription,
    );
  }
}

abstract interface class WebAudioElementAdapter {
  String get src;
  set src(String value);

  Duration get currentPosition;
  set currentPosition(Duration value);

  Duration get duration;

  Future<void> play();
  void pause();
  void load();
  void dispose();

  Stream<void> get onLoadedMetadata;
  Stream<void> get onTimeUpdate;
  Stream<void> get onPlay;
  Stream<void> get onPause;
  Stream<void> get onEnded;
  Stream<String?> get onError;
}

abstract interface class WebAudioPlayer {
  bool get isAvailable;
  WebAudioPlayerValue get value;

  Future<void> load({
    required String url,
    required Duration initialPosition,
    required bool autoplay,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
  Future<void> dispose();
}

final class AdapterBackedWebAudioPlayer implements WebAudioPlayer {
  AdapterBackedWebAudioPlayer({required WebAudioElementAdapter adapter})
      : _adapter = adapter {
    _subscriptions = [
      _adapter.onLoadedMetadata.listen((_) => _handleLoadedMetadata()),
      _adapter.onTimeUpdate.listen((_) => _syncFromAdapter(isCompleted: false)),
      _adapter.onPlay.listen((_) {
        _value = _value.copyWith(
          isInitialized: true,
          isPlaying: true,
          isCompleted: false,
          clearErrorDescription: true,
        );
        _syncFromAdapter(isCompleted: false);
      }),
      _adapter.onPause.listen((_) {
        _value = _value.copyWith(isPlaying: false);
        _syncFromAdapter(isCompleted: _value.isCompleted);
      }),
      _adapter.onEnded.listen((_) {
        _value = _value.copyWith(isPlaying: false);
        _syncFromAdapter(isCompleted: true);
      }),
      _adapter.onError.listen((message) {
        _value = _value.copyWith(
          isInitialized: false,
          isPlaying: false,
          errorDescription: message ?? 'Failed to play audio.',
        );
        _notifyListeners();
      }),
    ];
  }

  final WebAudioElementAdapter _adapter;
  final List<VoidCallback> _listeners = <VoidCallback>[];
  late final List<StreamSubscription<void>> _subscriptions;
  WebAudioPlayerValue _value = const WebAudioPlayerValue();
  String? _currentUrl;
  Duration? _pendingInitialPosition;
  bool _isDisposed = false;

  @override
  bool get isAvailable => true;

  @override
  WebAudioPlayerValue get value => _value;

  @override
  Future<void> load({
    required String url,
    required Duration initialPosition,
    required bool autoplay,
  }) async {
    if (_currentUrl == url && _value.isInitialized) {
      if (initialPosition > Duration.zero) {
        await seekTo(initialPosition);
      } else if (_value.isCompleted) {
        await seekTo(Duration.zero);
      }
      if (autoplay && !_value.isPlaying) {
        await play();
      }
      return;
    }
    _currentUrl = url;
    _pendingInitialPosition =
        initialPosition > Duration.zero ? initialPosition : null;
    _value = const WebAudioPlayerValue();
    _notifyListeners();

    _adapter.pause();
    _adapter.src = url;
    _adapter.load();

    if (autoplay) {
      await play();
    }
  }

  @override
  Future<void> play() async {
    try {
      await _adapter.play();
    } catch (error) {
      _value = _value.copyWith(
        isPlaying: false,
        errorDescription: error.toString(),
      );
      _notifyListeners();
    }
  }

  @override
  Future<void> pause() async {
    _adapter.pause();
    _value = _value.copyWith(isPlaying: false);
    _syncFromAdapter(isCompleted: false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    final clamped = _clampToDuration(position);
    _adapter.currentPosition = clamped;
    _value = _value.copyWith(
      position: clamped,
      isCompleted: false,
    );
    _notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _adapter.pause();
    _adapter.dispose();
    _listeners.clear();
  }

  void _handleLoadedMetadata() {
    final pending = _pendingInitialPosition;
    if (pending != null) {
      _adapter.currentPosition = _clampToDuration(pending);
      _pendingInitialPosition = null;
    }
    _value = _value.copyWith(
      isInitialized: true,
      duration: _adapter.duration,
      position: _adapter.currentPosition,
      isCompleted: false,
      clearErrorDescription: true,
    );
    _notifyListeners();
  }

  void _syncFromAdapter({required bool isCompleted}) {
    _value = _value.copyWith(
      isInitialized: true,
      position: _adapter.currentPosition,
      duration: _adapter.duration,
      isCompleted: isCompleted,
      clearErrorDescription: true,
    );
    _notifyListeners();
  }

  Duration _clampToDuration(Duration position) {
    final duration = _adapter.duration;
    if (duration <= Duration.zero) {
      return position < Duration.zero ? Duration.zero : position;
    }
    if (position < Duration.zero) {
      return Duration.zero;
    }
    if (position > duration) {
      return duration;
    }
    return position;
  }

  void _notifyListeners() {
    if (_isDisposed) {
      return;
    }
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }
}
