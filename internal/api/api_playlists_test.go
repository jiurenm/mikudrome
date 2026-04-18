package api

import (
	"bytes"
	"encoding/json"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"net/textproto"
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

func createTestPlaylist(t *testing.T, h *Handler, name string) int64 {
	t.Helper()
	rr := doReq(h, "POST", "/api/playlists", `{"name":"`+name+`"}`)
	if rr.Code != http.StatusCreated {
		t.Fatalf("createPlaylist: expected 201, got %d: %s", rr.Code, rr.Body.String())
	}
	var resp struct {
		ID int64 `json:"id"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	return resp.ID
}

func getPlaylistDetail(t *testing.T, h *Handler, playlistID int64) store.PlaylistDetail {
	t.Helper()
	detail, ok, err := h.store.GetPlaylistDetail(playlistID)
	if err != nil {
		t.Fatal(err)
	}
	if !ok {
		t.Fatalf("playlist %d not found", playlistID)
	}
	return detail
}

func mustJSON(t *testing.T, value interface{}) string {
	t.Helper()
	body, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	return string(body)
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

func TestPlaylistsHTTP_EmptyPlaylistHasEmptyCoverIDArrays(t *testing.T) {
	h := newTestHandler(t)

	playlistID := createTestPlaylist(t, h, "Empty Covers")
	playlistIDStr := mustJSON(t, playlistID)

	rr := doReq(h, "GET", "/api/playlists/"+playlistIDStr, "")
	if rr.Code != http.StatusOK {
		t.Fatalf("getPlaylist: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	var resp struct {
		CoverTrackIDs []int64 `json:"cover_track_ids"`
		CoverAlbumIDs []int64 `json:"cover_album_ids"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if resp.CoverTrackIDs == nil {
		t.Fatal("expected cover_track_ids to be an empty array, got null")
	}
	if resp.CoverAlbumIDs == nil {
		t.Fatal("expected cover_album_ids to be an empty array, got null")
	}
	if len(resp.CoverTrackIDs) != 0 {
		t.Fatalf("expected 0 cover_track_ids, got %d", len(resp.CoverTrackIDs))
	}
	if len(resp.CoverAlbumIDs) != 0 {
		t.Fatalf("expected 0 cover_album_ids, got %d", len(resp.CoverAlbumIDs))
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

func TestPlaylistItemsHTTP_GroupedReadReturnsUngroupedWithItems(t *testing.T) {
	h := newTestHandler(t)
	t1 := seedTrack(t, h, "GroupedTrack1")
	t2 := seedTrack(t, h, "GroupedTrack2")
	playlistID := createTestPlaylist(t, h, "GroupedRead")
	playlistIDStr := mustJSON(t, playlistID)

	addBody := mustJSON(t, map[string][]int64{"track_ids": []int64{t1, t2}})
	rr := doReq(h, "POST", "/api/playlists/"+playlistIDStr+"/tracks", addBody)
	if rr.Code != http.StatusOK {
		t.Fatalf("addPlaylistTracks: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	rr = doReq(h, "GET", "/api/playlists/"+playlistIDStr+"/items", "")
	if rr.Code != http.StatusOK {
		t.Fatalf("getPlaylistItems: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	var resp struct {
		Playlist struct {
			ID int64 `json:"id"`
		} `json:"playlist"`
		Groups []struct {
			ID       int64  `json:"id"`
			Title    string `json:"title"`
			IsSystem bool   `json:"is_system"`
			Items    []struct {
				ID    int64 `json:"id"`
				Track struct {
					ID    int64  `json:"id"`
					Title string `json:"title"`
				} `json:"track"`
			} `json:"items"`
		} `json:"groups"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if resp.Playlist.ID != playlistID {
		t.Fatalf("expected playlist id %d, got %d", playlistID, resp.Playlist.ID)
	}
	if len(resp.Groups) != 1 {
		t.Fatalf("expected 1 group, got %d", len(resp.Groups))
	}
	group := resp.Groups[0]
	if group.Title != "Ungrouped" {
		t.Fatalf("expected system group title Ungrouped, got %q", group.Title)
	}
	if !group.IsSystem {
		t.Fatal("expected Ungrouped to be marked as system")
	}
	if len(group.Items) != 2 {
		t.Fatalf("expected 2 items in Ungrouped, got %d", len(group.Items))
	}
	if group.Items[0].Track.ID != t1 || group.Items[1].Track.ID != t2 {
		t.Fatalf("expected tracks [%d, %d], got [%d, %d]", t1, t2, group.Items[0].Track.ID, group.Items[1].Track.ID)
	}
}

func TestPlaylistItemsHTTP_EmptyGroupIncludesItemsArray(t *testing.T) {
	h := newTestHandler(t)
	playlistID := createTestPlaylist(t, h, "EmptyGroup")
	playlistIDStr := mustJSON(t, playlistID)

	rr := doReq(h, "POST", "/api/playlists/"+playlistIDStr+"/groups", `{"title":"Empty"}`)
	if rr.Code != http.StatusCreated {
		t.Fatalf("create group: expected 201, got %d: %s", rr.Code, rr.Body.String())
	}
	var createResp struct {
		Title string `json:"title"`
		Items []struct {
			ID int64 `json:"id"`
		} `json:"items"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &createResp); err != nil {
		t.Fatal(err)
	}
	if createResp.Title != "Empty" {
		t.Fatalf("expected create response title Empty, got %q", createResp.Title)
	}
	if createResp.Items == nil {
		t.Fatal("expected create group response items field to be present as empty array")
	}
	if len(createResp.Items) != 0 {
		t.Fatalf("expected create group response to have 0 items, got %d", len(createResp.Items))
	}

	rr = doReq(h, "GET", "/api/playlists/"+playlistIDStr+"/items", "")
	if rr.Code != http.StatusOK {
		t.Fatalf("getPlaylistItems: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	var resp struct {
		Groups []struct {
			Title string `json:"title"`
			Items []struct {
				ID int64 `json:"id"`
			} `json:"items"`
		} `json:"groups"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if len(resp.Groups) != 2 {
		t.Fatalf("expected 2 groups, got %d", len(resp.Groups))
	}
	if resp.Groups[1].Title != "Empty" {
		t.Fatalf("expected created group title Empty, got %q", resp.Groups[1].Title)
	}
	if resp.Groups[1].Items == nil {
		t.Fatal("expected empty group items field to be present as empty array")
	}
	if len(resp.Groups[1].Items) != 0 {
		t.Fatalf("expected empty group to have 0 items, got %d", len(resp.Groups[1].Items))
	}
}

func TestPlaylistGroupsHTTP_SystemGroupRenameAllowedDeleteRejectedAndDeletesMoveItems(t *testing.T) {
	h := newTestHandler(t)
	trackID := seedTrack(t, h, "GroupedDeleteTrack")
	playlistID := createTestPlaylist(t, h, "GroupedDelete")
	playlistIDStr := mustJSON(t, playlistID)

	addBody := mustJSON(t, map[string][]int64{"track_ids": []int64{trackID}})
	rr := doReq(h, "POST", "/api/playlists/"+playlistIDStr+"/tracks", addBody)
	if rr.Code != http.StatusOK {
		t.Fatalf("addPlaylistTracks: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	detail := getPlaylistDetail(t, h, playlistID)
	systemGroupID := detail.Groups[0].ID
	systemGroupIDStr := mustJSON(t, systemGroupID)

	rr = doReq(h, "PATCH", "/api/playlists/"+playlistIDStr+"/groups/"+systemGroupIDStr, `{"title":"Loose Tracks"}`)
	if rr.Code != http.StatusNoContent {
		t.Fatalf("rename system group: expected 204, got %d: %s", rr.Code, rr.Body.String())
	}

	detail = getPlaylistDetail(t, h, playlistID)
	if detail.Groups[0].Title != "Loose Tracks" {
		t.Fatalf("expected renamed system group title Loose Tracks, got %q", detail.Groups[0].Title)
	}

	rr = doReq(h, "DELETE", "/api/playlists/"+playlistIDStr+"/groups/"+systemGroupIDStr, "")
	if rr.Code != http.StatusConflict {
		t.Fatalf("delete system group: expected 409, got %d: %s", rr.Code, rr.Body.String())
	}

	rr = doReq(h, "POST", "/api/playlists/"+playlistIDStr+"/groups", `{"title":"Set B"}`)
	if rr.Code != http.StatusCreated {
		t.Fatalf("create group: expected 201, got %d: %s", rr.Code, rr.Body.String())
	}
	var createGroupResp struct {
		ID       int64  `json:"id"`
		Title    string `json:"title"`
		IsSystem bool   `json:"is_system"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &createGroupResp); err != nil {
		t.Fatal(err)
	}
	if createGroupResp.Title != "Set B" {
		t.Fatalf("expected group title Set B, got %q", createGroupResp.Title)
	}
	if createGroupResp.IsSystem {
		t.Fatal("expected created group to be non-system")
	}

	detail = getPlaylistDetail(t, h, playlistID)
	itemID := detail.Groups[0].Items[0].ID
	if err := h.store.UpdatePlaylistItem(itemID, store.PlaylistItemUpdate{GroupID: &createGroupResp.ID}); err != nil {
		t.Fatal(err)
	}

	groupIDStr := mustJSON(t, createGroupResp.ID)
	rr = doReq(h, "DELETE", "/api/playlists/"+playlistIDStr+"/groups/"+groupIDStr, "")
	if rr.Code != http.StatusNoContent {
		t.Fatalf("delete group: expected 204, got %d: %s", rr.Code, rr.Body.String())
	}

	rr = doReq(h, "GET", "/api/playlists/"+playlistIDStr+"/items", "")
	if rr.Code != http.StatusOK {
		t.Fatalf("getPlaylistItems after delete: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
	var resp struct {
		Groups []struct {
			Title string `json:"title"`
			Items []struct {
				Track struct {
					ID int64 `json:"id"`
				} `json:"track"`
			} `json:"items"`
		} `json:"groups"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if len(resp.Groups) != 1 {
		t.Fatalf("expected 1 remaining group, got %d", len(resp.Groups))
	}
	if resp.Groups[0].Title != "Loose Tracks" {
		t.Fatalf("expected remaining group Loose Tracks, got %q", resp.Groups[0].Title)
	}
	if len(resp.Groups[0].Items) != 1 || resp.Groups[0].Items[0].Track.ID != trackID {
		t.Fatalf("expected track %d moved back to Ungrouped", trackID)
	}
}

func TestPlaylistItemsHTTP_GroupedReorderPersistsShape(t *testing.T) {
	h := newTestHandler(t)
	t1 := seedTrack(t, h, "GroupedReorder1")
	t2 := seedTrack(t, h, "GroupedReorder2")
	t3 := seedTrack(t, h, "GroupedReorder3")
	playlistID := createTestPlaylist(t, h, "GroupedReorder")
	playlistIDStr := mustJSON(t, playlistID)

	addBody := mustJSON(t, map[string][]int64{"track_ids": []int64{t1, t2, t3}})
	rr := doReq(h, "POST", "/api/playlists/"+playlistIDStr+"/tracks", addBody)
	if rr.Code != http.StatusOK {
		t.Fatalf("addPlaylistTracks: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	rr = doReq(h, "POST", "/api/playlists/"+playlistIDStr+"/groups", `{"title":"Highlights"}`)
	if rr.Code != http.StatusCreated {
		t.Fatalf("create group: expected 201, got %d: %s", rr.Code, rr.Body.String())
	}
	var createGroupResp struct {
		ID int64 `json:"id"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &createGroupResp); err != nil {
		t.Fatal(err)
	}

	detail := getPlaylistDetail(t, h, playlistID)
	ungroupedID := detail.Groups[0].ID
	highlightID := createGroupResp.ID
	if len(detail.Groups[0].Items) != 3 {
		t.Fatalf("expected 3 items in Ungrouped, got %d", len(detail.Groups[0].Items))
	}
	item1 := detail.Groups[0].Items[0].ID
	item2 := detail.Groups[0].Items[1].ID
	item3 := detail.Groups[0].Items[2].ID

	reorderBody := mustJSON(t, map[string][]map[string]interface{}{
		"groups": []map[string]interface{}{
			{"id": ungroupedID, "items": []int64{item3, item1}},
			{"id": highlightID, "items": []int64{item2}},
		},
	})
	rr = doReq(h, "PUT", "/api/playlists/"+playlistIDStr+"/items/order", reorderBody)
	if rr.Code != http.StatusNoContent {
		t.Fatalf("grouped reorder: expected 204, got %d: %s", rr.Code, rr.Body.String())
	}

	rr = doReq(h, "GET", "/api/playlists/"+playlistIDStr+"/items", "")
	if rr.Code != http.StatusOK {
		t.Fatalf("getPlaylistItems after reorder: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
	var resp struct {
		Groups []struct {
			ID    int64  `json:"id"`
			Title string `json:"title"`
			Items []struct {
				ID    int64 `json:"id"`
				Track struct {
					ID int64 `json:"id"`
				} `json:"track"`
			} `json:"items"`
		} `json:"groups"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if len(resp.Groups) != 2 {
		t.Fatalf("expected 2 groups after reorder, got %d", len(resp.Groups))
	}
	if resp.Groups[0].ID != ungroupedID || resp.Groups[1].ID != highlightID {
		t.Fatalf("unexpected group order after reorder: [%d, %d]", resp.Groups[0].ID, resp.Groups[1].ID)
	}
	if len(resp.Groups[0].Items) != 2 || resp.Groups[0].Items[0].ID != item3 || resp.Groups[0].Items[1].ID != item1 {
		t.Fatalf("unexpected ungrouped item order after reorder")
	}
	if len(resp.Groups[1].Items) != 1 || resp.Groups[1].Items[0].ID != item2 {
		t.Fatalf("unexpected highlight item order after reorder")
	}
	if resp.Groups[0].Items[0].Track.ID != t3 || resp.Groups[0].Items[1].Track.ID != t1 || resp.Groups[1].Items[0].Track.ID != t2 {
		t.Fatalf("unexpected track grouping after reorder")
	}
}

func TestPlaylistItemsHTTP_GroupedReorderConflictReturnsJSON(t *testing.T) {
	h := newTestHandler(t)
	t1 := seedTrack(t, h, "GroupedConflict1")
	t2 := seedTrack(t, h, "GroupedConflict2")
	playlistID := createTestPlaylist(t, h, "GroupedConflict")
	playlistIDStr := mustJSON(t, playlistID)

	addBody := mustJSON(t, map[string][]int64{"track_ids": []int64{t1, t2}})
	rr := doReq(h, "POST", "/api/playlists/"+playlistIDStr+"/tracks", addBody)
	if rr.Code != http.StatusOK {
		t.Fatalf("addPlaylistTracks: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	detail := getPlaylistDetail(t, h, playlistID)
	ungroupedID := detail.Groups[0].ID
	item1 := detail.Groups[0].Items[0].ID
	item2 := detail.Groups[0].Items[1].ID

	conflictBody := mustJSON(t, map[string][]map[string]interface{}{
		"groups": []map[string]interface{}{
			{"id": ungroupedID, "items": []int64{item1, item1}},
		},
	})
	rr = doReq(h, "PUT", "/api/playlists/"+playlistIDStr+"/items/order", conflictBody)
	if rr.Code != http.StatusConflict {
		t.Fatalf("grouped reorder conflict: expected 409, got %d: %s", rr.Code, rr.Body.String())
	}
	if ct := rr.Header().Get("Content-Type"); !strings.Contains(ct, "application/json") {
		t.Fatalf("grouped reorder conflict: expected JSON content type, got %q", ct)
	}
	var errResp struct {
		Error string `json:"error"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &errResp); err != nil {
		t.Fatal(err)
	}
	if errResp.Error == "" || errResp.Error == "internal" {
		t.Fatalf("expected conflict-style error body, got %q", errResp.Error)
	}

	rr = doReq(h, "GET", "/api/playlists/"+playlistIDStr+"/items", "")
	if rr.Code != http.StatusOK {
		t.Fatalf("getPlaylistItems after conflict: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
	var resp struct {
		Groups []struct {
			ID    int64 `json:"id"`
			Items []struct {
				ID int64 `json:"id"`
			} `json:"items"`
		} `json:"groups"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if len(resp.Groups) != 1 || resp.Groups[0].ID != ungroupedID {
		t.Fatalf("unexpected groups after conflict response")
	}
	if len(resp.Groups[0].Items) != 2 || resp.Groups[0].Items[0].ID != item1 || resp.Groups[0].Items[1].ID != item2 {
		t.Fatalf("expected reorder conflict to leave playlist unchanged")
	}
}

func TestPlaylistItemsHTTP_UpdatePersistsLocalMetadataAndPlacement(t *testing.T) {
	h := newTestHandler(t)
	t1 := seedTrack(t, h, "EditableItem1")
	t2 := seedTrack(t, h, "EditableItem2")
	playlistID := createTestPlaylist(t, h, "EditableItems")
	playlistIDStr := mustJSON(t, playlistID)

	addBody := mustJSON(t, map[string][]int64{"track_ids": []int64{t1, t2}})
	rr := doReq(h, "POST", "/api/playlists/"+playlistIDStr+"/tracks", addBody)
	if rr.Code != http.StatusOK {
		t.Fatalf("addPlaylistTracks: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	rr = doReq(h, "POST", "/api/playlists/"+playlistIDStr+"/groups", `{"title":"Highlights"}`)
	if rr.Code != http.StatusCreated {
		t.Fatalf("create group: expected 201, got %d: %s", rr.Code, rr.Body.String())
	}
	var createGroupResp struct {
		ID int64 `json:"id"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &createGroupResp); err != nil {
		t.Fatal(err)
	}

	detail := getPlaylistDetail(t, h, playlistID)
	ungroupedID := detail.Groups[0].ID
	item1 := detail.Groups[0].Items[0].ID
	item2 := detail.Groups[0].Items[1].ID

	updateBody := mustJSON(t, map[string]interface{}{
		"group_id":         createGroupResp.ID,
		"note":             "playlist-local note",
		"cover_mode":       "library",
		"library_cover_id": "album:42",
		"cached_cover_url": "https://cdn.example.test/covers/42.webp",
	})
	rr = doReq(h, "PATCH", "/api/playlists/"+playlistIDStr+"/items/"+mustJSON(t, item1), updateBody)
	if rr.Code != http.StatusNoContent {
		t.Fatalf("updatePlaylistItem: expected 204, got %d: %s", rr.Code, rr.Body.String())
	}

	rr = doReq(h, "GET", "/api/playlists/"+playlistIDStr+"/items", "")
	if rr.Code != http.StatusOK {
		t.Fatalf("getPlaylistItems after update: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
	var resp struct {
		Groups []struct {
			ID    int64  `json:"id"`
			Title string `json:"title"`
			Items []struct {
				ID             int64  `json:"id"`
				Note           string `json:"note"`
				CoverMode      string `json:"cover_mode"`
				LibraryCoverID string `json:"library_cover_id"`
				CachedCoverURL string `json:"cached_cover_url"`
				Track          struct {
					ID int64 `json:"id"`
				} `json:"track"`
			} `json:"items"`
		} `json:"groups"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if len(resp.Groups) != 2 {
		t.Fatalf("expected 2 groups after item update, got %d", len(resp.Groups))
	}
	if resp.Groups[0].ID != ungroupedID || len(resp.Groups[0].Items) != 1 || resp.Groups[0].Items[0].ID != item2 {
		t.Fatalf("expected second item to remain in Ungrouped after update")
	}
	if resp.Groups[1].ID != createGroupResp.ID || len(resp.Groups[1].Items) != 1 {
		t.Fatalf("expected moved item to appear in target group after update")
	}
	updatedItem := resp.Groups[1].Items[0]
	if updatedItem.ID != item1 || updatedItem.Track.ID != t1 {
		t.Fatalf("expected updated item %d with track %d in target group", item1, t1)
	}
	if updatedItem.Note != "playlist-local note" {
		t.Fatalf("expected note to persist, got %q", updatedItem.Note)
	}
	if updatedItem.CoverMode != "library" {
		t.Fatalf("expected cover_mode library, got %q", updatedItem.CoverMode)
	}
	if updatedItem.LibraryCoverID != "album:42" {
		t.Fatalf("expected library_cover_id to persist, got %q", updatedItem.LibraryCoverID)
	}
	if updatedItem.CachedCoverURL != "https://cdn.example.test/covers/42.webp" {
		t.Fatalf("expected cached_cover_url to persist, got %q", updatedItem.CachedCoverURL)
	}
}

func TestPlaylistItemCoverHTTP_RoundTrip(t *testing.T) {
	h := newTestHandler(t)
	t1 := seedTrack(t, h, "CoverTrack1")
	playlistID := createTestPlaylist(t, h, "Covers")
	playlistIDStr := mustJSON(t, playlistID)

	addBody := mustJSON(t, map[string][]int64{"track_ids": []int64{t1}})
	rr := doReq(h, http.MethodPost, "/api/playlists/"+playlistIDStr+"/tracks", addBody)
	if rr.Code != http.StatusOK {
		t.Fatalf("add tracks: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	detail := getPlaylistDetail(t, h, playlistID)
	itemID := detail.Groups[0].Items[0].ID
	itemIDStr := mustJSON(t, itemID)

	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	partHeader := textproto.MIMEHeader{}
	partHeader.Set("Content-Disposition", `form-data; name="file"; filename="cover.png"`)
	partHeader.Set("Content-Type", "image/png")
	part, err := writer.CreatePart(partHeader)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := part.Write([]byte("fake-image")); err != nil {
		t.Fatal(err)
	}
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}

	req := httptest.NewRequest(
		http.MethodPut,
		"/api/playlists/"+playlistIDStr+"/items/"+itemIDStr+"/cover",
		&body,
	)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	uploadRR := httptest.NewRecorder()
	h.ServeHTTP(uploadRR, req)
	if uploadRR.Code != http.StatusNoContent {
		t.Fatalf("upload item cover: expected 204, got %d: %s", uploadRR.Code, uploadRR.Body.String())
	}

	rr = doReq(h, http.MethodGet, "/api/playlists/"+playlistIDStr+"/items", "")
	if rr.Code != http.StatusOK {
		t.Fatalf("getPlaylistItems after upload: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
	var resp struct {
		Groups []struct {
			Items []struct {
				ID              int64  `json:"id"`
				CoverMode       string `json:"cover_mode"`
				CustomCoverPath string `json:"custom_cover_path"`
			} `json:"items"`
		} `json:"groups"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if len(resp.Groups) != 1 || len(resp.Groups[0].Items) != 1 {
		t.Fatalf("expected exactly one uploaded item in response")
	}
	if resp.Groups[0].Items[0].ID != itemID {
		t.Fatalf("expected item %d, got %d", itemID, resp.Groups[0].Items[0].ID)
	}
	if resp.Groups[0].Items[0].CoverMode != "custom" {
		t.Fatalf("expected cover_mode custom, got %q", resp.Groups[0].Items[0].CoverMode)
	}
	if !strings.Contains(resp.Groups[0].Items[0].CustomCoverPath, "/api/playlists/") {
		t.Fatalf("expected custom cover URL in response, got %q", resp.Groups[0].Items[0].CustomCoverPath)
	}

	coverRR := doReq(h, http.MethodGet, resp.Groups[0].Items[0].CustomCoverPath, "")
	if coverRR.Code != http.StatusOK {
		t.Fatalf("serve item cover: expected 200, got %d: %s", coverRR.Code, coverRR.Body.String())
	}

	rr = doReq(h, http.MethodDelete, "/api/playlists/"+playlistIDStr+"/items/"+itemIDStr+"/cover", "")
	if rr.Code != http.StatusNoContent {
		t.Fatalf("delete item cover: expected 204, got %d: %s", rr.Code, rr.Body.String())
	}

	rr = doReq(h, http.MethodGet, "/api/playlists/"+playlistIDStr+"/items", "")
	if rr.Code != http.StatusOK {
		t.Fatalf("getPlaylistItems after delete: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if resp.Groups[0].Items[0].CoverMode != "default" {
		t.Fatalf("expected cover_mode default after delete, got %q", resp.Groups[0].Items[0].CoverMode)
	}
	if resp.Groups[0].Items[0].CustomCoverPath != "" {
		t.Fatalf("expected custom_cover_path cleared after delete, got %q", resp.Groups[0].Items[0].CustomCoverPath)
	}
}

func TestPlaylistCoverHTTP_PutUploadRoundTrip(t *testing.T) {
	h := newTestHandler(t)
	playlistID := createTestPlaylist(t, h, "PlaylistCoverPut")
	playlistIDStr := mustJSON(t, playlistID)

	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	partHeader := textproto.MIMEHeader{}
	partHeader.Set("Content-Disposition", `form-data; name="file"; filename="cover.png"`)
	partHeader.Set("Content-Type", "image/png")
	part, err := writer.CreatePart(partHeader)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := part.Write([]byte("fake-image")); err != nil {
		t.Fatal(err)
	}
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}

	req := httptest.NewRequest(
		http.MethodPut,
		"/api/playlists/"+playlistIDStr+"/cover",
		&body,
	)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	rr := httptest.NewRecorder()
	h.ServeHTTP(rr, req)
	if rr.Code != http.StatusNoContent {
		t.Fatalf("upload playlist cover via PUT: expected 204, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestPlaylistTracksHTTP_ReorderReturnsConflictOncePlaylistIsGrouped(t *testing.T) {
	h := newTestHandler(t)
	t1 := seedTrack(t, h, "FlatConflict1")
	t2 := seedTrack(t, h, "FlatConflict2")
	playlistID := createTestPlaylist(t, h, "FlatConflict")
	playlistIDStr := mustJSON(t, playlistID)

	addBody := mustJSON(t, map[string][]int64{"track_ids": []int64{t1, t2}})
	rr := doReq(h, "POST", "/api/playlists/"+playlistIDStr+"/tracks", addBody)
	if rr.Code != http.StatusOK {
		t.Fatalf("addPlaylistTracks: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	rr = doReq(h, "POST", "/api/playlists/"+playlistIDStr+"/groups", `{"title":"Moved"}`)
	if rr.Code != http.StatusCreated {
		t.Fatalf("create group: expected 201, got %d: %s", rr.Code, rr.Body.String())
	}
	var createGroupResp struct {
		ID int64 `json:"id"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &createGroupResp); err != nil {
		t.Fatal(err)
	}

	detail := getPlaylistDetail(t, h, playlistID)
	itemID := detail.Groups[0].Items[0].ID
	if err := h.store.UpdatePlaylistItem(itemID, store.PlaylistItemUpdate{GroupID: &createGroupResp.ID}); err != nil {
		t.Fatal(err)
	}

	reorderBody := mustJSON(t, map[string][]int64{"track_ids": []int64{t2, t1}})
	rr = doReq(h, "PUT", "/api/playlists/"+playlistIDStr+"/tracks/order", reorderBody)
	if rr.Code != http.StatusConflict {
		t.Fatalf("flat reorder on grouped playlist: expected 409, got %d: %s", rr.Code, rr.Body.String())
	}

	var errResp struct {
		Error string `json:"error"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &errResp); err != nil {
		t.Fatal(err)
	}
	if errResp.Error == "" || errResp.Error == "internal" {
		t.Fatalf("expected conflict-style error body, got %q", errResp.Error)
	}
}

func TestPlaylistHTTP_UnknownNestedSubrouteReturnsJSONNotFound(t *testing.T) {
	h := newTestHandler(t)
	playlistID := createTestPlaylist(t, h, "NestedMiss")
	playlistIDStr := mustJSON(t, playlistID)

	rr := doReq(h, "GET", "/api/playlists/"+playlistIDStr+"/unknown", "")
	if rr.Code != http.StatusNotFound {
		t.Fatalf("unknown nested subroute: expected 404, got %d: %s", rr.Code, rr.Body.String())
	}

	if ct := rr.Header().Get("Content-Type"); !strings.Contains(ct, "application/json") {
		t.Fatalf("expected JSON content type for unknown nested subroute, got %q", ct)
	}

	var errResp struct {
		Error string `json:"error"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &errResp); err != nil {
		t.Fatal(err)
	}
	if errResp.Error == "" {
		t.Fatal("expected non-empty API error body for unknown nested subroute")
	}
}

func TestPlaylistHTTP_MalformedPlaylistSubroutesReturnJSONNotFound(t *testing.T) {
	h := newTestHandler(t)

	for _, path := range []string{"/api/playlists/", "/api/playlists//tracks"} {
		rr := doReq(h, "GET", path, "")
		if rr.Code != http.StatusNotFound {
			t.Fatalf("%s: expected 404, got %d: %s", path, rr.Code, rr.Body.String())
		}
		if ct := rr.Header().Get("Content-Type"); !strings.Contains(ct, "application/json") {
			t.Fatalf("%s: expected JSON content type, got %q", path, ct)
		}

		var errResp struct {
			Error string `json:"error"`
		}
		if err := json.Unmarshal(rr.Body.Bytes(), &errResp); err != nil {
			t.Fatal(err)
		}
		if errResp.Error == "" {
			t.Fatalf("%s: expected non-empty API error body", path)
		}
	}
}

func TestPlaylistHTTP_DeeperSubroutesReturnJSONNotFound(t *testing.T) {
	h := newTestHandler(t)
	playlistID := createTestPlaylist(t, h, "DeepMiss")
	playlistIDStr := mustJSON(t, playlistID)

	for _, path := range []string{
		"/api/playlists/" + playlistIDStr + "/groups/123/extra",
		"/api/playlists/" + playlistIDStr + "/items/order/extra",
	} {
		rr := doReq(h, "GET", path, "")
		if rr.Code != http.StatusNotFound {
			t.Fatalf("%s: expected 404, got %d: %s", path, rr.Code, rr.Body.String())
		}
		if ct := rr.Header().Get("Content-Type"); !strings.Contains(ct, "application/json") {
			t.Fatalf("%s: expected JSON content type, got %q", path, ct)
		}
		var errResp struct {
			Error string `json:"error"`
		}
		if err := json.Unmarshal(rr.Body.Bytes(), &errResp); err != nil {
			t.Fatal(err)
		}
		if errResp.Error == "" {
			t.Fatalf("%s: expected non-empty API error body", path)
		}
	}
}

func TestPlaylistHTTP_MethodMismatchReturnsJSON(t *testing.T) {
	h := newTestHandler(t)
	playlistID := createTestPlaylist(t, h, "MethodMismatch")
	playlistIDStr := mustJSON(t, playlistID)

	tests := []struct {
		method string
		path   string
	}{
		{method: http.MethodPut, path: "/api/playlists"},
		{method: http.MethodPost, path: "/api/playlists/" + playlistIDStr},
		{method: http.MethodPatch, path: "/api/playlists/" + playlistIDStr + "/cover"},
		{method: http.MethodGet, path: "/api/playlists/" + playlistIDStr + "/groups"},
	}

	for _, tc := range tests {
		rr := doReq(h, tc.method, tc.path, "")
		if rr.Code != http.StatusMethodNotAllowed {
			t.Fatalf("%s %s: expected 405, got %d: %s", tc.method, tc.path, rr.Code, rr.Body.String())
		}
		if ct := rr.Header().Get("Content-Type"); !strings.Contains(ct, "application/json") {
			t.Fatalf("%s %s: expected JSON content type, got %q", tc.method, tc.path, ct)
		}
		var errResp struct {
			Error string `json:"error"`
		}
		if err := json.Unmarshal(rr.Body.Bytes(), &errResp); err != nil {
			t.Fatal(err)
		}
		if errResp.Error == "" {
			t.Fatalf("%s %s: expected non-empty API error body", tc.method, tc.path)
		}
	}
}

func TestPlaylistHTTP_TrailingSlashGroupResourceReturnsJSONNotFound(t *testing.T) {
	h := newTestHandler(t)
	playlistID := createTestPlaylist(t, h, "TrailingGroupSlash")
	playlistIDStr := mustJSON(t, playlistID)

	for _, method := range []string{http.MethodGet, http.MethodPatch, http.MethodDelete} {
		rr := doReq(h, method, "/api/playlists/"+playlistIDStr+"/groups/", "")
		if rr.Code != http.StatusNotFound {
			t.Fatalf("%s trailing slash group resource: expected 404, got %d: %s", method, rr.Code, rr.Body.String())
		}
		if ct := rr.Header().Get("Content-Type"); !strings.Contains(ct, "application/json") {
			t.Fatalf("%s trailing slash group resource: expected JSON content type, got %q", method, ct)
		}
		var errResp struct {
			Error string `json:"error"`
		}
		if err := json.Unmarshal(rr.Body.Bytes(), &errResp); err != nil {
			t.Fatal(err)
		}
		if errResp.Error == "" {
			t.Fatalf("%s trailing slash group resource: expected non-empty API error body", method)
		}
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
