package api

import (
	"encoding/json"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/mikudrome/mikudrome/internal/store"
)

// Handler serves the REST API, static file streaming, and Flutter web static files.
type Handler struct {
	store     *store.Store
	mediaRoot string
	webRoot   string
}

// New returns an HTTP handler for the API.
func New(s *store.Store, mediaRoot, webRoot string) *Handler {
	return &Handler{store: s, mediaRoot: mediaRoot, webRoot: webRoot}
}

// ServeHTTP routes /api/tracks, /api/albums, /api/stream/...
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
	if r.URL.Path == "/api/albums" && r.Method == http.MethodGet {
		h.listAlbums(w, r)
		return
	}
	if strings.HasPrefix(r.URL.Path, "/api/albums/") && r.Method == http.MethodGet {
		trimmed := strings.TrimPrefix(r.URL.Path, "/api/albums/")
		parts := strings.SplitN(trimmed, "/", 2)
		if parts[0] != "" {
			if len(parts) == 2 && parts[1] == "cover" {
				h.serveAlbumCover(w, r, parts[0])
			} else if len(parts) == 1 {
				h.getAlbum(w, r, parts[0])
			} else {
				http.NotFound(w, r)
			}
			return
		}
	}
	if r.URL.Path == "/api/producers" && r.Method == http.MethodGet {
		h.listProducers(w, r)
		return
	}
	if strings.HasPrefix(r.URL.Path, "/api/producers/") && r.Method == http.MethodGet {
		nameEnc := strings.TrimPrefix(r.URL.Path, "/api/producers/")
		if nameEnc != "" {
			parts := strings.SplitN(nameEnc, "/", 2)
			if len(parts) == 2 && parts[1] == "avatar" {
				if name, err := url.PathUnescape(parts[0]); err == nil && name != "" {
					h.serveProducerAvatar(w, r, name)
				} else {
					http.Error(w, "invalid producer name", http.StatusBadRequest)
				}
			} else if name, err := url.PathUnescape(nameEnc); err == nil {
				h.getProducer(w, r, name)
			} else {
				http.Error(w, "invalid producer name", http.StatusBadRequest)
			}
			return
		}
	}
	if r.URL.Path == "/api/db/backup" && r.Method == http.MethodGet {
		h.serveDBBackup(w, r)
		return
	}
	if strings.HasPrefix(r.URL.Path, "/api/stream/") {
		h.serveStream(w, r)
		return
	}
	// Serve Flutter web static files; fallback to index.html for SPA routing
	h.serveWeb(w, r)
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

func (h *Handler) listAlbums(w http.ResponseWriter, _ *http.Request) {
	albums, err := h.store.ListAlbums()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]interface{}{"albums": albums})
}

func (h *Handler) getAlbum(w http.ResponseWriter, _ *http.Request, idStr string) {
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}
	album, ok, err := h.store.GetAlbumByID(id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if !ok {
		http.NotFound(w, nil)
		return
	}
	tracks, err := h.store.GetTracksByAlbumID(id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"album":  album,
		"tracks": tracks,
	})
}

func (h *Handler) listProducers(w http.ResponseWriter, _ *http.Request) {
	producers, err := h.store.ListProducers()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]interface{}{"producers": producers})
}

func (h *Handler) getProducer(w http.ResponseWriter, _ *http.Request, name string) {
	producer, ok, err := h.store.GetProducerByName(name)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if !ok {
		http.NotFound(w, nil)
		return
	}
	tracks, err := h.store.GetTracksByProducer(producer.Name)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	albums, err := h.store.GetAlbumsByProducer(producer.Name)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"producer": &producer,
		"tracks":   tracks,
		"albums":   albums,
	})
}

func (h *Handler) serveProducerAvatar(w http.ResponseWriter, r *http.Request, name string) {
	producer, ok, err := h.store.GetProducerByName(name)
	if err != nil || !ok || producer.AvatarPath == "" {
		http.NotFound(w, r)
		return
	}
	http.ServeFile(w, r, producer.AvatarPath)
}

func (h *Handler) serveAlbumCover(w http.ResponseWriter, r *http.Request, idStr string) {
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	album, ok, err := h.store.GetAlbumByID(id)
	if err != nil || !ok || album.CoverPath == "" {
		http.NotFound(w, r)
		return
	}
	http.ServeFile(w, r, album.CoverPath)
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
	case "thumb":
		path = track.VideoThumbPath
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

// serveDBBackup streams a consistent copy of the database for download (avoids "busy or locked" when copying the file directly).
func (h *Handler) serveDBBackup(w http.ResponseWriter, r *http.Request) {
	tmpPath := filepath.Join(os.TempDir(), "mikudrome-backup-"+strconv.FormatInt(time.Now().UnixNano(), 10)+".db")
	defer os.Remove(tmpPath)

	if err := h.store.BackupTo(tmpPath); err != nil {
		http.Error(w, "backup failed: "+err.Error(), http.StatusInternalServerError)
		return
	}
	info, err := os.Stat(tmpPath)
	if err != nil {
		http.Error(w, "backup stat: "+err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Disposition", `attachment; filename="mikudrome.db"`)
	w.Header().Set("Content-Length", strconv.FormatInt(info.Size(), 10))
	http.ServeFile(w, r, tmpPath)
}

// serveWeb serves static files from webRoot. Non-API GET requests fall back to index.html for SPA routing.
func (h *Handler) serveWeb(w http.ResponseWriter, r *http.Request) {
	if h.webRoot == "" {
		http.NotFound(w, r)
		return
	}
	path := r.URL.Path
	if path == "/" {
		path = "/index.html"
	}
	fpath := filepath.Join(h.webRoot, filepath.FromSlash(path))
	fpath = filepath.Clean(fpath)
	rel, err := filepath.Rel(h.webRoot, fpath)
	if err != nil || strings.HasPrefix(rel, "..") {
		http.NotFound(w, r)
		return
	}
	if info, err := os.Stat(fpath); err == nil && !info.IsDir() {
		http.ServeFile(w, r, fpath)
		return
	}
	// SPA fallback: serve index.html for GET so Flutter router handles client-side routes
	if r.Method == http.MethodGet {
		indexPath := filepath.Join(h.webRoot, "index.html")
		if _, err := os.Stat(indexPath); err == nil {
			http.ServeFile(w, r, indexPath)
			return
		}
	}
	http.NotFound(w, r)
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
