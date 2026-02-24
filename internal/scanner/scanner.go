package scanner

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/mikudrome/mikudrome/internal/store"
)

// AudioExts lists supported audio extensions (lowercase).
var AudioExts = map[string]bool{
	".flac": true, ".mp3": true, ".m4a": true, ".ogg": true, ".wav": true,
}

// VideoExts lists supported video extensions for MV matching (lowercase).
var VideoExts = map[string]bool{
	".mp4": true, ".mkv": true, ".webm": true, ".avi": true,
}

// Scan walks mediaRoot, finds audio files, and for each audio looks for
// a same-named video in the same directory. It upserts into the store.
func Scan(mediaRoot string, s *store.Store) error {
	audioPaths := make(map[string]string) // base name (no ext) -> full path
	err := filepath.Walk(mediaRoot, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}
		ext := strings.ToLower(filepath.Ext(path))
		if AudioExts[ext] {
			base := strings.TrimSuffix(path, ext)
			audioPaths[base] = path
		}
		return nil
	})
	if err != nil {
		return err
	}

	for base, audioPath := range audioPaths {
		dir := filepath.Dir(audioPath)
		title := filepath.Base(base)
		videoPath := findVideoForBase(dir, base)
		if err := s.UpsertTrack(title, audioPath, videoPath); err != nil {
			return err
		}
	}
	return nil
}

// findVideoForBase looks in dir for a file with same base name and a video extension.
func findVideoForBase(dir, base string) string {
	baseName := filepath.Base(base)
	for ext := range VideoExts {
		candidate := filepath.Join(dir, baseName+ext)
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
	}
	return ""
}
