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
}

// Default returns a config with sensible defaults.
func Default() *Config {
	c := &Config{
		MediaRoot: ".",
		DBPath:    "mikudrome.db",
		HTTPAddr:  ":8080",
	}
	if wd, err := os.Getwd(); err == nil {
		c.MediaRoot = filepath.Join(wd, "media")
		c.WebRoot = filepath.Join(wd, "build", "web")
	}
	return c
}
