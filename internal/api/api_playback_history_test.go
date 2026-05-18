package api

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"testing"
)

func TestPlaybackHistoryHTTPPostClampsAndPersists(t *testing.T) {
	h := newTestHandler(t)
	trackID := seedPlaybackHistoryAPITrack(t, h, "Track", "/music/track.flac")

	body := fmt.Sprintf(`{
		"track_id": %d,
		"position_ms": 12000,
		"duration_ms": 10000,
		"playback_mode": "invalid",
		"context_label": " Album / Context "
	}`, trackID)
	rr := doReq(h, http.MethodPost, "/api/playback/history", body)
	if rr.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want %d: %s", rr.Code, http.StatusNoContent, rr.Body.String())
	}

	items, err := h.store.ListPlaybackHistory(10)
	if err != nil {
		t.Fatalf("list history: %v", err)
	}
	if len(items) != 1 {
		t.Fatalf("history length = %d, want 1", len(items))
	}
	got := items[0]
	if got.PositionMS != 10000 || got.DurationMS != 10000 || got.PlaybackMode != "audio" || got.ContextLabel != "Album / Context" {
		t.Fatalf("unexpected persisted row: %+v", got)
	}
}

func TestPlaybackHistoryHTTPPostRejectsInvalidTrack(t *testing.T) {
	h := newTestHandler(t)

	for _, body := range []string{
		`{"track_id":0}`,
		`{"track_id":-1}`,
	} {
		rr := doReq(h, http.MethodPost, "/api/playback/history", body)
		if rr.Code != http.StatusBadRequest {
			t.Fatalf("body %s status = %d, want %d", body, rr.Code, http.StatusBadRequest)
		}
	}
}

func TestPlaybackHistoryHTTPGetReturnsNewestRowsAndHonorsLimit(t *testing.T) {
	h := newTestHandler(t)
	for i := 0; i < 3; i++ {
		trackID := seedPlaybackHistoryAPITrack(t, h, fmt.Sprintf("Track %d", i), fmt.Sprintf("/music/api-track-%d.flac", i))
		body := fmt.Sprintf(`{"track_id":%d,"position_ms":%d,"duration_ms":10000,"playback_mode":"audio","context_label":"Queue"}`, trackID, i*1000)
		rr := doReq(h, http.MethodPost, "/api/playback/history", body)
		if rr.Code != http.StatusNoContent {
			t.Fatalf("post %d status = %d: %s", i, rr.Code, rr.Body.String())
		}
	}

	rr := doReq(h, http.MethodGet, "/api/playback/history?limit=2", "")
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d: %s", rr.Code, http.StatusOK, rr.Body.String())
	}

	var resp struct {
		Items []struct {
			Track struct {
				Title string `json:"title"`
			} `json:"track"`
			PositionMS int64 `json:"position_ms"`
		} `json:"items"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if len(resp.Items) != 2 {
		t.Fatalf("items length = %d, want 2", len(resp.Items))
	}
	if !strings.HasPrefix(resp.Items[0].Track.Title, "Track 2") || !strings.HasPrefix(resp.Items[1].Track.Title, "Track 1") {
		t.Fatalf("unexpected order: %+v", resp.Items)
	}
}

func seedPlaybackHistoryAPITrack(t *testing.T, h *Handler, title, audioPath string) int64 {
	t.Helper()
	albumID, err := h.store.UpsertAlbum(title+" Album", "", 0, "")
	if err != nil {
		t.Fatalf("upsert album: %v", err)
	}
	if err := h.store.UpsertTrack(title, audioPath, "", "", albumID, 1, 1, "", 2024, 180, "FLAC"); err != nil {
		t.Fatalf("upsert track: %v", err)
	}
	tracks, err := h.store.ListTracks()
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
