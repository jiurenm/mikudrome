package watcher

import (
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/fsnotify/fsnotify"
	"github.com/mikudrome/mikudrome/internal/scanner"
	"github.com/mikudrome/mikudrome/internal/store"
)

// Watcher monitors media directory for file changes and triggers incremental scans.
type Watcher struct {
	mediaRoot string
	store     *store.Store
	watcher   *fsnotify.Watcher
	workers   int
	batchSize int

	// Debouncing
	mu            sync.Mutex
	pendingEvents map[string]time.Time
	debounceTimer *time.Timer
}

// New creates a new file system watcher.
func New(mediaRoot string, store *store.Store, workers, batchSize int) (*Watcher, error) {
	fsWatcher, err := fsnotify.NewWatcher()
	if err != nil {
		return nil, err
	}

	w := &Watcher{
		mediaRoot:     mediaRoot,
		store:         store,
		watcher:       fsWatcher,
		workers:       workers,
		batchSize:     batchSize,
		pendingEvents: make(map[string]time.Time),
	}

	return w, nil
}

// Start begins watching the media directory.
func (w *Watcher) Start() error {
	// Add media root and all subdirectories to watch list
	if err := w.addRecursive(w.mediaRoot); err != nil {
		return err
	}

	log.Printf("watcher: monitoring %s for changes", w.mediaRoot)

	go w.eventLoop()
	return nil
}

// addRecursive adds a directory and all its subdirectories to the watcher.
func (w *Watcher) addRecursive(root string) error {
	return filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			if err := w.watcher.Add(path); err != nil {
				log.Printf("watcher: failed to watch %s: %v", path, err)
			}
		}
		return nil
	})
}

// eventLoop processes file system events.
func (w *Watcher) eventLoop() {
	for {
		select {
		case event, ok := <-w.watcher.Events:
			if !ok {
				return
			}
			w.handleEvent(event)

		case err, ok := <-w.watcher.Errors:
			if !ok {
				return
			}
			log.Printf("watcher: error: %v", err)
		}
	}
}

// handleEvent processes a single file system event.
func (w *Watcher) handleEvent(event fsnotify.Event) {
	// Check if it's an audio or video file
	ext := strings.ToLower(filepath.Ext(event.Name))
	if !scanner.AudioExts[ext] && !scanner.VideoExts[ext] {
		// If it's a directory creation, add it to watch list
		if event.Op&fsnotify.Create == fsnotify.Create {
			if info, err := os.Stat(event.Name); err == nil && info.IsDir() {
				w.watcher.Add(event.Name)
				log.Printf("watcher: now watching new directory: %s", event.Name)
			}
		}
		return
	}

	// Debounce: collect events and trigger scan after quiet period
	w.mu.Lock()
	defer w.mu.Unlock()

	w.pendingEvents[event.Name] = time.Now()

	// Reset debounce timer
	if w.debounceTimer != nil {
		w.debounceTimer.Stop()
	}

	w.debounceTimer = time.AfterFunc(2*time.Second, func() {
		w.triggerScan()
	})

	log.Printf("watcher: detected change: %s (%s)", event.Name, event.Op)
}

// triggerScan performs an incremental scan.
func (w *Watcher) triggerScan() {
	w.mu.Lock()
	eventCount := len(w.pendingEvents)
	w.pendingEvents = make(map[string]time.Time)
	w.mu.Unlock()

	if eventCount == 0 {
		return
	}

	log.Printf("watcher: triggering incremental scan (%d events)", eventCount)

	if err := scanner.Scan(w.mediaRoot, w.store, w.workers, w.batchSize); err != nil {
		log.Printf("watcher: scan error: %v", err)
	}
}

// Close stops the watcher.
func (w *Watcher) Close() error {
	if w.debounceTimer != nil {
		w.debounceTimer.Stop()
	}
	return w.watcher.Close()
}
