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
	return map[string]interface{}{
		"id":               p.ID,
		"name":             p.Name,
		"cover_path":       coverURL,
		"track_count":      p.TrackCount,
		"cover_track_ids":  p.CoverTrackIDs,
		"cover_album_ids":  p.CoverAlbumIDs,
		"created_at":       p.CreatedAt,
		"updated_at":       p.UpdatedAt,
	}
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
		if strings.Contains(err.Error(), "reorder set mismatch") {
			jsonError(w, "reorder set mismatch", http.StatusConflict)
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
