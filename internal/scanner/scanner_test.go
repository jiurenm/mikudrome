package scanner

import (
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/dhowden/tag"
)

func TestProcessFileUsesWAVTagAliases(t *testing.T) {
	tmpDir := t.TempDir()
	restoreSeams := stubScannerSeams()
	defer restoreSeams()

	audioDir := filepath.Join(tmpDir, "artist-folder", "random-album-dir")
	if err := os.MkdirAll(audioDir, 0o755); err != nil {
		t.Fatalf("mkdir audio dir: %v", err)
	}
	audioPath := filepath.Join(audioDir, "world-is-mine.wav")
	if err := os.WriteFile(audioPath, []byte("not a real wav"), 0o644); err != nil {
		t.Fatalf("write audio file: %v", err)
	}
	videoPath := filepath.Join(audioDir, "world-is-mine.mp4")
	if err := os.WriteFile(videoPath, []byte("not a real mp4"), 0o644); err != nil {
		t.Fatalf("write video file: %v", err)
	}

	ffprobeRunner = func(path string) (int, string, map[string]string) {
		if path != audioPath {
			t.Fatalf("ffprobe path = %q, want %q", path, audioPath)
		}
		return 215, "24bit PCM_S24LE", map[string]string{
			"INAM":   "World Is Mine",
			"IART":   "ryo",
			"IPRD":   "supercell",
			"TPE2":   "supercell",
			"ITRK":   "7/12",
			"IPRT":   "2/2",
			"ICRD":   "2009",
			"LYRICS": "君は王女",
		}
	}
	metadataReader = func(path string) (tag.Metadata, error) {
		t.Fatalf("metadataReader should not be called, got %q", path)
		return nil, errors.New("unexpected metadata read")
	}
	videoThumbFinder = func(path string) string {
		if path != videoPath {
			t.Fatalf("video thumb path = %q, want %q", path, videoPath)
		}
		return filepath.Join(audioDir, "world-is-mine.jpg")
	}

	result := processFile(scanJob{audioPath: audioPath}, tmpDir)

	if result.track.Title != "World Is Mine" {
		t.Fatalf("title = %q, want %q", result.track.Title, "World Is Mine")
	}
	if result.track.Artists != "ryo" {
		t.Fatalf("artists = %q, want %q", result.track.Artists, "ryo")
	}
	if result.album.Title != "supercell" {
		t.Fatalf("album title = %q, want %q", result.album.Title, "supercell")
	}
	if result.album.AlbumArtist != "supercell" {
		t.Fatalf("album artist = %q, want %q", result.album.AlbumArtist, "supercell")
	}
	if result.track.TrackNumber != 7 {
		t.Fatalf("track number = %d, want %d", result.track.TrackNumber, 7)
	}
	if result.track.DiscNumber != 2 {
		t.Fatalf("disc number = %d, want %d", result.track.DiscNumber, 2)
	}
	if result.track.Year != 2009 {
		t.Fatalf("year = %d, want %d", result.track.Year, 2009)
	}
	if result.track.DurationSeconds != 215 {
		t.Fatalf("duration = %d, want %d", result.track.DurationSeconds, 215)
	}
	if result.track.Format != "24bit PCM_S24LE" {
		t.Fatalf("format = %q, want %q", result.track.Format, "24bit PCM_S24LE")
	}
	if result.track.Lyrics != "君は王女" {
		t.Fatalf("lyrics = %q, want %q", result.track.Lyrics, "君は王女")
	}
	if result.track.VideoThumbPath != filepath.Join(audioDir, "world-is-mine.jpg") {
		t.Fatalf("video thumb path = %q, want %q", result.track.VideoThumbPath, filepath.Join(audioDir, "world-is-mine.jpg"))
	}
}

func stubScannerSeams() func() {
	origFFprobeRunner := ffprobeRunner
	origMetadataReader := metadataReader
	origVideoThumbFinder := videoThumbFinder
	return func() {
		ffprobeRunner = origFFprobeRunner
		metadataReader = origMetadataReader
		videoThumbFinder = origVideoThumbFinder
	}
}
