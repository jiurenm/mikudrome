package watcher

import (
	"testing"
	"time"

	"github.com/mikudrome/mikudrome/internal/library"
	"github.com/mikudrome/mikudrome/internal/scanner"
	"github.com/mikudrome/mikudrome/internal/store"
)

func TestTriggerScanQueuesFollowupUntilFullRescanCompletes(t *testing.T) {
	manager := library.NewTaskManager("/tmp/media", nil, 1, 10)
	release := make(chan struct{})
	manager.SetScanFunc(func(scanner.ScanOptions) error {
		<-release
		return nil
	})

	if _, started := manager.StartFullRescan(); !started {
		t.Fatal("expected full rescan to start")
	}

	scanCalls := make(chan struct{}, 1)
	w := &Watcher{
		mediaRoot:      "/tmp/media",
		workers:        1,
		batchSize:      10,
		libraryTasks:   manager,
		pendingEvents:  map[string]time.Time{"/tmp/media/track.flac": time.Now()},
		scanRunner: func(string, *store.Store, int, int) error {
			scanCalls <- struct{}{}
			return nil
		},
	}

	w.triggerScan()

	select {
	case <-scanCalls:
		t.Fatal("incremental scan should not run while full rescan is active")
	case <-time.After(250 * time.Millisecond):
	}

	close(release)

	select {
	case <-scanCalls:
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for queued incremental scan")
	}
}
