package api

import (
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/mikudrome/mikudrome/internal/store"
)

// TrackDTO wraps a store.Track with the is_favorite field for API responses.
type TrackDTO struct {
	store.Track
	IsFavorite bool `json:"is_favorite"`
}

// tagFavorites converts a slice of tracks into TrackDTOs with is_favorite set.
func tagFavorites(tracks []store.Track, favSet map[int64]bool) []TrackDTO {
	out := make([]TrackDTO, len(tracks))
	for i, t := range tracks {
		out[i] = TrackDTO{Track: t, IsFavorite: favSet[t.ID]}
	}
	return out
}

// loadFavSet returns the set of favorited track IDs, or an empty map on error.
func (h *Handler) loadFavSet() map[int64]bool {
	set, err := h.store.GetFavoriteSet()
	if err != nil {
		return make(map[int64]bool)
	}
	return set
}

// --- JSON helpers ---

func writeJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func jsonError(w http.ResponseWriter, msg string, status int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

// --- Favorites HTTP handlers ---

func (h *Handler) listFavorites(w http.ResponseWriter, _ *http.Request) {
	tracks, err := h.store.ListFavorites()
	if err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	// All favorites are, by definition, favorited
	dtos := make([]TrackDTO, len(tracks))
	for i, t := range tracks {
		dtos[i] = TrackDTO{Track: t, IsFavorite: true}
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"tracks": dtos})
}

func (h *Handler) addFavorite(w http.ResponseWriter, _ *http.Request, trackIDStr string) {
	id, err := strconv.ParseInt(trackIDStr, 10, 64)
	if err != nil {
		jsonError(w, "invalid track id", http.StatusBadRequest)
		return
	}
	if err := h.store.AddFavorite(id); err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) removeFavorite(w http.ResponseWriter, _ *http.Request, trackIDStr string) {
	id, err := strconv.ParseInt(trackIDStr, 10, 64)
	if err != nil {
		jsonError(w, "invalid track id", http.StatusBadRequest)
		return
	}
	if err := h.store.RemoveFavorite(id); err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- Playlists HTTP handlers ---

// playlistWire converts a store.Playlist to the JSON wire format,
// replacing cover_path with a URL if present.
func playlistWire(p store.Playlist) map[string]interface{} {
	coverURL := ""
	if p.CoverPath != "" {
		coverURL = fmt.Sprintf("/api/playlists/%d/cover", p.ID)
	}
	coverTrackIDs := p.CoverTrackIDs
	if coverTrackIDs == nil {
		coverTrackIDs = []int64{}
	}
	coverAlbumIDs := p.CoverAlbumIDs
	if coverAlbumIDs == nil {
		coverAlbumIDs = []int64{}
	}
	return map[string]interface{}{
		"id":              p.ID,
		"name":            p.Name,
		"cover_path":      coverURL,
		"track_count":     p.TrackCount,
		"cover_track_ids": coverTrackIDs,
		"cover_album_ids": coverAlbumIDs,
		"created_at":      p.CreatedAt,
		"updated_at":      p.UpdatedAt,
	}
}

type playlistItemWire struct {
	ID              int64    `json:"id"`
	PlaylistID      int64    `json:"playlist_id"`
	TrackID         int64    `json:"track_id"`
	GroupID         int64    `json:"group_id"`
	Position        int      `json:"position"`
	Note            string   `json:"note"`
	CoverMode       string   `json:"cover_mode"`
	LibraryCoverID  string   `json:"library_cover_id"`
	CachedCoverURL  string   `json:"cached_cover_url"`
	CustomCoverPath string   `json:"custom_cover_path"`
	CreatedAt       int64    `json:"created_at"`
	UpdatedAt       int64    `json:"updated_at"`
	Track           TrackDTO `json:"track"`
}

type playlistGroupWire struct {
	ID         int64              `json:"id"`
	PlaylistID int64              `json:"playlist_id"`
	Title      string             `json:"title"`
	Position   int                `json:"position"`
	IsSystem   bool               `json:"is_system"`
	CreatedAt  int64              `json:"created_at"`
	UpdatedAt  int64              `json:"updated_at"`
	Items      []playlistItemWire `json:"items"`
}

type playlistDetailWire struct {
	Playlist map[string]interface{} `json:"playlist"`
	Groups   []playlistGroupWire    `json:"groups"`
}

func playlistGroupToWire(group store.PlaylistGroup) playlistGroupWire {
	return playlistGroupWire{
		ID:         group.ID,
		PlaylistID: group.PlaylistID,
		Title:      group.Title,
		Position:   group.Position,
		IsSystem:   group.IsSystem,
		CreatedAt:  group.CreatedAt,
		UpdatedAt:  group.UpdatedAt,
		Items:      []playlistItemWire{},
	}
}

func playlistDetailToWire(detail store.PlaylistDetail, favSet map[int64]bool) playlistDetailWire {
	groups := make([]playlistGroupWire, len(detail.Groups))
	for groupIdx, group := range detail.Groups {
		groupWire := playlistGroupToWire(group.PlaylistGroup)
		groupWire.Items = make([]playlistItemWire, len(group.Items))
		for itemIdx, item := range group.Items {
			groupWire.Items[itemIdx] = playlistItemWire{
				ID:              item.ID,
				PlaylistID:      item.PlaylistID,
				TrackID:         item.TrackID,
				GroupID:         item.GroupID,
				Position:        item.Position,
				Note:            item.Note,
				CoverMode:       item.CoverMode,
				LibraryCoverID:  item.LibraryCoverID,
				CachedCoverURL:  item.CachedCoverURL,
				CustomCoverPath: item.CustomCoverPath,
				CreatedAt:       item.CreatedAt,
				UpdatedAt:       item.UpdatedAt,
				Track:           TrackDTO{Track: item.Track, IsFavorite: favSet[item.Track.ID]},
			}
		}
		groups[groupIdx] = groupWire
	}
	return playlistDetailWire{
		Playlist: playlistWire(detail.Playlist),
		Groups:   groups,
	}
}

func parsePlaylistID(idStr string) (int64, error) {
	return strconv.ParseInt(idStr, 10, 64)
}

func parsePlaylistGroupID(groupIDStr string) (int64, error) {
	return strconv.ParseInt(groupIDStr, 10, 64)
}

func (h *Handler) loadPlaylistDetail(id int64) (store.PlaylistDetail, bool, error) {
	return h.store.GetPlaylistDetail(id)
}

func (h *Handler) findPlaylistGroup(playlistID, groupID int64) (store.PlaylistGroupDetail, bool, bool, error) {
	detail, ok, err := h.loadPlaylistDetail(playlistID)
	if err != nil || !ok {
		return store.PlaylistGroupDetail{}, ok, false, err
	}
	for _, group := range detail.Groups {
		if group.ID == groupID {
			return group, true, true, nil
		}
	}
	return store.PlaylistGroupDetail{}, true, false, nil
}

func playlistConflictStatus(err error) (string, int, bool) {
	switch {
	case errors.Is(err, store.ErrSystemPlaylistGroup):
		return "system group cannot be modified", http.StatusConflict, true
	case strings.Contains(err.Error(), "flat reorder unsupported"):
		return "flat reorder unsupported once playlist is grouped", http.StatusConflict, true
	case strings.Contains(err.Error(), "reorder set mismatch"):
		return "reorder set mismatch", http.StatusConflict, true
	case strings.Contains(err.Error(), "reorder group mismatch"):
		return "reorder group mismatch", http.StatusConflict, true
	}
	return "", 0, false
}

func (h *Handler) listPlaylists(w http.ResponseWriter, _ *http.Request) {
	playlists, err := h.store.ListPlaylists()
	if err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	wired := make([]map[string]interface{}, len(playlists))
	for i, p := range playlists {
		wired[i] = playlistWire(p)
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"playlists": wired})
}

func (h *Handler) createPlaylist(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, "invalid json body", http.StatusBadRequest)
		return
	}
	id, err := h.store.CreatePlaylist(body.Name)
	if err != nil {
		if errors.Is(err, store.ErrInvalidName) {
			jsonError(w, "invalid name", http.StatusBadRequest)
			return
		}
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	p, ok, err := h.store.GetPlaylistByID(id)
	if err != nil || !ok {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusCreated, playlistWire(p))
}

func (h *Handler) getPlaylist(w http.ResponseWriter, _ *http.Request, idStr string) {
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}
	p, ok, err := h.store.GetPlaylistByID(id)
	if err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	if !ok {
		jsonError(w, "playlist not found", http.StatusNotFound)
		return
	}
	writeJSON(w, http.StatusOK, playlistWire(p))
}

func (h *Handler) renamePlaylist(w http.ResponseWriter, r *http.Request, idStr string) {
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}
	var body struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, "invalid json body", http.StatusBadRequest)
		return
	}
	err = h.store.RenamePlaylist(id, body.Name)
	if err != nil {
		if errors.Is(err, store.ErrInvalidName) {
			jsonError(w, "invalid name", http.StatusBadRequest)
			return
		}
		if errors.Is(err, sql.ErrNoRows) {
			jsonError(w, "playlist not found", http.StatusNotFound)
			return
		}
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) deletePlaylist(w http.ResponseWriter, _ *http.Request, idStr string) {
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}
	err = h.store.DeletePlaylist(id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			jsonError(w, "playlist not found", http.StatusNotFound)
			return
		}
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) getPlaylistTracks(w http.ResponseWriter, _ *http.Request, idStr string) {
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}
	// Verify playlist exists
	_, ok, err := h.store.GetPlaylistByID(id)
	if err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	if !ok {
		jsonError(w, "playlist not found", http.StatusNotFound)
		return
	}
	tracks, err := h.store.GetPlaylistTracks(id)
	if err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	favSet := h.loadFavSet()
	writeJSON(w, http.StatusOK, map[string]interface{}{"tracks": tagFavorites(tracks, favSet)})
}

func (h *Handler) getPlaylistItems(w http.ResponseWriter, _ *http.Request, idStr string) {
	id, err := parsePlaylistID(idStr)
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}
	detail, ok, err := h.loadPlaylistDetail(id)
	if err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	if !ok {
		jsonError(w, "playlist not found", http.StatusNotFound)
		return
	}
	writeJSON(w, http.StatusOK, playlistDetailToWire(detail, h.loadFavSet()))
}

func (h *Handler) addPlaylistTracks(w http.ResponseWriter, r *http.Request, idStr string) {
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}
	// Verify playlist exists
	_, ok, err := h.store.GetPlaylistByID(id)
	if err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	if !ok {
		jsonError(w, "playlist not found", http.StatusNotFound)
		return
	}
	var body struct {
		TrackIDs []int64 `json:"track_ids"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, "invalid json body", http.StatusBadRequest)
		return
	}
	added, err := h.store.AddTracksToPlaylist(id, body.TrackIDs)
	if err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"added": added})
}

func (h *Handler) removePlaylistTracks(w http.ResponseWriter, r *http.Request, idStr string) {
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}
	// Verify playlist exists
	_, ok, err := h.store.GetPlaylistByID(id)
	if err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	if !ok {
		jsonError(w, "playlist not found", http.StatusNotFound)
		return
	}
	var body struct {
		TrackIDs []int64 `json:"track_ids"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, "invalid json body", http.StatusBadRequest)
		return
	}
	if err := h.store.RemoveTracksFromPlaylist(id, body.TrackIDs); err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) reorderPlaylistTracks(w http.ResponseWriter, r *http.Request, idStr string) {
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}
	// Verify playlist exists
	_, ok, err := h.store.GetPlaylistByID(id)
	if err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	if !ok {
		jsonError(w, "playlist not found", http.StatusNotFound)
		return
	}
	var body struct {
		TrackIDs []int64 `json:"track_ids"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, "invalid json body", http.StatusBadRequest)
		return
	}
	err = h.store.ReorderPlaylist(id, body.TrackIDs)
	if err != nil {
		if msg, status, ok := playlistConflictStatus(err); ok {
			jsonError(w, msg, status)
			return
		}
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) createPlaylistGroup(w http.ResponseWriter, r *http.Request, idStr string) {
	id, err := parsePlaylistID(idStr)
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}
	var body struct {
		Title string `json:"title"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, "invalid json body", http.StatusBadRequest)
		return
	}
	groupID, err := h.store.CreatePlaylistGroup(id, body.Title)
	if err != nil {
		if errors.Is(err, store.ErrInvalidName) {
			jsonError(w, "invalid name", http.StatusBadRequest)
			return
		}
		if errors.Is(err, sql.ErrNoRows) {
			jsonError(w, "playlist not found", http.StatusNotFound)
			return
		}
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	group, playlistExists, groupExists, err := h.findPlaylistGroup(id, groupID)
	if err != nil || !playlistExists || !groupExists {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusCreated, playlistGroupToWire(group.PlaylistGroup))
}

func (h *Handler) renamePlaylistGroup(w http.ResponseWriter, r *http.Request, playlistIDStr, groupIDStr string) {
	playlistID, err := parsePlaylistID(playlistIDStr)
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}
	groupID, err := parsePlaylistGroupID(groupIDStr)
	if err != nil {
		jsonError(w, "invalid group id", http.StatusBadRequest)
		return
	}
	if _, playlistExists, groupExists, err := h.findPlaylistGroup(playlistID, groupID); err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	} else if !playlistExists {
		jsonError(w, "playlist not found", http.StatusNotFound)
		return
	} else if !groupExists {
		jsonError(w, "group not found", http.StatusNotFound)
		return
	}
	var body struct {
		Title string `json:"title"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, "invalid json body", http.StatusBadRequest)
		return
	}
	if err := h.store.RenamePlaylistGroup(groupID, body.Title); err != nil {
		if errors.Is(err, store.ErrInvalidName) {
			jsonError(w, "invalid name", http.StatusBadRequest)
			return
		}
		if msg, status, ok := playlistConflictStatus(err); ok {
			jsonError(w, msg, status)
			return
		}
		if errors.Is(err, sql.ErrNoRows) {
			jsonError(w, "group not found", http.StatusNotFound)
			return
		}
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) deletePlaylistGroup(w http.ResponseWriter, _ *http.Request, playlistIDStr, groupIDStr string) {
	playlistID, err := parsePlaylistID(playlistIDStr)
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}
	groupID, err := parsePlaylistGroupID(groupIDStr)
	if err != nil {
		jsonError(w, "invalid group id", http.StatusBadRequest)
		return
	}
	if _, playlistExists, groupExists, err := h.findPlaylistGroup(playlistID, groupID); err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	} else if !playlistExists {
		jsonError(w, "playlist not found", http.StatusNotFound)
		return
	} else if !groupExists {
		jsonError(w, "group not found", http.StatusNotFound)
		return
	}
	if err := h.store.DeletePlaylistGroup(groupID); err != nil {
		if msg, status, ok := playlistConflictStatus(err); ok {
			jsonError(w, msg, status)
			return
		}
		if errors.Is(err, sql.ErrNoRows) {
			jsonError(w, "group not found", http.StatusNotFound)
			return
		}
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) reorderGroupedPlaylistItems(w http.ResponseWriter, r *http.Request, idStr string) {
	id, err := parsePlaylistID(idStr)
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}
	if _, ok, err := h.loadPlaylistDetail(id); err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	} else if !ok {
		jsonError(w, "playlist not found", http.StatusNotFound)
		return
	}

	var body struct {
		Groups []struct {
			ID    int64   `json:"id"`
			Items []int64 `json:"items"`
		} `json:"groups"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, "invalid json body", http.StatusBadRequest)
		return
	}

	order := make([]store.PlaylistGroupOrder, len(body.Groups))
	for idx, group := range body.Groups {
		if group.ID <= 0 {
			jsonError(w, "invalid group id", http.StatusBadRequest)
			return
		}
		itemIDs := make([]int64, len(group.Items))
		for itemIdx, itemID := range group.Items {
			if itemID <= 0 {
				jsonError(w, "invalid item id", http.StatusBadRequest)
				return
			}
			itemIDs[itemIdx] = itemID
		}
		order[idx] = store.PlaylistGroupOrder{GroupID: group.ID, ItemIDs: itemIDs}
	}

	if err := h.store.ReorderPlaylistItems(id, order); err != nil {
		if msg, status, ok := playlistConflictStatus(err); ok {
			jsonError(w, msg, status)
			return
		}
		if errors.Is(err, sql.ErrNoRows) {
			jsonError(w, "playlist not found", http.StatusNotFound)
			return
		}
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- Playlist cover handlers ---

func (h *Handler) uploadPlaylistCover(w http.ResponseWriter, r *http.Request, idStr string) {
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}
	// Verify playlist exists
	_, ok, err := h.store.GetPlaylistByID(id)
	if err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	if !ok {
		jsonError(w, "playlist not found", http.StatusNotFound)
		return
	}

	// Parse multipart: max 5MB
	if err := r.ParseMultipartForm(5 << 20); err != nil {
		jsonError(w, "cover too large", http.StatusRequestEntityTooLarge)
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		jsonError(w, "missing file field", http.StatusBadRequest)
		return
	}
	defer file.Close()

	// Validate content type
	ct := header.Header.Get("Content-Type")
	var ext string
	switch ct {
	case "image/jpeg":
		ext = ".jpg"
	case "image/png":
		ext = ".png"
	case "image/webp":
		ext = ".webp"
	default:
		jsonError(w, "unsupported image type", http.StatusUnsupportedMediaType)
		return
	}

	// Check size
	if header.Size > 5<<20 {
		jsonError(w, "cover too large", http.StatusRequestEntityTooLarge)
		return
	}

	// Ensure cover dir exists
	if err := os.MkdirAll(h.playlistCoverDir, 0o755); err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}

	// Remove any old cover files for this playlist
	for _, oldExt := range []string{".jpg", ".png", ".webp"} {
		os.Remove(filepath.Join(h.playlistCoverDir, fmt.Sprintf("%d%s", id, oldExt)))
	}

	filename := fmt.Sprintf("%d%s", id, ext)
	destPath := filepath.Join(h.playlistCoverDir, filename)
	dst, err := os.Create(destPath)
	if err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	defer dst.Close()

	if _, err := io.Copy(dst, file); err != nil {
		os.Remove(destPath)
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}

	if err := h.store.SetPlaylistCover(id, filename); err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) deletePlaylistCover(w http.ResponseWriter, _ *http.Request, idStr string) {
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}
	// Get current playlist to find cover path
	p, ok, err := h.store.GetPlaylistByID(id)
	if err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	if !ok {
		jsonError(w, "playlist not found", http.StatusNotFound)
		return
	}
	// Best-effort remove file
	if p.CoverPath != "" {
		os.Remove(filepath.Join(h.playlistCoverDir, p.CoverPath))
	}
	if err := h.store.ClearPlaylistCover(id); err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) servePlaylistCover(w http.ResponseWriter, r *http.Request, idStr string) {
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	p, ok, err := h.store.GetPlaylistByID(id)
	if err != nil || !ok || p.CoverPath == "" {
		http.NotFound(w, r)
		return
	}
	coverFile := filepath.Join(h.playlistCoverDir, p.CoverPath)
	if _, err := os.Stat(coverFile); err != nil {
		http.NotFound(w, r)
		return
	}
	http.ServeFile(w, r, coverFile)
}
