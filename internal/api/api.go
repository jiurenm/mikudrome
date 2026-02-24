package api

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/mikudrome/mikudrome/internal/store"
)

// Handler serves the REST API and static file streaming.
type Handler struct {
	store     *store.Store
	mediaRoot string
}

// New returns an HTTP handler for the API.
func New(s *store.Store, mediaRoot string) *Handler {
	return &Handler{store: s, mediaRoot: mediaRoot}
}

// ServeHTTP routes /api/tracks, /api/tracks/:id, and /api/stream/...
func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// CORS: allow Flutter Web (and other browsers) to call API from another origin
	addCORSHeaders(w, r)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if r.URL.Path == "/api/tracks" && r.Method == http.MethodGet {
		h.listTracks(w, r)
		return
	}
	if strings.HasPrefix(r.URL.Path, "/api/tracks/") && r.Method == http.MethodGet {
		idStr := strings.TrimPrefix(r.URL.Path, "/api/tracks/")
		if idStr != "" {
			h.getTrack(w, r, idStr)
			return
		}
	}
	if strings.HasPrefix(r.URL.Path, "/api/stream/") {
		h.serveStream(w, r)
		return
	}
	http.NotFound(w, r)
}

func (h *Handler) listTracks(w http.ResponseWriter, _ *http.Request) {
	tracks, err := h.store.ListTracks()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]interface{}{"tracks": tracks})
}

func (h *Handler) getTrack(w http.ResponseWriter, _ *http.Request, idStr string) {
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}
	track, ok, err := h.store.GetTrackByID(id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if !ok {
		http.NotFound(w, nil)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(track)
}

// serveStream serves audio or video file by track ID and type (audio|video).
// Path format: /api/stream/:id/audio or /api/stream/:id/video
func (h *Handler) serveStream(w http.ResponseWriter, r *http.Request) {
	trimmed := strings.TrimPrefix(r.URL.Path, "/api/stream/")
	parts := strings.SplitN(trimmed, "/", 2)
	if len(parts) != 2 {
		http.NotFound(w, r)
		return
	}
	id, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}
	track, ok, err := h.store.GetTrackByID(id)
	if err != nil || !ok {
		http.NotFound(w, r)
		return
	}
	var path string
	switch parts[1] {
	case "audio":
		path = track.AudioPath
	case "video":
		path = track.VideoPath
	default:
		http.NotFound(w, r)
		return
	}
	if path == "" {
		http.NotFound(w, r)
		return
	}
	http.ServeFile(w, r, path)
}

func addCORSHeaders(w http.ResponseWriter, r *http.Request) {
	origin := r.Header.Get("Origin")
	if origin == "" {
		origin = "*"
	}
	w.Header().Set("Access-Control-Allow-Origin", origin)
	w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
}
