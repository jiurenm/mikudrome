package main

import (
	"log"
	"net/http"
	"os"
	"strconv"

	"github.com/mikudrome/mikudrome/internal/config"
	"github.com/mikudrome/mikudrome/internal/scanner"
	"github.com/mikudrome/mikudrome/internal/store"
	"github.com/mikudrome/mikudrome/internal/api"
)

func main() {
	cfg := config.Default()
	if r := os.Getenv("MEDIA_ROOT"); r != "" {
		cfg.MediaRoot = r
	}
	if d := os.Getenv("DB_PATH"); d != "" {
		cfg.DBPath = d
	}
	if a := os.Getenv("HTTP_ADDR"); a != "" {
		cfg.HTTPAddr = a
	}
	if w := os.Getenv("WEB_ROOT"); w != "" {
		cfg.WebRoot = w
	}
	if p := os.Getenv("YTDLP_PROXY"); p != "" {
		cfg.YtDlpProxy = p
	}
	if w := os.Getenv("SCAN_WORKERS"); w != "" {
		if n, err := strconv.Atoi(w); err == nil && n > 0 {
			cfg.ScanWorkers = n
		}
	}
	if b := os.Getenv("SCAN_BATCH_SIZE"); b != "" {
		if n, err := strconv.Atoi(b); err == nil && n > 0 {
			cfg.ScanBatchSize = n
		}
	}

	st, err := store.New(cfg.DBPath)
	if err != nil {
		log.Fatal("store:", err)
	}
	defer st.Close()

	// Start media scanning in background
	go func() {
		log.Println("starting background media scan...")
		if err := scanner.Scan(cfg.MediaRoot, st, cfg.ScanWorkers, cfg.ScanBatchSize); err != nil {
			log.Printf("scan warning: %v", err)
		}
	}()

	handler := api.New(st, cfg.MediaRoot, cfg.WebRoot, cfg.YtDlpProxy)
	log.Printf("listening on %s", cfg.HTTPAddr)
	if err := http.ListenAndServe(cfg.HTTPAddr, handler); err != nil {
		log.Fatal(err)
	}
}
