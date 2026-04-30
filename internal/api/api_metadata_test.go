package api

import (
	"encoding/json"
	"net/http"
	"strconv"
	"testing"

	"github.com/mikudrome/mikudrome/internal/store"
)

func TestTrackMetadataHTTP_ListReturnsEditorContext(t *testing.T) {
	h := newTestHandler(t)

	id := seedMetadataTrack(t, h, store.Track{
		Title:           "Track",
		AudioPath:       "/tmp/track.flac",
		TrackNumber:     2,
		DiscNumber:      1,
		ComposerScanned: "scan composer",
		LyricistScanned: "scan lyricist",
	}, store.Album{
		Title:       "Album",
		CoverPath:   "/cover.png",
		AlbumArtist: "kz",
	}, store.Producer{
		Name: "kz",
	})
	if err := h.store.UpdateTrackMetadata(id, store.TrackMetadataPatch{Vocal: strPtr("manual vocal")}); err != nil {
		t.Fatalf("seed manual vocal: %v", err)
	}

	rr := doReq(h, http.MethodGet, "/api/tracks/metadata", "")
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d: %s", rr.Code, http.StatusOK, rr.Body.String())
	}

	var resp struct {
		Tracks []struct {
			ID             int64  `json:"id"`
			AlbumTitle     string `json:"album_title"`
			ProducerName   string `json:"producer_name"`
			Composer       string `json:"composer"`
			ComposerSource string `json:"composer_source"`
		} `json:"tracks"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if len(resp.Tracks) != 1 {
		t.Fatalf("tracks = %d, want 1", len(resp.Tracks))
	}
	if resp.Tracks[0].AlbumTitle != "Album" || resp.Tracks[0].ProducerName != "kz" {
		t.Fatalf("unexpected context row: %+v", resp.Tracks[0])
	}
	if resp.Tracks[0].Composer != "scan composer" || resp.Tracks[0].ComposerSource != "scanned" {
		t.Fatalf("unexpected composer row: %+v", resp.Tracks[0])
	}
}

func TestTrackMetadataHTTP_PatchUpdatesProvidedFieldsOnly(t *testing.T) {
	h := newTestHandler(t)

	id := seedMetadataTrack(t, h, store.Track{
		Title:           "Track",
		AudioPath:       "/tmp/track.flac",
		ComposerScanned: "scan composer",
		LyricistScanned: "scan lyricist",
	}, store.Album{
		Title: "Patch Album",
	}, store.Producer{
		Name: "patch producer",
	})
	if err := h.store.UpdateTrackMetadata(id, store.TrackMetadataPatch{
		Composer: strPtr("manual composer"),
		Arranger: strPtr("old arranger"),
		Remix:    strPtr("old remix"),
		Vocal:    strPtr("old vocal"),
	}); err != nil {
		t.Fatalf("seed patch metadata: %v", err)
	}

	body := `{"composer":"","arranger":"new arranger","remix":"new remix"}`
	rr := doReq(h, http.MethodPatch, "/api/tracks/"+strconv.FormatInt(id, 10)+"/metadata", body)
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d: %s", rr.Code, http.StatusOK, rr.Body.String())
	}

	var resp struct {
		Composer       string `json:"composer"`
		ComposerSource string `json:"composer_source"`
		Arranger       string `json:"arranger"`
		Remix          string `json:"remix"`
		Vocal          string `json:"vocal"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode patch response: %v", err)
	}
	if resp.Composer != "scan composer" || resp.ComposerSource != "scanned" {
		t.Fatalf("composer = %q (%s)", resp.Composer, resp.ComposerSource)
	}
	if resp.Arranger != "new arranger" || resp.Remix != "new remix" || resp.Vocal != "old vocal" {
		t.Fatalf("unexpected patch response: %+v", resp)
	}
}

func TestTrackMetadataHTTP_PatchRejectsNonPositiveID(t *testing.T) {
	h := newTestHandler(t)

	for _, path := range []string{
		"/api/tracks/0/metadata",
		"/api/tracks/-1/metadata",
	} {
		rr := doReq(h, http.MethodPatch, path, `{}`)
		if rr.Code != http.StatusBadRequest {
			t.Fatalf("path %s status = %d, want %d", path, rr.Code, http.StatusBadRequest)
		}
	}
}

func seedMetadataTrack(t *testing.T, h *Handler, track store.Track, album store.Album, producer store.Producer) int64 {
	t.Helper()

	batch, err := h.store.BeginBatch(1)
	if err != nil {
		t.Fatalf("begin batch: %v", err)
	}
	if err := batch.Add(track, album, producer); err != nil {
		t.Fatalf("batch add: %v", err)
	}
	if err := batch.Close(); err != nil {
		t.Fatalf("batch close: %v", err)
	}

	tracks, err := h.store.ListTracks()
	if err != nil {
		t.Fatalf("list tracks: %v", err)
	}
	for _, row := range tracks {
		if row.AudioPath == track.AudioPath {
			return row.ID
		}
	}
	t.Fatalf("seeded track not found: %s", track.AudioPath)
	return 0
}

func strPtr(v string) *string {
	return &v
}
