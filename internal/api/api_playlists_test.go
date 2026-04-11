package api

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"

	"github.com/mikudrome/mikudrome/internal/store"
)

func newTestHandler(t *testing.T) *Handler {
	t.Helper()
	dir := t.TempDir()
	s, err := store.New(filepath.Join(dir, "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { s.Close() })
	coverDir := filepath.Join(dir, "covers")
	return New(s, dir, "", "", coverDir)
}

func doReq(h http.Handler, method, path, body string) *httptest.ResponseRecorder {
	var reader io.Reader
	if body != "" {
		reader = strings.NewReader(body)
	}
	req := httptest.NewRequest(method, path, reader)
	if body != "" {
		req.Header.Set("Content-Type", "application/json")
	}
	rr := httptest.NewRecorder()
	h.ServeHTTP(rr, req)
	return rr
}

// seedTrack inserts a minimal producer+album+track and returns the track ID.
func seedTrack(t *testing.T, h *Handler, title string) int64 {
	t.Helper()
	pid, err := h.store.UpsertProducer("TestProducer", "")
	if err != nil {
		t.Fatal(err)
	}
	aid, err := h.store.UpsertAlbum("TestAlbum", "", pid, "")
	if err != nil {
		t.Fatal(err)
	}
	err = h.store.UpsertTrack(title, "/tmp/"+title+".flac", "", "", aid, 1, 1, "", 2024, 180, "FLAC")
	if err != nil {
		t.Fatal(err)
	}
	tracks, err := h.store.ListTracks()
	if err != nil {
		t.Fatal(err)
	}
	for _, tr := range tracks {
		if tr.Title == title {
			return tr.ID
		}
	}
	t.Fatalf("track %q not found after seed", title)
	return 0
}

func TestFavoritesHTTP_RoundTrip(t *testing.T) {
	h := newTestHandler(t)
	tid := seedTrack(t, h, "FavSong")

	tidStr := strings.TrimSpace(strings.Replace(
		strings.Replace(
			func() string { b, _ := json.Marshal(tid); return string(b) }(),
			"\"", "", -1), " ", "", -1))

	// POST /api/favorites/:id -> 204
	rr := doReq(h, "POST", "/api/favorites/"+tidStr, "")
	if rr.Code != http.StatusNoContent {
		t.Fatalf("addFavorite: expected 204, got %d: %s", rr.Code, rr.Body.String())
	}

	// GET /api/favorites -> has track
	rr = doReq(h, "GET", "/api/favorites", "")
	if rr.Code != http.StatusOK {
		t.Fatalf("listFavorites: expected 200, got %d", rr.Code)
	}
	var favResp struct {
		Tracks []struct {
			ID         int64 `json:"id"`
			IsFavorite bool  `json:"is_favorite"`
		} `json:"tracks"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &favResp); err != nil {
		t.Fatal(err)
	}
	if len(favResp.Tracks) != 1 {
		t.Fatalf("expected 1 favorite track, got %d", len(favResp.Tracks))
	}
	if favResp.Tracks[0].ID != tid {
		t.Fatalf("expected track id %d, got %d", tid, favResp.Tracks[0].ID)
	}
	if !favResp.Tracks[0].IsFavorite {
		t.Fatal("expected is_favorite=true")
	}

	// DELETE /api/favorites/:id -> 204
	rr = doReq(h, "DELETE", "/api/favorites/"+tidStr, "")
	if rr.Code != http.StatusNoContent {
		t.Fatalf("removeFavorite: expected 204, got %d: %s", rr.Code, rr.Body.String())
	}

	// GET /api/favorites -> empty
	rr = doReq(h, "GET", "/api/favorites", "")
	if err := json.Unmarshal(rr.Body.Bytes(), &favResp); err != nil {
		t.Fatal(err)
	}
	if len(favResp.Tracks) != 0 {
		t.Fatalf("expected 0 favorite tracks after remove, got %d", len(favResp.Tracks))
	}
}

func TestPlaylistsHTTP_CRUD(t *testing.T) {
	h := newTestHandler(t)

	// POST /api/playlists -> 201
	rr := doReq(h, "POST", "/api/playlists", `{"name":"My Playlist"}`)
	if rr.Code != http.StatusCreated {
		t.Fatalf("createPlaylist: expected 201, got %d: %s", rr.Code, rr.Body.String())
	}
	var createResp struct {
		ID   int64  `json:"id"`
		Name string `json:"name"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &createResp); err != nil {
		t.Fatal(err)
	}
	if createResp.Name != "My Playlist" {
		t.Fatalf("expected name 'My Playlist', got %q", createResp.Name)
	}
	plID := createResp.ID

	// GET /api/playlists -> has playlist
	rr = doReq(h, "GET", "/api/playlists", "")
	if rr.Code != http.StatusOK {
		t.Fatalf("listPlaylists: expected 200, got %d", rr.Code)
	}
	var listResp struct {
		Playlists []struct {
			ID   int64  `json:"id"`
			Name string `json:"name"`
		} `json:"playlists"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &listResp); err != nil {
		t.Fatal(err)
	}
	if len(listResp.Playlists) != 1 {
		t.Fatalf("expected 1 playlist, got %d", len(listResp.Playlists))
	}

	// PATCH /api/playlists/:id -> 204
	plIDStr := func() string { b, _ := json.Marshal(plID); return string(b) }()
	rr = doReq(h, "PATCH", "/api/playlists/"+plIDStr, `{"name":"Renamed"}`)
	if rr.Code != http.StatusNoContent {
		t.Fatalf("renamePlaylist: expected 204, got %d: %s", rr.Code, rr.Body.String())
	}

	// GET /api/playlists/:id -> renamed
	rr = doReq(h, "GET", "/api/playlists/"+plIDStr, "")
	if rr.Code != http.StatusOK {
		t.Fatalf("getPlaylist: expected 200, got %d", rr.Code)
	}
	var getResp struct {
		Name string `json:"name"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &getResp); err != nil {
		t.Fatal(err)
	}
	if getResp.Name != "Renamed" {
		t.Fatalf("expected name 'Renamed', got %q", getResp.Name)
	}

	// DELETE /api/playlists/:id -> 204
	rr = doReq(h, "DELETE", "/api/playlists/"+plIDStr, "")
	if rr.Code != http.StatusNoContent {
		t.Fatalf("deletePlaylist: expected 204, got %d: %s", rr.Code, rr.Body.String())
	}

	// GET /api/playlists/:id -> 404
	rr = doReq(h, "GET", "/api/playlists/"+plIDStr, "")
	if rr.Code != http.StatusNotFound {
		t.Fatalf("getPlaylist after delete: expected 404, got %d", rr.Code)
	}
}

func TestPlaylistTracksHTTP_RoundTrip(t *testing.T) {
	h := newTestHandler(t)
	t1 := seedTrack(t, h, "Track1")
	t2 := seedTrack(t, h, "Track2")

	// Create a playlist
	rr := doReq(h, "POST", "/api/playlists", `{"name":"TrackList"}`)
	if rr.Code != http.StatusCreated {
		t.Fatalf("createPlaylist: expected 201, got %d: %s", rr.Code, rr.Body.String())
	}
	var createResp struct {
		ID int64 `json:"id"`
	}
	json.Unmarshal(rr.Body.Bytes(), &createResp)
	plIDStr := func() string { b, _ := json.Marshal(createResp.ID); return string(b) }()

	// POST /api/playlists/:id/tracks -> add tracks
	body, _ := json.Marshal(map[string][]int64{"track_ids": {t1, t2}})
	rr = doReq(h, "POST", "/api/playlists/"+plIDStr+"/tracks", string(body))
	if rr.Code != http.StatusOK {
		t.Fatalf("addPlaylistTracks: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
	var addResp struct {
		Added int `json:"added"`
	}
	json.Unmarshal(rr.Body.Bytes(), &addResp)
	if addResp.Added != 2 {
		t.Fatalf("expected 2 added, got %d", addResp.Added)
	}

	// GET /api/playlists/:id/tracks -> has 2 tracks
	rr = doReq(h, "GET", "/api/playlists/"+plIDStr+"/tracks", "")
	if rr.Code != http.StatusOK {
		t.Fatalf("getPlaylistTracks: expected 200, got %d", rr.Code)
	}
	var tracksResp struct {
		Tracks []struct {
			ID         int64 `json:"id"`
			IsFavorite bool  `json:"is_favorite"`
		} `json:"tracks"`
	}
	json.Unmarshal(rr.Body.Bytes(), &tracksResp)
	if len(tracksResp.Tracks) != 2 {
		t.Fatalf("expected 2 tracks, got %d", len(tracksResp.Tracks))
	}

	// PUT /api/playlists/:id/tracks/order -> reorder
	reorderBody, _ := json.Marshal(map[string][]int64{"track_ids": {t2, t1}})
	rr = doReq(h, "PUT", "/api/playlists/"+plIDStr+"/tracks/order", string(reorderBody))
	if rr.Code != http.StatusNoContent {
		t.Fatalf("reorderPlaylistTracks: expected 204, got %d: %s", rr.Code, rr.Body.String())
	}

	// Verify reorder
	rr = doReq(h, "GET", "/api/playlists/"+plIDStr+"/tracks", "")
	json.Unmarshal(rr.Body.Bytes(), &tracksResp)
	if tracksResp.Tracks[0].ID != t2 || tracksResp.Tracks[1].ID != t1 {
		t.Fatalf("reorder failed: expected [%d, %d], got [%d, %d]",
			t2, t1, tracksResp.Tracks[0].ID, tracksResp.Tracks[1].ID)
	}

	// PUT /api/playlists/:id/tracks/order with mismatch -> 409
	badBody, _ := json.Marshal(map[string][]int64{"track_ids": {t1}})
	rr = doReq(h, "PUT", "/api/playlists/"+plIDStr+"/tracks/order", string(badBody))
	if rr.Code != http.StatusConflict {
		t.Fatalf("reorder mismatch: expected 409, got %d: %s", rr.Code, rr.Body.String())
	}

	// DELETE /api/playlists/:id/tracks -> remove track
	removeBody, _ := json.Marshal(map[string][]int64{"track_ids": {t1}})
	rr = doReq(h, "DELETE", "/api/playlists/"+plIDStr+"/tracks", string(removeBody))
	if rr.Code != http.StatusNoContent {
		t.Fatalf("removePlaylistTracks: expected 204, got %d: %s", rr.Code, rr.Body.String())
	}

	// Verify removal
	rr = doReq(h, "GET", "/api/playlists/"+plIDStr+"/tracks", "")
	json.Unmarshal(rr.Body.Bytes(), &tracksResp)
	if len(tracksResp.Tracks) != 1 {
		t.Fatalf("expected 1 track after remove, got %d", len(tracksResp.Tracks))
	}
	if tracksResp.Tracks[0].ID != t2 {
		t.Fatalf("remaining track should be %d, got %d", t2, tracksResp.Tracks[0].ID)
	}
}

func TestTracksEndpoint_HasIsFavorite(t *testing.T) {
	h := newTestHandler(t)
	tid := seedTrack(t, h, "TestTrack")

	// GET /api/tracks should include is_favorite field (false initially)
	rr := doReq(h, "GET", "/api/tracks", "")
	if rr.Code != http.StatusOK {
		t.Fatalf("listTracks: expected 200, got %d", rr.Code)
	}
	var resp struct {
		Tracks []struct {
			ID         int64 `json:"id"`
			IsFavorite bool  `json:"is_favorite"`
		} `json:"tracks"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	found := false
	for _, tr := range resp.Tracks {
		if tr.ID == tid {
			found = true
			if tr.IsFavorite {
				t.Fatal("expected is_favorite=false before favoriting")
			}
		}
	}
	if !found {
		t.Fatalf("track %d not found in /api/tracks response", tid)
	}

	// Favorite the track
	tidStr := func() string { b, _ := json.Marshal(tid); return string(b) }()
	doReq(h, "POST", "/api/favorites/"+tidStr, "")

	// GET /api/tracks should now have is_favorite=true
	rr = doReq(h, "GET", "/api/tracks", "")
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	for _, tr := range resp.Tracks {
		if tr.ID == tid && !tr.IsFavorite {
			t.Fatal("expected is_favorite=true after favoriting")
		}
	}

	// GET /api/tracks/:id should also include is_favorite
	rr = doReq(h, "GET", "/api/tracks/"+tidStr, "")
	if rr.Code != http.StatusOK {
		t.Fatalf("getTrack: expected 200, got %d", rr.Code)
	}
	var singleResp struct {
		ID         int64 `json:"id"`
		IsFavorite bool  `json:"is_favorite"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &singleResp); err != nil {
		t.Fatal(err)
	}
	if !singleResp.IsFavorite {
		t.Fatal("expected is_favorite=true on single track endpoint")
	}
}
