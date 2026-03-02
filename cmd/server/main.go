package main

import (
	"log"
	"net/http"
	"os"

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

	st, err := store.New(cfg.DBPath)
	if err != nil {
		log.Fatal("store:", err)
	}
	defer st.Close()

	if err := scanner.Scan(cfg.MediaRoot, st); err != nil {
		log.Printf("scan warning: %v", err)
	}

	handler := api.New(st, cfg.MediaRoot, cfg.WebRoot)
	log.Printf("listening on %s", cfg.HTTPAddr)
	if err := http.ListenAndServe(cfg.HTTPAddr, handler); err != nil {
		log.Fatal(err)
	}
}
