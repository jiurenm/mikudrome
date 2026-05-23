package api

import (
	"net/http"
	"time"
)

func (h *Handler) getDailyRecommendations(w http.ResponseWriter, _ *http.Request) {
	now := time.Now()
	tracks, err := h.store.DailyRecommendations(now, 20)
	if err != nil {
		jsonError(w, "internal", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"date":   now.Local().Format("2006-01-02"),
		"tracks": tagFavorites(tracks, h.loadFavSet()),
	})
}
