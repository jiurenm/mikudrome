package library

import (
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/mikudrome/mikudrome/internal/scanner"
)

func TestTaskManagerStartFullRescanReportsRunningAndCompletion(t *testing.T) {
	manager := NewTaskManager("/tmp/media", nil, 1, 10)

	progressSeen := make(chan struct{}, 1)
	manager.SetScanFunc(func(opts scanner.ScanOptions) error {
		if opts.OnProgress == nil {
			t.Fatal("expected OnProgress to be set")
		}
		opts.OnProgress(scanner.ScanProgress{
			Phase:          "processing",
			TotalFiles:     2,
			ProcessedFiles: 1,
			NewFiles:       1,
			UpdatedFiles:   1,
		})
		progressSeen <- struct{}{}
		return nil
	})

	status, started := manager.StartFullRescan()
	if !started {
		t.Fatal("expected first rescan start to succeed")
	}
	if status.Status != StatusRunning {
		t.Fatalf("status = %q, want %q", status.Status, StatusRunning)
	}

	completed := waitForTaskState(t, manager, StatusCompleted)
	select {
	case <-progressSeen:
	default:
		t.Fatal("expected scan progress callback to be invoked")
	}
	if completed.TaskType != "full_rescan" {
		t.Fatalf("task type = %q, want %q", completed.TaskType, "full_rescan")
	}
	if completed.TotalFiles != 2 {
		t.Fatalf("total files = %d, want %d", completed.TotalFiles, 2)
	}
	if completed.ProcessedFiles != 1 {
		t.Fatalf("processed files = %d, want %d", completed.ProcessedFiles, 1)
	}
	if completed.LastError != "" {
		t.Fatalf("last error = %q, want empty", completed.LastError)
	}
}

func TestTaskManagerStartFullRescanIsSingleFlightAndReportsFailure(t *testing.T) {
	manager := NewTaskManager("/tmp/media", nil, 1, 10)

	release := make(chan struct{})
	startedScan := make(chan struct{}, 1)
	manager.SetScanFunc(func(opts scanner.ScanOptions) error {
		startedScan <- struct{}{}
		<-release
		return errors.New("scan failed")
	})

	first, started := manager.StartFullRescan()
	if !started {
		t.Fatal("expected first rescan start to succeed")
	}
	if first.Status != StatusRunning {
		t.Fatalf("first status = %q, want %q", first.Status, StatusRunning)
	}

	select {
	case <-startedScan:
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for scan to start")
	}

	second, startedAgain := manager.StartFullRescan()
	if startedAgain {
		t.Fatal("expected second rescan start to be rejected while running")
	}
	if second.Status != StatusRunning {
		t.Fatalf("second status = %q, want %q", second.Status, StatusRunning)
	}

	close(release)

	failed := waitForTaskState(t, manager, StatusFailed)
	if failed.LastError != "scan failed" {
		t.Fatalf("last error = %q, want %q", failed.LastError, "scan failed")
	}
}

func TestTaskManagerConcurrentStartFullRescanStaysSingleFlight(t *testing.T) {
	manager := NewTaskManager("/tmp/media", nil, 1, 10)

	release := make(chan struct{})
	startedScan := make(chan struct{}, 1)
	manager.SetScanFunc(func(scanner.ScanOptions) error {
		startedScan <- struct{}{}
		<-release
		return nil
	})

	type result struct {
		status  Status
		started bool
	}

	results := make(chan result, 2)
	var wg sync.WaitGroup
	wg.Add(2)
	for range 2 {
		go func() {
			defer wg.Done()
			status, started := manager.StartFullRescan()
			results <- result{status: status, started: started}
		}()
	}
	wg.Wait()
	close(results)

	startCount := 0
	for result := range results {
		if result.started {
			startCount++
		}
		if result.status.Status != StatusRunning {
			t.Fatalf("status = %q, want %q", result.status.Status, StatusRunning)
		}
	}
	if startCount != 1 {
		t.Fatalf("started count = %d, want %d", startCount, 1)
	}

	select {
	case <-startedScan:
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for scan to start")
	}

	close(release)
	waitForTaskState(t, manager, StatusCompleted)
}

func waitForTaskState(t *testing.T, manager *TaskManager, want TaskStatus) Status {
	t.Helper()

	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		status := manager.GetStatus()
		if status.Status == want {
			return status
		}
		time.Sleep(10 * time.Millisecond)
	}

	t.Fatalf("timed out waiting for status %q; last status = %#v", want, manager.GetStatus())
	return Status{}
}
