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
	seedNonPlayableRecommendationTracks(t, s)

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
		if track.Title == "Recommendation Empty Audio" || track.Title == "Recommendation Whitespace Audio" {
			t.Fatalf("recommended non-playable track: %+v", track)
		}
	}
}

func TestDailyRecommendationsUsesServerLocalDate(t *testing.T) {
	originalLocal := time.Local
	time.Local = time.FixedZone("RecommendationTestLocal", 8*60*60)
	t.Cleanup(func() { time.Local = originalLocal })

	s := newTestStore(t)
	seedRecommendationTracks(t, s, 30)

	utcNow := time.Date(2026, 5, 21, 16, 30, 0, 0, time.UTC)
	localNow := utcNow.Local()
	if utcNow.Format("2006-01-02") == localNow.Format("2006-01-02") {
		t.Fatalf("test setup expected UTC and local dates to differ: utc=%s local=%s", utcNow, localNow)
	}

	fromUTC, err := s.DailyRecommendations(utcNow, 20)
	if err != nil {
		t.Fatalf("DailyRecommendations UTC now: %v", err)
	}
	fromLocal, err := s.DailyRecommendations(localNow, 20)
	if err != nil {
		t.Fatalf("DailyRecommendations local now: %v", err)
	}
	if !reflect.DeepEqual(trackIDs(fromUTC), trackIDs(fromLocal)) {
		t.Fatalf("same instant produced different server-local recommendations: utc=%v local=%v", trackIDs(fromUTC), trackIDs(fromLocal))
	}
}

func TestDailyRecommendationsDefaultLimitForNonPositiveLimit(t *testing.T) {
	s := newTestStore(t)
	seedRecommendationTracks(t, s, 25)

	date := time.Date(2026, 5, 22, 10, 30, 0, 0, time.Local)
	zero, err := s.DailyRecommendations(date, 0)
	if err != nil {
		t.Fatalf("DailyRecommendations zero limit: %v", err)
	}
	negative, err := s.DailyRecommendations(date, -5)
	if err != nil {
		t.Fatalf("DailyRecommendations negative limit: %v", err)
	}

	if len(zero) != 20 {
		t.Fatalf("zero limit len = %d, want 20", len(zero))
	}
	if len(negative) != 20 {
		t.Fatalf("negative limit len = %d, want 20", len(negative))
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

func TestDailyRecommendationsStableWithinServerLocalDateWithHistory(t *testing.T) {
	s := newTestStore(t)
	ids := seedRecommendationTracks(t, s, 120)
	early := time.Date(2026, 5, 22, 0, 5, 0, 0, time.Local)
	late := time.Date(2026, 5, 22, 23, 55, 0, 0, time.Local)

	for i, id := range ids {
		playedAt := early.Unix()
		if i%2 != 0 {
			playedAt = late.Unix()
		}
		if err := s.UpsertPlaybackHistory(PlaybackHistoryUpdate{
			TrackID:      id,
			PositionMS:   1000,
			DurationMS:   10000,
			PlaybackMode: "audio",
			ContextLabel: "Test",
			PlayedAt:     playedAt,
		}); err != nil {
			t.Fatalf("UpsertPlaybackHistory %d: %v", id, err)
		}
	}

	first, err := s.DailyRecommendations(early, 50)
	if err != nil {
		t.Fatalf("DailyRecommendations early: %v", err)
	}
	second, err := s.DailyRecommendations(late, 50)
	if err != nil {
		t.Fatalf("DailyRecommendations late: %v", err)
	}

	if !reflect.DeepEqual(trackIDs(first), trackIDs(second)) {
		t.Fatalf("same server-local date order changed with history: early=%v late=%v", trackIDs(first), trackIDs(second))
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

func TestDailyRecommendationsCapsFavoritesToQuarterOfLimit(t *testing.T) {
	s := newTestStore(t)
	ids := seedRecommendationTracks(t, s, 60)
	favoriteIDs := make(map[int64]bool, 20)
	for _, id := range ids[:20] {
		if err := s.AddFavorite(id); err != nil {
			t.Fatalf("AddFavorite %d: %v", id, err)
		}
		favoriteIDs[id] = true
	}

	got, err := s.DailyRecommendations(time.Date(2026, 5, 22, 10, 0, 0, 0, time.Local), 20)
	if err != nil {
		t.Fatalf("DailyRecommendations: %v", err)
	}

	if len(got) != 20 {
		t.Fatalf("len(got) = %d, want 20", len(got))
	}
	favoriteCount := 0
	for _, track := range got {
		if favoriteIDs[track.ID] {
			favoriteCount++
		}
	}
	if favoriteCount != 5 {
		t.Fatalf("favorite recommendations = %d, want 5: %v", favoriteCount, trackIDs(got))
	}
}

func TestDailyRecommendationsScoreAnchorsRecencyToLocalDate(t *testing.T) {
	now := time.Date(2026, 5, 22, 10, 0, 0, 0, time.Local)
	localNow := now.Local()
	date := localNow.Format("2006-01-02")
	scoreAnchor := recommendationDateAnchor(localNow)
	track := Track{ID: 7}

	recent := recommendationScore(recommendationCandidate{
		Track:    track,
		PlayedAt: scoreAnchor.Unix(),
	}, date, scoreAnchor)
	future := recommendationScore(recommendationCandidate{
		Track:    track,
		PlayedAt: scoreAnchor.Add(2 * time.Hour).Unix(),
	}, date, scoreAnchor)
	stale := recommendationScore(recommendationCandidate{
		Track:    track,
		PlayedAt: scoreAnchor.Add(-31 * 24 * time.Hour).Unix(),
	}, date, scoreAnchor)

	if future != recent {
		t.Fatalf("future playback score = %v, want same as most recent score %v", future, recent)
	}
	if stale >= recent {
		t.Fatalf("stale playback score = %v, want less than recent score %v", stale, recent)
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

func seedNonPlayableRecommendationTracks(t *testing.T, s *Store) {
	t.Helper()
	albumID, err := s.UpsertAlbum("Recommendation Non-Playable Album", "", 0, "")
	if err != nil {
		t.Fatalf("UpsertAlbum non-playable: %v", err)
	}
	if err := s.UpsertTrack("Recommendation Empty Audio", "", "", "", albumID, 1, 1, "Artist", 2026, 180, ""); err != nil {
		t.Fatalf("UpsertTrack empty audio: %v", err)
	}
	if err := s.UpsertTrack("Recommendation Whitespace Audio", "   ", "", "", albumID, 1, 2, "Artist", 2026, 180, ""); err != nil {
		t.Fatalf("UpsertTrack whitespace audio: %v", err)
	}
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
