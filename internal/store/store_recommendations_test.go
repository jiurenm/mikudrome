package store

import (
	"fmt"
	"reflect"
	"testing"
	"time"
)

func TestDailyRecommendationsReturnsStableLimitedPlayableTracks(t *testing.T) {
	s := newTestStore(t)
	seedRecommendationTracks(t, s, 25)

	date := time.Date(2026, 5, 22, 10, 30, 0, 0, time.Local)
	first, err := s.DailyRecommendations(date, 20)
	if err != nil {
		t.Fatalf("DailyRecommendations first: %v", err)
	}
	second, err := s.DailyRecommendations(date, 20)
	if err != nil {
		t.Fatalf("DailyRecommendations second: %v", err)
	}

	if len(first) != 20 {
		t.Fatalf("len(first) = %d, want 20", len(first))
	}
	if !reflect.DeepEqual(trackIDs(first), trackIDs(second)) {
		t.Fatalf("same date order changed: %v vs %v", trackIDs(first), trackIDs(second))
	}
	for _, track := range first {
		if track.AudioPath == "" {
			t.Fatalf("recommended non-playable track: %+v", track)
		}
	}
}

func TestDailyRecommendationsEmptyAndSmallLibrary(t *testing.T) {
	s := newTestStore(t)
	date := time.Date(2026, 5, 22, 10, 30, 0, 0, time.Local)

	empty, err := s.DailyRecommendations(date, 20)
	if err != nil {
		t.Fatalf("DailyRecommendations empty: %v", err)
	}
	if len(empty) != 0 {
		t.Fatalf("empty len = %d, want 0", len(empty))
	}

	seedRecommendationTracks(t, s, 3)
	small, err := s.DailyRecommendations(date, 20)
	if err != nil {
		t.Fatalf("DailyRecommendations small: %v", err)
	}
	if len(small) != 3 {
		t.Fatalf("small len = %d, want 3", len(small))
	}
}

func TestDailyRecommendationsDateChangesOrdering(t *testing.T) {
	s := newTestStore(t)
	seedRecommendationTracks(t, s, 30)

	dayOne, err := s.DailyRecommendations(time.Date(2026, 5, 22, 10, 0, 0, 0, time.Local), 20)
	if err != nil {
		t.Fatalf("day one: %v", err)
	}
	dayTwo, err := s.DailyRecommendations(time.Date(2026, 5, 23, 10, 0, 0, 0, time.Local), 20)
	if err != nil {
		t.Fatalf("day two: %v", err)
	}
	if reflect.DeepEqual(trackIDs(dayOne), trackIDs(dayTwo)) {
		t.Fatalf("different dates produced same order: %v", trackIDs(dayOne))
	}
}

func TestDailyRecommendationsFavoritesAndHistoryBoostTracks(t *testing.T) {
	s := newTestStore(t)
	ids := seedRecommendationTracks(t, s, 12)

	if err := s.AddFavorite(ids[0]); err != nil {
		t.Fatalf("AddFavorite: %v", err)
	}
	if err := s.UpsertPlaybackHistory(PlaybackHistoryUpdate{
		TrackID:      ids[1],
		PositionMS:   1000,
		DurationMS:   10000,
		PlaybackMode: "audio",
		ContextLabel: "Test",
		PlayedAt:     1779072000,
	}); err != nil {
		t.Fatalf("UpsertPlaybackHistory: %v", err)
	}

	got, err := s.DailyRecommendations(time.Date(2026, 5, 22, 10, 0, 0, 0, time.Local), 5)
	if err != nil {
		t.Fatalf("DailyRecommendations: %v", err)
	}
	gotIDs := trackIDs(got)
	if !containsTrackID(gotIDs, ids[0]) {
		t.Fatalf("favorite track %d missing from boosted recommendations: %v", ids[0], gotIDs)
	}
	if !containsTrackID(gotIDs, ids[1]) {
		t.Fatalf("history track %d missing from boosted recommendations: %v", ids[1], gotIDs)
	}
	if hasDuplicateTrackIDs(gotIDs) {
		t.Fatalf("duplicate recommendation IDs: %v", gotIDs)
	}
}

func seedRecommendationTracks(t *testing.T, s *Store, count int) []int64 {
	t.Helper()
	albumID, err := s.UpsertAlbum("Recommendation Album", "", 0, "")
	if err != nil {
		t.Fatalf("UpsertAlbum: %v", err)
	}
	for i := 0; i < count; i++ {
		title := fmt.Sprintf("Recommendation Track %02d", i)
		audioPath := fmt.Sprintf("/music/recommendation-track-%02d.flac", i)
		videoPath := ""
		if i%4 == 0 {
			videoPath = fmt.Sprintf("/music/recommendation-track-%02d.mp4", i)
		}
		if err := s.UpsertTrack(title, audioPath, videoPath, "", albumID, 1, i+1, "Artist", 2026, 180+i, "FLAC"); err != nil {
			t.Fatalf("UpsertTrack %d: %v", i, err)
		}
	}
	tracks, err := s.ListTracks()
	if err != nil {
		t.Fatalf("ListTracks: %v", err)
	}
	ids := make([]int64, 0, count)
	for _, track := range tracks {
		ids = append(ids, track.ID)
	}
	return ids
}

func trackIDs(tracks []Track) []int64 {
	ids := make([]int64, len(tracks))
	for i, track := range tracks {
		ids[i] = track.ID
	}
	return ids
}

func containsTrackID(ids []int64, want int64) bool {
	for _, id := range ids {
		if id == want {
			return true
		}
	}
	return false
}

func hasDuplicateTrackIDs(ids []int64) bool {
	seen := make(map[int64]bool, len(ids))
	for _, id := range ids {
		if seen[id] {
			return true
		}
		seen[id] = true
	}
	return false
}
