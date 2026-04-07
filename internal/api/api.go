package api

import (
	"encoding/json"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/mikudrome/mikudrome/internal/scanner"
	"github.com/mikudrome/mikudrome/internal/store"
)

// Handler serves the REST API, static file streaming, and Flutter web static files.
type Handler struct {
	store      *store.Store
	mediaRoot  string
	webRoot    string
	ytdlpProxy string
}

// New returns an HTTP handler for the API.
func New(s *store.Store, mediaRoot, webRoot, ytdlpProxy string) *Handler {
	return &Handler{store: s, mediaRoot: mediaRoot, webRoot: webRoot, ytdlpProxy: ytdlpProxy}
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
	if strings.HasPrefix(r.URL.Path, "/api/tracks/") {
		trimmed := strings.TrimPrefix(r.URL.Path, "/api/tracks/")
		parts := strings.SplitN(trimmed, "/", 2)
		if parts[0] != "" {
			if len(parts) == 2 && parts[1] == "download-mv" && r.Method == http.MethodPost {
				h.downloadTrackMV(w, r, parts[0])
				return
			}
			if r.Method == http.MethodGet && len(parts) == 1 {
				h.getTrack(w, r, parts[0])
				return
			}
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
		trimmed := strings.TrimPrefix(r.URL.Path, "/api/producers/")
		if trimmed != "" {
			parts := strings.SplitN(trimmed, "/", 2)
			idStr := parts[0]
			if id, err := strconv.ParseInt(idStr, 10, 64); err == nil && id > 0 {
				if len(parts) == 2 && parts[1] == "avatar" {
					h.serveProducerAvatar(w, r, id)
				} else if len(parts) == 1 {
					h.getProducer(w, r, id)
				} else {
					http.NotFound(w, r)
				}
			} else {
				http.Error(w, "invalid producer id", http.StatusBadRequest)
			}
			return
		}
	}
	if r.URL.Path == "/api/vocalists" && r.Method == http.MethodGet {
		h.listVocalists(w, r)
		return
	}
	if strings.HasPrefix(r.URL.Path, "/api/vocalists/") && r.Method == http.MethodGet {
		trimmed := strings.TrimPrefix(r.URL.Path, "/api/vocalists/")
		if trimmed != "" {
			parts := strings.SplitN(trimmed, "/", 2)
			vocalistName, err := url.PathUnescape(parts[0])
			if err != nil {
				http.Error(w, "invalid vocalist name", http.StatusBadRequest)
				return
			}
			if len(parts) == 2 && parts[1] == "tracks" {
				h.getVocalistTracks(w, r, vocalistName)
			} else if len(parts) == 1 {
				h.getVocalistTracks(w, r, vocalistName)
			} else {
				http.NotFound(w, r)
			}
			return
		}
	}
	if r.URL.Path == "/api/db/backup" && r.Method == http.MethodGet {
		h.serveDBBackup(w, r)
		return
	}
	if r.URL.Path == "/api/videos" && r.Method == http.MethodGet {
		h.listVideos(w, r)
		return
	}
	if strings.HasPrefix(r.URL.Path, "/api/videos/") && r.Method == http.MethodGet {
		trimmed := strings.TrimPrefix(r.URL.Path, "/api/videos/")
		parts := strings.SplitN(trimmed, "/", 2)
		if parts[0] != "" {
			id, err := strconv.ParseInt(parts[0], 10, 64)
			if err != nil {
				http.Error(w, "invalid video id", http.StatusBadRequest)
				return
			}
			if len(parts) == 2 && parts[1] == "stream" {
				h.serveVideoStream(w, r, id)
			} else if len(parts) == 2 && parts[1] == "thumb" {
				h.serveVideoThumb(w, r, id)
			} else if len(parts) == 1 {
				h.getVideo(w, r, strconv.FormatInt(id, 10))
			} else {
				http.NotFound(w, r)
			}
			return
		}
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

func (h *Handler) downloadTrackMV(w http.ResponseWriter, r *http.Request, idStr string) {
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
	var body struct {
		URL string `json:"url"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || strings.TrimSpace(body.URL) == "" {
		http.Error(w, "body must be JSON with non-empty \"url\"", http.StatusBadRequest)
		return
	}
	videoURL := strings.TrimSpace(body.URL)
	dir := filepath.Dir(track.AudioPath)
	baseName := strings.TrimSuffix(filepath.Base(track.AudioPath), filepath.Ext(track.AudioPath))
	outputTemplate := filepath.Join(dir, baseName+".%(ext)s")
	outputTemplate = filepath.ToSlash(outputTemplate)

	args := []string{
		"-f", "bestvideo+bestaudio",
		"--merge-output-format", "mp4",
		"--write-thumbnail",
		"--embed-thumbnail",
		"-o", outputTemplate,
		"--no-playlist",
	}

	// 添加代理参数（如果配置了）
	if h.ytdlpProxy != "" {
		args = append(args, "--proxy", h.ytdlpProxy)
	}

	args = append(args, videoURL)

	cmd := exec.Command("yt-dlp", args...)
	if out, err := cmd.CombinedOutput(); err != nil {
		http.Error(w, "yt-dlp failed: "+string(out), http.StatusInternalServerError)
		return
	}
	videoPath := scanner.FindVideoForBase(dir, filepath.Join(dir, baseName))
	if videoPath == "" {
		http.Error(w, "download did not produce a known video file in album dir", http.StatusInternalServerError)
		return
	}
	thumbPath := scanner.FindOrExtractVideoThumb(videoPath)
	if err := h.store.UpdateTrackVideo(id, videoPath, thumbPath); err != nil {
		http.Error(w, "failed to update track: "+err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{
		"video_path":       videoPath,
		"video_thumb_path": thumbPath,
	})
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

func (h *Handler) getProducer(w http.ResponseWriter, _ *http.Request, id int64) {
	producer, ok, err := h.store.GetProducerByID(id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if !ok {
		http.NotFound(w, nil)
		return
	}
	tracks, err := h.store.GetTracksByProducer(id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	albums, err := h.store.GetAlbumsByProducer(id)
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

func (h *Handler) serveProducerAvatar(w http.ResponseWriter, r *http.Request, id int64) {
	producer, ok, err := h.store.GetProducerByID(id)
	if err != nil || !ok || producer.AvatarPath == "" {
		http.NotFound(w, r)
		return
	}
	http.ServeFile(w, r, producer.AvatarPath)
}

func (h *Handler) listVocalists(w http.ResponseWriter, _ *http.Request) {
	vocalists, err := h.store.ListVocalists()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]interface{}{"vocalists": vocalists})
}

func (h *Handler) getVocalistTracks(w http.ResponseWriter, _ *http.Request, name string) {
	tracks, err := h.store.GetTracksByVocalist(name)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	albums, err := h.store.GetAlbumsByVocalist(name)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"name":   name,
		"tracks": tracks,
		"albums": albums,
	})
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

func (h *Handler) listVideos(w http.ResponseWriter, _ *http.Request) {
	videos, err := h.store.ListVideos()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]interface{}{"videos": videos})
}

func (h *Handler) getVideo(w http.ResponseWriter, _ *http.Request, idStr string) {
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}
	video, ok, err := h.store.GetVideoByID(id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if !ok {
		http.NotFound(w, nil)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(video)
}

func (h *Handler) serveVideoStream(w http.ResponseWriter, r *http.Request, id int64) {
	video, ok, err := h.store.GetVideoByID(id)
	if err != nil || !ok || video.Path == "" {
		http.NotFound(w, r)
		return
	}
	http.ServeFile(w, r, video.Path)
}

func (h *Handler) serveVideoThumb(w http.ResponseWriter, r *http.Request, id int64) {
	video, ok, err := h.store.GetVideoByID(id)
	if err != nil || !ok || video.ThumbPath == "" {
		http.NotFound(w, r)
		return
	}
	http.ServeFile(w, r, video.ThumbPath)
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
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
}
