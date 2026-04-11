package config

import (
	"os"
	"path/filepath"
)

// Config holds server configuration.
type Config struct {
	// MediaRoot is the root directory to scan for audio/video (local path or mount).
	MediaRoot string
	// DBPath is the path to the SQLite database file.
	DBPath string
	// HTTPAddr is the address to bind the API server (e.g. ":8080").
	HTTPAddr string
	// WebRoot is the directory for Flutter web build (static files). Empty disables static serving.
	WebRoot string
	// YtDlpProxy is the proxy URL for yt-dlp (e.g. "http://127.0.0.1:7890" or "socks5://127.0.0.1:1080").
	YtDlpProxy string
	// ScanWorkers is the number of concurrent workers for media scanning.
	ScanWorkers int
	// ScanBatchSize is the batch size for database operations during scanning.
	ScanBatchSize int
	// EnableWatcher enables automatic file system monitoring for changes.
	EnableWatcher bool
	// PlaylistCoverDir is the directory where user-uploaded playlist covers are stored.
	// Default: filepath.Join(filepath.Dir(DBPath), "playlist_covers").
	PlaylistCoverDir string
}

// Default returns a config with sensible defaults.
func Default() *Config {
	c := &Config{
		MediaRoot:     ".",
		DBPath:        "mikudrome.db",
		HTTPAddr:      ":8080",
		ScanWorkers:   4,
		ScanBatchSize: 100,
		EnableWatcher: true,
	}
	if wd, err := os.Getwd(); err == nil {
		c.MediaRoot = filepath.Join(wd, "media")
		c.WebRoot = filepath.Join(wd, "build", "web")
	}
	return c
}
