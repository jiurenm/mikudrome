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

func TestTrackMetadataHTTP_BatchPatchUpdatesMultipleTracks(t *testing.T) {
	h := newTestHandler(t)

	firstID := seedMetadataTrack(t, h, store.Track{
		Title:     "Track 1",
		AudioPath: "/tmp/batch-1.flac",
	}, store.Album{Title: "Batch Album"}, store.Producer{Name: "batch producer"})
	secondID := seedMetadataTrack(t, h, store.Track{
		Title:     "Track 2",
		AudioPath: "/tmp/batch-2.flac",
	}, store.Album{Title: "Batch Album"}, store.Producer{Name: "batch producer"})

	body := `{"updates":[` +
		`{"track_id":` + strconv.FormatInt(firstID, 10) + `,"patch":{"composer":"ryo","lyricist":"ryo"}},` +
		`{"track_id":` + strconv.FormatInt(secondID, 10) + `,"patch":{"vocal":"Hatsune Miku"}}` +
		`]}`
	rr := doReq(h, http.MethodPatch, "/api/tracks/metadata", body)
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d: %s", rr.Code, http.StatusOK, rr.Body.String())
	}

	var resp struct {
		Tracks []struct {
			ID       int64  `json:"id"`
			Composer string `json:"composer"`
			Lyricist string `json:"lyricist"`
			Vocal    string `json:"vocal"`
		} `json:"tracks"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if len(resp.Tracks) != 2 {
		t.Fatalf("tracks = %d, want 2", len(resp.Tracks))
	}
	if resp.Tracks[0].ID != firstID || resp.Tracks[0].Composer != "ryo" || resp.Tracks[0].Lyricist != "ryo" {
		t.Fatalf("unexpected first track: %+v", resp.Tracks[0])
	}
	if resp.Tracks[1].ID != secondID || resp.Tracks[1].Vocal != "Hatsune Miku" {
		t.Fatalf("unexpected second track: %+v", resp.Tracks[1])
	}
}

func TestTrackMetadataHTTP_BatchPatchRejectsInvalidPayloads(t *testing.T) {
	h := newTestHandler(t)

	cases := []struct {
		name string
		body string
	}{
		{name: "empty updates", body: `{"updates":[]}`},
		{name: "non-positive id", body: `{"updates":[{"track_id":0,"patch":{"composer":"ryo"}}]}`},
		{name: "duplicate id", body: `{"updates":[{"track_id":1,"patch":{"composer":"ryo"}},{"track_id":1,"patch":{"lyricist":"ryo"}}]}`},
		{name: "empty patch", body: `{"updates":[{"track_id":1,"patch":{}}]}`},
		{name: "unknown field", body: `{"updates":[{"track_id":1,"patch":{"unknown":"ryo"}}]}`},
		{name: "trailing content", body: `{"updates":[{"track_id":1,"patch":{"composer":"ryo"}}]} {"unexpected":true}`},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			rr := doReq(h, http.MethodPatch, "/api/tracks/metadata", tc.body)
			if rr.Code != http.StatusBadRequest {
				t.Fatalf("status = %d, want %d: %s", rr.Code, http.StatusBadRequest, rr.Body.String())
			}
		})
	}
}

func TestTrackMetadataHTTP_BatchPatchRollsBackWhenTrackMissing(t *testing.T) {
	h := newTestHandler(t)

	id := seedMetadataTrack(t, h, store.Track{
		Title:     "Track",
		AudioPath: "/tmp/batch-rollback.flac",
	}, store.Album{Title: "Rollback Album"}, store.Producer{Name: "rollback producer"})

	body := `{"updates":[` +
		`{"track_id":` + strconv.FormatInt(id, 10) + `,"patch":{"composer":"changed"}},` +
		`{"track_id":999999,"patch":{"vocal":"Hatsune Miku"}}` +
		`]}`
	rr := doReq(h, http.MethodPatch, "/api/tracks/metadata", body)
	if rr.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d: %s", rr.Code, http.StatusNotFound, rr.Body.String())
	}

	row, ok, err := h.store.GetTrackMetadataByID(id)
	if err != nil || !ok {
		t.Fatalf("GetTrackMetadataByID ok=%v err=%v", ok, err)
	}
	if row.Composer != "" {
		t.Fatalf("composer = %q, want empty after rollback", row.Composer)
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
