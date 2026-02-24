package store

import (
	"database/sql"
	"fmt"

	_ "modernc.org/sqlite"
)

// Track represents a single track with audio and optional video path.
type Track struct {
	ID        int64  `json:"id"`
	Title     string `json:"title"`
	AudioPath string `json:"audio_path"`
	VideoPath string `json:"video_path"`
}

// Store provides SQLite persistence for tracks.
type Store struct {
	db *sql.DB
}

// New opens the database at path and runs migrations.
func New(path string) (*Store, error) {
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, fmt.Errorf("open db: %w", err)
	}
	if err := migrate(db); err != nil {
		db.Close()
		return nil, err
	}
	return &Store{db: db}, nil
}

func migrate(db *sql.DB) error {
	_, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS tracks (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			title TEXT NOT NULL,
			audio_path TEXT NOT NULL UNIQUE,
			video_path TEXT NOT NULL DEFAULT ''
		);
		CREATE INDEX IF NOT EXISTS idx_tracks_audio ON tracks(audio_path);
	`)
	return err
}

// UpsertTrack inserts or updates a track by audio_path.
func (s *Store) UpsertTrack(title, audioPath, videoPath string) error {
	_, err := s.db.Exec(
		`INSERT INTO tracks (title, audio_path, video_path) VALUES (?, ?, ?)
		 ON CONFLICT(audio_path) DO UPDATE SET title=excluded.title, video_path=excluded.video_path`,
		title, audioPath, videoPath,
	)
	return err
}

// ListTracks returns all tracks ordered by title.
func (s *Store) ListTracks() ([]Track, error) {
	rows, err := s.db.Query(`SELECT id, title, audio_path, video_path FROM tracks ORDER BY title`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Track
	for rows.Next() {
		var t Track
		if err := rows.Scan(&t.ID, &t.Title, &t.AudioPath, &t.VideoPath); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// GetTrackByID returns a track by id.
func (s *Store) GetTrackByID(id int64) (Track, bool, error) {
	var t Track
	err := s.db.QueryRow(`SELECT id, title, audio_path, video_path FROM tracks WHERE id = ?`, id).
		Scan(&t.ID, &t.Title, &t.AudioPath, &t.VideoPath)
	if err == sql.ErrNoRows {
		return Track{}, false, nil
	}
	if err != nil {
		return Track{}, false, err
	}
	return t, true, nil
}

// Close closes the database.
func (s *Store) Close() error {
	return s.db.Close()
}
