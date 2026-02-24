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
	}
	return c
}
