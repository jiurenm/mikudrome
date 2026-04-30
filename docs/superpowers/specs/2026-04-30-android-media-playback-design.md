# Android Media Playback Design

## Context

Mikudrome already has a mobile audio abstraction, Android foreground-service
permissions, an `AudioServiceActivity`, and an `AudioService` service/receiver
declared in the Android manifest. The current mobile implementation still
controls `just_audio.AudioPlayer` directly from
`JustAudioMobileAudioPlaybackService`, so Android system media controls are not
the owner of playback state, queue metadata, or transport commands.

## Goal

Rework app-side audio playback so Android background playback and Android media
controller integration use the same playback core. Lock-screen controls,
notification controls, headset buttons, and in-app controls must all drive the
same queue, current item, position, and playing state.

## Non-Goals

- No visual redesign of the mobile player.
- No changes to backend streaming endpoints.
- No changes to desktop or web playback behavior.
- No new playback modes beyond the existing audio/video and queue-order modes.

## Approach

Keep the public `MobileAudioPlaybackService` contract used by
`LibraryHomeScreen`, but replace the mobile implementation internals with an
`audio_service` handler.

Add a Mikudrome audio handler that extends `BaseAudioHandler` and mixes in
queue/seek support. The handler owns a `just_audio.AudioPlayer`, sets the audio
source queue, publishes `MediaItem` metadata, and handles play, pause, seek,
skip-to-next, skip-to-previous, and stop. `JustAudioMobileAudioPlaybackService`
becomes a thin adapter from the app-facing service API to the handler.

## Data Flow

1. The app calls `MobileAudioPlaybackService.playQueue` with tracks, selected
   index, and URL builder.
2. The mobile service converts tracks to audio URLs and sends the queue to the
   handler.
3. The handler publishes `audio_service.queue` and current `mediaItem`, then
   configures the `just_audio` player with matching `AudioSource.uri` entries
   and API headers.
4. In-app controls and Android media controls call the same handler methods.
5. Player streams update `audio_service.playbackState` and the app-facing
   `MobileAudioPlaybackState` stream.
6. `LibraryHomeScreen` keeps using existing state handling for progress labels,
   saved playback state, queue index, completion, shuffle, and repeat behavior.

## Metadata

Each track maps to a `MediaItem` with:

- `id`: audio stream URL.
- `title`: track title.
- `artist`: the track display artist, preferring the existing vocal/composer
  presentation used by the app model.
- `album`: available album context when present.
- `duration`: track duration when known.
- `artUri`: album cover URL when the app can provide one without extra backend
  work.

If artwork is unavailable, playback still works and the notification shows text
metadata.

## Android Integration

The existing Android manifest entries for foreground media playback, wake lock,
cleartext network playback, `AudioService`, `MediaButtonReceiver`, and
`AudioServiceActivity` remain. Implementation should verify that the
`audio_service` version in use does not require additional manifest metadata.
If it does, add only the required package-documented entries.

## Error Handling

- If loading a queue fails, the app-facing state remains stopped and no stale
  queue is published.
- If play fails after a queue is loaded, the selected track remains visible but
  paused.
- Commands after disposal are ignored.
- Empty queues stop playback and clear handler/app state.
- Completion is surfaced once through `MobileAudioPlaybackState.isCompleted`
  so existing repeat/next logic in `LibraryHomeScreen` remains authoritative.

## Testing

Use test-first changes around the existing mobile playback test file.

Coverage should include:

- factory creates the audio-service-backed mobile service;
- playing a queue publishes handler queue/media item and app-facing state;
- handler play, pause, seek, next, previous, and stop commands update the same
  app-facing state;
- player stream changes update current index, duration, position, completion,
  and playing state;
- loading and play failures preserve the expected stopped/paused states;
- Android manifest still includes media playback service, receiver,
  foreground-service permissions, wake lock, notification permission, cleartext
  playback config, and `AudioServiceActivity`.

## Acceptance Criteria

- Mobile audio playback continues to work from existing app controls.
- Android media notification and system media controller can play, pause, seek,
  and skip tracks.
- Background audio continues after the app leaves the foreground.
- Track metadata and duration appear in Android media controls when available.
- Existing Flutter tests for mobile playback and player routing pass.
