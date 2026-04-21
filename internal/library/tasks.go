package library

import (
	"sync"
	"time"

	"github.com/mikudrome/mikudrome/internal/scanner"
	"github.com/mikudrome/mikudrome/internal/store"
)

const TaskTypeFullRescan = "full_rescan"

type TaskStatus string

const (
	StatusIdle      TaskStatus = "idle"
	StatusRunning   TaskStatus = "running"
	StatusCompleted TaskStatus = "completed"
	StatusFailed    TaskStatus = "failed"
)

type Status struct {
	TaskType       string     `json:"task_type"`
	Status         TaskStatus `json:"status"`
	StartedAt      int64      `json:"started_at"`
	FinishedAt     int64      `json:"finished_at"`
	TotalFiles     int        `json:"total_files"`
	ProcessedFiles int        `json:"processed_files"`
	UpdatedFiles   int        `json:"updated_files"`
	SkippedFiles   int        `json:"skipped_files"`
	DeletedFiles   int        `json:"deleted_files"`
	FailedFiles    int        `json:"failed_files"`
	LastError      string     `json:"last_error"`
}

type TaskManager struct {
	mu                  sync.Mutex
	status              Status
	running             bool
	runGate             chan struct{}
	scan                func(scanner.ScanOptions) error
	completionCallbacks []func(Status)
}

func NewTaskManager(mediaRoot string, st *store.Store, workers, batchSize int) *TaskManager {
	manager := &TaskManager{
		status: Status{
			TaskType: TaskTypeFullRescan,
			Status:   StatusIdle,
		},
		runGate: make(chan struct{}, 1),
		scan: func(opts scanner.ScanOptions) error {
			return scanner.ScanWithOptions(mediaRoot, st, workers, batchSize, scanner.ScanOptions{
				Force:      true,
				OnProgress: opts.OnProgress,
			})
		},
	}
	manager.runGate <- struct{}{}
	return manager
}

func (m *TaskManager) StartFullRescan() (Status, bool) {
	m.mu.Lock()
	if m.running {
		status := m.status
		m.mu.Unlock()
		return status, false
	}
	m.running = true
	m.status = Status{
		TaskType:  TaskTypeFullRescan,
		Status:    StatusRunning,
		StartedAt: time.Now().Unix(),
	}
	status := m.status
	m.mu.Unlock()

	<-m.runGate

	go m.run()

	return status, true
}

func (m *TaskManager) GetStatus() Status {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.status
}

func (m *TaskManager) IsRunning() bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.running
}

func (m *TaskManager) SetScanFunc(scan func(scanner.ScanOptions) error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.scan = scan
}

func (m *TaskManager) AddCompletionCallback(callback func(Status)) {
	if callback == nil {
		return
	}

	m.mu.Lock()
	defer m.mu.Unlock()
	m.completionCallbacks = append(m.completionCallbacks, callback)
}

func (m *TaskManager) RunWhenIdle(fn func()) {
	if m == nil {
		if fn != nil {
			fn()
		}
		return
	}

	<-m.runGate
	defer func() {
		m.runGate <- struct{}{}
	}()

	if fn != nil {
		fn()
	}
}

func (m *TaskManager) run() {
	defer func() {
		m.runGate <- struct{}{}
	}()

	scan := m.getScanFunc()
	err := scan(scanner.ScanOptions{
		Force: true,
		OnProgress: func(progress scanner.ScanProgress) {
			m.mu.Lock()
			m.status.TotalFiles = progress.TotalFiles
			m.status.ProcessedFiles = progress.ProcessedFiles
			m.status.UpdatedFiles = progress.UpdatedFiles
			m.status.SkippedFiles = progress.SkippedFiles
			m.status.DeletedFiles = progress.DeletedFiles
			m.status.FailedFiles = progress.FailedFiles
			m.mu.Unlock()
		},
	})

	m.mu.Lock()
	m.running = false
	m.status.FinishedAt = time.Now().Unix()
	if err != nil {
		m.status.Status = StatusFailed
		m.status.LastError = err.Error()
	} else {
		m.status.Status = StatusCompleted
		m.status.LastError = ""
	}
	status := m.status
	callbacks := append([]func(Status){}, m.completionCallbacks...)
	m.mu.Unlock()

	for _, callback := range callbacks {
		callback(status)
	}
}

func (m *TaskManager) getScanFunc() func(scanner.ScanOptions) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.scan == nil {
		return func(scanner.ScanOptions) error { return nil }
	}
	return m.scan
}
