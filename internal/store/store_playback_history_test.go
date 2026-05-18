package store

import (
	"fmt"
	"path/filepath"
	"testing"
)

func TestPlaybackHistoryUpsertUpdatesExistingTrack(t *testing.T) {
	s := newPlaybackHistoryTestStore(t)
	trackID := seedPlaybackHistoryTrack(t, s, "Track", "/music/track.flac")

	first := PlaybackHistoryUpdate{
		TrackID:      trackID,
		PositionMS:   1000,
		DurationMS:   10000,
		PlaybackMode: "audio",
		ContextLabel: "Album / First",
		PlayedAt:     100,
	}
	if err := s.UpsertPlaybackHistory(first); err != nil {
		t.Fatalf("first upsert: %v", err)
	}
	second := PlaybackHistoryUpdate{
		TrackID:      trackID,
		PositionMS:   2500,
		DurationMS:   10000,
		PlaybackMode: "video",
		ContextLabel: "Album / Second",
		PlayedAt:     200,
	}
	if err := s.UpsertPlaybackHistory(second); err != nil {
		t.Fatalf("second upsert: %v", err)
	}

	items, err := s.ListPlaybackHistory(10)
	if err != nil {
		t.Fatalf("list history: %v", err)
	}
	if len(items) != 1 {
		t.Fatalf("history length = %d, want 1", len(items))
	}
	got := items[0]
	if got.Track.ID != trackID || got.PositionMS != 2500 || got.PlaybackMode != "video" || got.ContextLabel != "Album / Second" || got.PlayedAt != 200 {
		t.Fatalf("unexpected history row: %+v", got)
	}
}

func TestPlaybackHistoryPrunesOldRows(t *testing.T) {
	s := newPlaybackHistoryTestStore(t)

	for i := 0; i < 205; i++ {
		trackID := seedPlaybackHistoryTrack(t, s, fmt.Sprintf("Track %03d", i), fmt.Sprintf("/music/track-%03d.flac", i))
		if err := s.UpsertPlaybackHistory(PlaybackHistoryUpdate{
			TrackID:      trackID,
			PositionMS:   int64(i),
			DurationMS:   10000,
			PlaybackMode: "audio",
			ContextLabel: "Queue",
			PlayedAt:     int64(i + 1),
		}); err != nil {
			t.Fatalf("upsert %d: %v", i, err)
		}
	}

	items, err := s.ListPlaybackHistory(250)
	if err != nil {
		t.Fatalf("list history: %v", err)
	}
	if len(items) != 200 {
		t.Fatalf("history length = %d, want 200", len(items))
	}
	if items[0].PlayedAt != 205 {
		t.Fatalf("newest played_at = %d, want 205", items[0].PlayedAt)
	}
	if items[len(items)-1].PlayedAt != 6 {
		t.Fatalf("oldest kept played_at = %d, want 6", items[len(items)-1].PlayedAt)
	}
}

func newPlaybackHistoryTestStore(t *testing.T) *Store {
	t.Helper()
	s, err := New(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatalf("new store: %v", err)
	}
	t.Cleanup(func() { s.Close() })
	return s
}

func seedPlaybackHistoryTrack(t *testing.T, s *Store, title, audioPath string) int64 {
	t.Helper()
	albumID, err := s.UpsertAlbum(title+" Album", "", 0, "")
	if err != nil {
		t.Fatalf("upsert album: %v", err)
	}
	if err := s.UpsertTrack(title, audioPath, "", "", albumID, 1, 1, "", 2024, 180, "FLAC"); err != nil {
		t.Fatalf("upsert track: %v", err)
	}
	tracks, err := s.ListTracks()
	if err != nil {
		t.Fatalf("list tracks: %v", err)
	}
	for _, track := range tracks {
		if track.AudioPath == audioPath {
			return track.ID
		}
	}
	t.Fatalf("seeded track not found: %s", audioPath)
	return 0
}
