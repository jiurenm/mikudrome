package api

import (
	"encoding/json"
	"net/http"
	"strconv"
	"testing"
)

func TestDailyRecommendationsHTTPReturnsDateAndTracks(t *testing.T) {
	h := newTestHandler(t)
	trackID := seedTrack(t, h, "Daily Song")
	rr := doReq(h, http.MethodGet, "/api/recommendations/daily", "")
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d: %s", rr.Code, http.StatusOK, rr.Body.String())
	}

	var resp struct {
		Date   string `json:"date"`
		Tracks []struct {
			ID         int64  `json:"id"`
			Title      string `json:"title"`
			IsFavorite bool   `json:"is_favorite"`
		} `json:"tracks"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.Date == "" {
		t.Fatalf("date is empty")
	}
	if len(resp.Tracks) != 1 {
		t.Fatalf("tracks len = %d, want 1", len(resp.Tracks))
	}
	if resp.Tracks[0].ID != trackID || resp.Tracks[0].Title != "Daily Song" {
		t.Fatalf("unexpected track: %+v", resp.Tracks[0])
	}
}

func TestDailyRecommendationsHTTPTagsFavorites(t *testing.T) {
	h := newTestHandler(t)
	trackID := seedTrack(t, h, "Favorite Daily Song")
	rr := doReq(h, http.MethodPost, "/api/favorites/"+strconv.FormatInt(trackID, 10), "")
	if rr.Code != http.StatusNoContent {
		t.Fatalf("favorite status = %d: %s", rr.Code, rr.Body.String())
	}

	rr = doReq(h, http.MethodGet, "/api/recommendations/daily", "")
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d: %s", rr.Code, http.StatusOK, rr.Body.String())
	}
	var resp struct {
		Tracks []struct {
			ID         int64 `json:"id"`
			IsFavorite bool  `json:"is_favorite"`
		} `json:"tracks"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if len(resp.Tracks) != 1 || resp.Tracks[0].ID != trackID || !resp.Tracks[0].IsFavorite {
		t.Fatalf("favorite track not tagged: %+v", resp.Tracks)
	}
}

func TestDailyRecommendationsHTTPEmptyLibrary(t *testing.T) {
	h := newTestHandler(t)
	rr := doReq(h, http.MethodGet, "/api/recommendations/daily", "")
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d: %s", rr.Code, http.StatusOK, rr.Body.String())
	}
	var resp struct {
		Date   string        `json:"date"`
		Tracks []interface{} `json:"tracks"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.Date == "" {
		t.Fatalf("date is empty")
	}
	if len(resp.Tracks) != 0 {
		t.Fatalf("tracks len = %d, want 0", len(resp.Tracks))
	}
}
