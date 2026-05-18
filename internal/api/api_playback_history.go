package api

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/mikudrome/mikudrome/internal/store"
)

func (h *Handler) savePlaybackHistory(w http.ResponseWriter, r *http.Request) {
	var req struct {
		TrackID      int64  `json:"track_id"`
		PositionMS   int64  `json:"position_ms"`
		DurationMS   int64  `json:"duration_ms"`
		PlaybackMode string `json:"playback_mode"`
		ContextLabel string `json:"context_label"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, "invalid json", http.StatusBadRequest)
		return
	}
	if req.TrackID <= 0 {
		jsonError(w, "track_id must be positive", http.StatusBadRequest)
		return
	}
	mode := req.PlaybackMode
	if mode != "video" {
		mode = "audio"
	}
	update := store.PlaybackHistoryUpdate{
		TrackID:      req.TrackID,
		PositionMS:   req.PositionMS,
		DurationMS:   req.DurationMS,
		PlaybackMode: mode,
		ContextLabel: strings.TrimSpace(req.ContextLabel),
		PlayedAt:     time.Now().Unix(),
	}
	if err := h.store.UpsertPlaybackHistory(update); err != nil {
		jsonError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) listPlaybackHistory(w http.ResponseWriter, r *http.Request) {
	limit := 50
	if raw := r.URL.Query().Get("limit"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil {
			jsonError(w, "invalid limit", http.StatusBadRequest)
			return
		}
		limit = parsed
	}
	items, err := h.store.ListPlaybackHistory(limit)
	if err != nil {
		jsonError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	json.NewEncoder(w).Encode(map[string]any{"items": items})
}
