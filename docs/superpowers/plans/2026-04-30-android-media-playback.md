# Android Media Playback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework mobile audio playback so Android background playback and Android media controls are driven by `audio_service`.

**Architecture:** Keep `MobileAudioPlaybackService` as the app-facing boundary. Introduce a Mikudrome `AudioHandler` that owns `just_audio`, publishes queue/media/playback state to Android, and exposes a stream consumed by the existing Flutter UI.

**Tech Stack:** Flutter/Dart, `audio_service`, `just_audio`, existing Android manifest service/receiver, Flutter widget/service tests.

---

## File Structure

- Modify: `lib/services/mobile_audio_playback_audio_service.dart` - split direct `just_audio` control into a handler plus thin service adapter.
- Modify: `test/services/mobile_audio_playback_test.dart` - add handler-oriented tests while keeping existing service behavior tests.
- Modify: `android/app/src/main/AndroidManifest.xml` only if the installed `audio_service` version requires additional documented metadata.
- Do not change `LibraryHomeScreen`, player widgets, backend endpoints, or web playback unless a test proves the existing boundary is insufficient.

---

### Task 1: Add Handler Metadata and Queue Surface

**Files:**
- Modify: `lib/services/mobile_audio_playback_audio_service.dart`
- Test: `test/services/mobile_audio_playback_test.dart`

- [ ] **Step 1: Write the failing test**

Add this test near the existing just_audio service tests in `test/services/mobile_audio_playback_test.dart`:

```dart
test('audio handler publishes media queue and current media item', () async {
  final player = FakeJustAudioPlayer();
  final handler = audio_service.MikudromeAudioHandler(player: player);

  await handler.setMikudromeQueue(
    tracks: [_track(1), _track(2)],
    audioUrls: const ['http://server/audio/1', 'http://server/audio/2'],
    initialIndex: 1,
  );

  expect(handler.queue.value.map((item) => item.id), [
    'http://server/audio/1',
    'http://server/audio/2',
  ]);
  expect(handler.queue.value.map((item) => item.title), ['Track 1', 'Track 2']);
  expect(handler.mediaItem.value?.id, 'http://server/audio/2');
  expect(handler.mediaItem.value?.title, 'Track 2');
  expect(handler.mediaItem.value?.duration, const Duration(seconds: 120));

  await handler.dispose();
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
/home/wj/workspace/flutter/bin/flutter test test/services/mobile_audio_playback_test.dart --plain-name "audio handler publishes media queue and current media item"
```

Expected: FAIL because `MikudromeAudioHandler` and `setMikudromeQueue` do not exist.

- [ ] **Step 3: Write minimal implementation**

In `lib/services/mobile_audio_playback_audio_service.dart`, add imports and a handler class:

```dart
import 'package:audio_service/audio_service.dart';
```

Add this class before `JustAudioMobileAudioPlaybackService`:

```dart
class MikudromeAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  MikudromeAudioHandler({MobileAudioPlayerAdapter? player})
    : _player = player ?? JustAudioPlayerAdapter() {
    _subscriptions.add(
      _player.currentIndexStream.listen(_handleCurrentIndexChanged),
    );
  }

  final MobileAudioPlayerAdapter _player;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  List<Track> _tracks = const [];
  List<String> _audioUrls = const [];
  bool _disposed = false;

  Future<void> setMikudromeQueue({
    required List<Track> tracks,
    required List<String> audioUrls,
    required int initialIndex,
  }) async {
    if (_disposed) return;
    if (tracks.isEmpty) {
      _tracks = const [];
      _audioUrls = const [];
      queue.add(const []);
      mediaItem.add(null);
      await _player.stop();
      return;
    }

    _tracks = List<Track>.unmodifiable(tracks);
    _audioUrls = List<String>.unmodifiable(audioUrls);
    final clampedIndex = initialIndex.clamp(0, _tracks.length - 1);
    final items = [
      for (var i = 0; i < _tracks.length; i++)
        MediaItem(
          id: _audioUrls[i],
          title: _tracks[i].title,
          artist: _tracks[i].vocalLine,
          duration: Duration(seconds: _tracks[i].durationSeconds),
        ),
    ];

    queue.add(items);
    mediaItem.add(items[clampedIndex]);
    await _player.setAudioSources(
      _audioUrls
          .map(
            (url) => AudioSource.uri(
              Uri.parse(url),
              headers: ApiConfig.defaultHeaders,
            ),
          )
          .toList(growable: false),
      initialIndex: clampedIndex,
      initialPosition: Duration.zero,
    );
  }

  void _handleCurrentIndexChanged(int? index) {
    if (index == null || queue.value.isEmpty) return;
    final clampedIndex = index.clamp(0, queue.value.length - 1);
    mediaItem.add(queue.value[clampedIndex]);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
/home/wj/workspace/flutter/bin/flutter test test/services/mobile_audio_playback_test.dart --plain-name "audio handler publishes media queue and current media item"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/mobile_audio_playback_audio_service.dart test/services/mobile_audio_playback_test.dart
git commit -m "feat: add mikudrome audio handler queue metadata"
```

---

### Task 2: Route Mobile Service Through the Handler

**Files:**
- Modify: `lib/services/mobile_audio_playback_audio_service.dart`
- Test: `test/services/mobile_audio_playback_test.dart`

- [ ] **Step 1: Write the failing test**

Add this test:

```dart
test('audio-service-backed service exposes handler queue state', () async {
  final player = FakeJustAudioPlayer();
  final handler = audio_service.MikudromeAudioHandler(player: player);
  final service = audio_service.JustAudioMobileAudioPlaybackService(
    handler: handler,
  );

  await service.playQueue(
    queue: [_track(1), _track(2)],
    index: 1,
    audioUrlForTrack: (track) => 'http://server/audio/${track.id}',
  );

  expect(handler.queue.value.length, 2);
  expect(handler.mediaItem.value?.title, 'Track 2');
  expect(player.playCalls, 1);
  expect(service.currentState.track?.id, 2);
  expect(service.currentState.isPlaying, isTrue);

  await service.dispose();
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
/home/wj/workspace/flutter/bin/flutter test test/services/mobile_audio_playback_test.dart --plain-name "audio-service-backed service exposes handler queue state"
```

Expected: FAIL because `JustAudioMobileAudioPlaybackService` does not accept a handler and still controls the player directly.

- [ ] **Step 3: Write minimal implementation**

Change `JustAudioMobileAudioPlaybackService` to depend on `MikudromeAudioHandler`:

```dart
class JustAudioMobileAudioPlaybackService
    implements MobileAudioPlaybackService {
  JustAudioMobileAudioPlaybackService({
    MikudromeAudioHandler? handler,
    MobileAudioPlayerAdapter? player,
  }) : _handler = handler ?? MikudromeAudioHandler(player: player),
       _states = StreamController<MobileAudioPlaybackState>.broadcast(
         sync: true,
       ) {
    _subscriptions.add(_handler.mikudromeState.listen(_emit));
  }

  final MikudromeAudioHandler _handler;
  final StreamController<MobileAudioPlaybackState> _states;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  MobileAudioPlaybackState _currentState = MobileAudioPlaybackState.empty();
  bool _disposed = false;
```

Keep `states` and `currentState` as the public service surface:

```dart
@override
Stream<MobileAudioPlaybackState> get states => _states.stream;

@override
MobileAudioPlaybackState get currentState => _currentState;
```

Add a handler state stream in `MikudromeAudioHandler`:

```dart
final StreamController<MobileAudioPlaybackState> _mikudromeStates =
    StreamController<MobileAudioPlaybackState>.broadcast(sync: true);

Stream<MobileAudioPlaybackState> get mikudromeState => _mikudromeStates.stream;
```

In `setMikudromeQueue`, after setting sources, emit the selected state and start playback:

```dart
_emitMikudromeState(index: clampedIndex, isPlaying: _player.playing);
await play();
```

Add handler command overrides:

```dart
@override
Future<void> play() => _player.play();

@override
Future<void> pause() => _player.pause();

@override
Future<void> seek(Duration position) => _player.seek(position);

@override
Future<void> skipToNext() => _player.seekToNext();

@override
Future<void> skipToPrevious() => _player.seekToPrevious();

@override
Future<void> stop() async {
  await _player.stop();
  _tracks = const [];
  _audioUrls = const [];
  queue.add(const []);
  mediaItem.add(null);
  _emitMikudromeState(empty: true);
}
```

Add `_emitMikudromeState` in the handler:

```dart
void _emitMikudromeState({
  int? index,
  bool? isPlaying,
  Duration position = Duration.zero,
  Duration? duration,
  bool isCompleted = false,
  bool empty = false,
}) {
  if (_disposed) return;
  if (empty || _tracks.isEmpty) {
    _mikudromeStates.add(MobileAudioPlaybackState.empty());
    return;
  }
  final effectiveIndex = (index ?? _player.currentIndex ?? 0).clamp(
    0,
    _tracks.length - 1,
  );
  _mikudromeStates.add(
    MobileAudioPlaybackState(
      queue: _tracks,
      index: effectiveIndex,
      isPlaying: isPlaying ?? _player.playing,
      position: position,
      duration:
          duration ?? Duration(seconds: _tracks[effectiveIndex].durationSeconds),
      isCompleted: isCompleted,
      audioUrl: _audioUrls[effectiveIndex],
    ),
  );
}
```

Then update service methods to delegate:

```dart
@override
Future<void> playQueue({
  required List<Track> queue,
  required int index,
  required AudioUrlForTrack audioUrlForTrack,
}) async {
  if (_disposed) return;
  final urls = List<String>.unmodifiable(queue.map(audioUrlForTrack));
  await _handler.setMikudromeQueue(
    tracks: List<Track>.unmodifiable(queue),
    audioUrls: urls,
    initialIndex: index,
  );
}

@override
Future<void> play() => _disposed ? Future.value() : _handler.play();

@override
Future<void> pause() => _disposed ? Future.value() : _handler.pause();

@override
Future<void> seek(Duration position) =>
    _disposed ? Future.value() : _handler.seek(position);

@override
Future<void> next() => _disposed ? Future.value() : _handler.skipToNext();

@override
Future<void> previous() =>
    _disposed ? Future.value() : _handler.skipToPrevious();

@override
Future<void> stop() => _disposed ? Future.value() : _handler.stop();
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
/home/wj/workspace/flutter/bin/flutter test test/services/mobile_audio_playback_test.dart --plain-name "audio-service-backed service exposes handler queue state"
```

Expected: PASS.

- [ ] **Step 5: Run existing mobile playback tests**

Run:

```bash
/home/wj/workspace/flutter/bin/flutter test test/services/mobile_audio_playback_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/services/mobile_audio_playback_audio_service.dart test/services/mobile_audio_playback_test.dart
git commit -m "feat: route mobile playback through audio service handler"
```

---

### Task 3: Sync Playback State, Completion, and Failure Behavior

**Files:**
- Modify: `lib/services/mobile_audio_playback_audio_service.dart`
- Test: `test/services/mobile_audio_playback_test.dart`

- [ ] **Step 1: Write failing state-sync test**

Add this test:

```dart
test('audio handler syncs player streams to playback state and app state', () async {
  final player = FakeJustAudioPlayer();
  final handler = audio_service.MikudromeAudioHandler(player: player);
  final states = <MobileAudioPlaybackState>[];
  final sub = handler.mikudromeState.listen(states.add);

  await handler.setMikudromeQueue(
    tracks: [_track(1), _track(2)],
    audioUrls: const ['http://server/audio/1', 'http://server/audio/2'],
    initialIndex: 0,
  );

  player.setCurrentIndex(1);
  player.setDuration(const Duration(seconds: 90));
  player.setPosition(const Duration(seconds: 12));
  player.setProcessingState(ProcessingState.completed);

  expect(handler.mediaItem.value?.title, 'Track 2');
  expect(states.last.track?.id, 2);
  expect(states.last.duration, const Duration(seconds: 90));
  expect(states.last.position, const Duration(seconds: 12));
  expect(states.last.isCompleted, isTrue);
  expect(handler.playbackState.value.processingState, AudioProcessingState.completed);

  await sub.cancel();
  await handler.dispose();
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
/home/wj/workspace/flutter/bin/flutter test test/services/mobile_audio_playback_test.dart --plain-name "audio handler syncs player streams to playback state and app state"
```

Expected: FAIL because the handler does not yet listen to all player streams or publish `audio_service.playbackState`.

- [ ] **Step 3: Implement stream synchronization**

In `MikudromeAudioHandler`, subscribe to all player streams in the constructor:

```dart
_subscriptions.add(_player.playingStream.listen(_handlePlayingChanged));
_subscriptions.add(_player.currentIndexStream.listen(_handleCurrentIndexChanged));
_subscriptions.add(
  _player.processingStateStream.listen(_handleProcessingStateChanged),
);
_subscriptions.add(_player.positionStream.listen(_handlePositionChanged));
_subscriptions.add(_player.durationStream.listen(_handleDurationChanged));
```

Add fields:

```dart
Duration _position = Duration.zero;
Duration _duration = Duration.zero;
bool _isCompleted = false;
```

Add handlers:

```dart
void _handlePlayingChanged(bool isPlaying) {
  _publishPlaybackState(isPlaying: isPlaying);
  _emitMikudromeState(isPlaying: isPlaying, isCompleted: false);
}

void _handleProcessingStateChanged(ProcessingState state) {
  if (state == ProcessingState.completed) {
    _isCompleted = true;
    _publishPlaybackState(
      isPlaying: false,
      processingState: AudioProcessingState.completed,
    );
    _emitMikudromeState(isPlaying: false, isCompleted: true);
    return;
  }
  _publishPlaybackState(
    processingState: state == ProcessingState.loading
        ? AudioProcessingState.loading
        : AudioProcessingState.ready,
  );
}

void _handlePositionChanged(Duration position) {
  _position = position;
  _publishPlaybackState();
  _emitMikudromeState(position: position);
}

void _handleDurationChanged(Duration? duration) {
  _duration = duration ?? Duration.zero;
  final current = mediaItem.value;
  if (current != null) {
    mediaItem.add(current.copyWith(duration: _duration));
  }
  _emitMikudromeState(duration: _duration);
}
```

Add playback-state publishing:

```dart
void _publishPlaybackState({
  bool? isPlaying,
  AudioProcessingState processingState = AudioProcessingState.ready,
}) {
  playbackState.add(
    PlaybackState(
      controls: const [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.pause,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: processingState,
      playing: isPlaying ?? _player.playing,
      updatePosition: _position,
    ),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
/home/wj/workspace/flutter/bin/flutter test test/services/mobile_audio_playback_test.dart --plain-name "audio handler syncs player streams to playback state and app state"
```

Expected: PASS.

- [ ] **Step 5: Preserve failure tests**

Run:

```bash
/home/wj/workspace/flutter/bin/flutter test test/services/mobile_audio_playback_test.dart --plain-name "setAudioSources failure leaves service stopped"
/home/wj/workspace/flutter/bin/flutter test test/services/mobile_audio_playback_test.dart --plain-name "play failure is handled and leaves selected track paused"
```

Expected: both PASS. If either fails, update `setMikudromeQueue` so source-load failures clear handler state before rethrowing, and update `play` failure handling so the selected queue remains published with `playing: false`.

- [ ] **Step 6: Commit**

```bash
git add lib/services/mobile_audio_playback_audio_service.dart test/services/mobile_audio_playback_test.dart
git commit -m "feat: sync android media playback state"
```

---

### Task 4: Initialize the Real Android Audio Service

**Files:**
- Modify: `lib/services/mobile_audio_playback_audio_service.dart`
- Test: `test/services/mobile_audio_playback_test.dart`

- [ ] **Step 1: Write failing factory test**

Replace the existing factory test expectation with:

```dart
test('audio service factory creates audio-service-backed service', () async {
  final service = audio_service.createMobileAudioPlaybackService();

  expect(service, isA<audio_service.JustAudioMobileAudioPlaybackService>());
  expect(
    (service as audio_service.JustAudioMobileAudioPlaybackService).usesAudioService,
    isTrue,
  );

  await service.dispose();
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
/home/wj/workspace/flutter/bin/flutter test test/services/mobile_audio_playback_test.dart --plain-name "audio service factory creates audio-service-backed service"
```

Expected: FAIL because the service has no `usesAudioService` indicator and factory does not call `AudioService.init`.

- [ ] **Step 3: Implement factory initialization**

Change the factory to initialize the handler through `audio_service`:

```dart
Future<AudioHandler>? _handlerInit;

MobileAudioPlaybackService createMobileAudioPlaybackService() {
  return JustAudioMobileAudioPlaybackService.fromAudioService();
}
```

Add a named constructor and visible test flag:

```dart
JustAudioMobileAudioPlaybackService.fromAudioService()
  : this(
      handlerFuture: _handlerInit ??= AudioService.init(
        builder: () => MikudromeAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.miku39.mikudrome.playback',
          androidNotificationChannelName: 'Mikudrome playback',
          androidNotificationOngoing: true,
        ),
      ),
      usesAudioService: true,
    );

JustAudioMobileAudioPlaybackService({
  MikudromeAudioHandler? handler,
  Future<AudioHandler>? handlerFuture,
  MobileAudioPlayerAdapter? player,
  this.usesAudioService = false,
}) : _handler = handler ?? MikudromeAudioHandler(player: player),
     _handlerFuture = handlerFuture,
     _states = StreamController<MobileAudioPlaybackState>.broadcast(sync: true) {
  _bindHandler(_handler);
}

final bool usesAudioService;
final Future<AudioHandler>? _handlerFuture;
```

If `handlerFuture` is provided, await it inside service methods before command delegation:

```dart
Future<MikudromeAudioHandler> _effectiveHandler() async {
  final future = _handlerFuture;
  if (future == null) return _handler;
  final handler = await future;
  return handler as MikudromeAudioHandler;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
/home/wj/workspace/flutter/bin/flutter test test/services/mobile_audio_playback_test.dart --plain-name "audio service factory creates audio-service-backed service"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/mobile_audio_playback_audio_service.dart test/services/mobile_audio_playback_test.dart
git commit -m "feat: initialize android audio service playback"
```

---

### Task 5: Final Verification

**Files:**
- Modify only files required by failing tests.
- Test: `test/services/mobile_audio_playback_test.dart`

- [ ] **Step 1: Run focused playback tests**

Run:

```bash
/home/wj/workspace/flutter/bin/flutter test test/services/mobile_audio_playback_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run related media-session tests**

Run:

```bash
/home/wj/workspace/flutter/bin/flutter test test/services/media_session_handler_binding_test.dart test/screens/player_screen_media_session_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run Flutter analysis**

Run:

```bash
/home/wj/workspace/flutter/bin/flutter analyze lib test
```

Expected: exits 0 with no new errors.

- [ ] **Step 4: Build Android debug APK**

Run:

```bash
/home/wj/workspace/flutter/bin/flutter build apk --debug
```

Expected: debug APK builds successfully and Android manifest merge succeeds.

- [ ] **Step 5: Commit final fixes**

If Step 1-4 required any corrections:

```bash
git add lib/services/mobile_audio_playback_audio_service.dart test/services/mobile_audio_playback_test.dart android/app/src/main/AndroidManifest.xml
git commit -m "fix: verify android media playback integration"
```

If there were no corrections, do not create an empty commit.
