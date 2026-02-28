package store

import (
	"database/sql"
	"fmt"
	"strings"

	_ "modernc.org/sqlite"
)

// Album represents an album (artist/album folder under media root).
type Album struct {
	ID         int64  `json:"id"`
	Artist     string `json:"artist"`
	Title      string `json:"title"`
	CoverPath  string `json:"cover_path"`
	TrackCount int    `json:"track_count"`
}

// Track represents a single track with audio and optional video path.
type Track struct {
	ID              int64  `json:"id"`
	Title           string `json:"title"`
	AudioPath       string `json:"audio_path"`
	VideoPath       string `json:"video_path"`
	AlbumID         int64  `json:"album_id,omitempty"`
	TrackNumber     int    `json:"track_number"`
	Producer        string `json:"producer"` // P主
	Vocal           string `json:"vocal"`    // 歌い手 / vocal
	Year            int    `json:"year"`    // 年份
	DurationSeconds int    `json:"duration_seconds"` // 时长（秒）
	Format          string `json:"format"`           // 码率/格式，如 "24bit FLAC"
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
	// WAL mode reduces locking so the db file is less often "busy or locked" when copying.
	if _, err := db.Exec(`PRAGMA journal_mode=WAL`); err != nil {
		db.Close()
		return nil, fmt.Errorf("enable WAL: %w", err)
	}
	if err := migrate(db); err != nil {
		db.Close()
		return nil, err
	}
	return &Store{db: db}, nil
}

func migrate(db *sql.DB) error {
	_, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS albums (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			dir_path TEXT NOT NULL UNIQUE,
			artist TEXT NOT NULL DEFAULT '',
			title TEXT NOT NULL,
			cover_path TEXT NOT NULL DEFAULT ''
		);
		CREATE INDEX IF NOT EXISTS idx_albums_dir ON albums(dir_path);

		CREATE TABLE IF NOT EXISTS tracks (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			title TEXT NOT NULL,
			audio_path TEXT NOT NULL UNIQUE,
			video_path TEXT NOT NULL DEFAULT '',
			album_id INTEGER REFERENCES albums(id),
			track_number INTEGER NOT NULL DEFAULT 0,
			producer TEXT NOT NULL DEFAULT '',
			vocal TEXT NOT NULL DEFAULT '',
			year INTEGER NOT NULL DEFAULT 0,
			duration_seconds INTEGER NOT NULL DEFAULT 0,
			format TEXT NOT NULL DEFAULT ''
		);
		CREATE INDEX IF NOT EXISTS idx_tracks_audio ON tracks(audio_path);
		CREATE INDEX IF NOT EXISTS idx_tracks_album ON tracks(album_id);
	`)
	return err
}

// UpsertAlbum inserts or updates an album by dir_path. Returns album ID (always by querying, so INSERT vs UPDATE is consistent).
func (s *Store) UpsertAlbum(dirPath, artist, title, coverPath string) (int64, error) {
	_, err := s.db.Exec(
		`INSERT INTO albums (dir_path, artist, title, cover_path) VALUES (?, ?, ?, ?)
		 ON CONFLICT(dir_path) DO UPDATE SET artist=excluded.artist, title=excluded.title, cover_path=excluded.cover_path`,
		dirPath, artist, title, coverPath,
	)
	if err != nil {
		return 0, err
	}
	var id int64
	err = s.db.QueryRow(`SELECT id FROM albums WHERE dir_path = ?`, dirPath).Scan(&id)
	return id, err
}

// UpdateAlbumCover sets the cover path for an album (e.g. after extracting from track).
func (s *Store) UpdateAlbumCover(albumID int64, coverPath string) error {
	_, err := s.db.Exec(`UPDATE albums SET cover_path = ? WHERE id = ?`, coverPath, albumID)
	return err
}

// UpsertTrack inserts or updates a track by audio_path.
func (s *Store) UpsertTrack(title, audioPath, videoPath string, albumID int64, trackNumber int, producer, vocal string, year, durationSeconds int, format string) error {
	_, err := s.db.Exec(
		`INSERT INTO tracks (title, audio_path, video_path, album_id, track_number, producer, vocal, year, duration_seconds, format) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		 ON CONFLICT(audio_path) DO UPDATE SET title=excluded.title, video_path=excluded.video_path, album_id=excluded.album_id, track_number=excluded.track_number, producer=excluded.producer, vocal=excluded.vocal, year=excluded.year, duration_seconds=excluded.duration_seconds, format=excluded.format`,
		title, audioPath, videoPath, albumID, trackNumber, producer, vocal, year, durationSeconds, format,
	)
	return err
}

// ListAlbums returns all albums ordered by artist, title.
func (s *Store) ListAlbums() ([]Album, error) {
	rows, err := s.db.Query(`
		SELECT a.id, a.artist, a.title, a.cover_path, COUNT(t.id) AS track_count
		FROM albums a
		LEFT JOIN tracks t ON t.album_id = a.id
		GROUP BY a.id
		ORDER BY a.artist, a.title
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Album
	for rows.Next() {
		var a Album
		if err := rows.Scan(&a.ID, &a.Artist, &a.Title, &a.CoverPath, &a.TrackCount); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// GetAlbumByID returns an album by id.
func (s *Store) GetAlbumByID(id int64) (Album, bool, error) {
	var a Album
	err := s.db.QueryRow(`
		SELECT a.id, a.artist, a.title, a.cover_path, COUNT(t.id)
		FROM albums a
		LEFT JOIN tracks t ON t.album_id = a.id
		WHERE a.id = ?
		GROUP BY a.id
	`, id).Scan(&a.ID, &a.Artist, &a.Title, &a.CoverPath, &a.TrackCount)
	if err == sql.ErrNoRows {
		return Album{}, false, nil
	}
	if err != nil {
		return Album{}, false, err
	}
	return a, true, nil
}

// GetTracksByAlbumID returns tracks for an album, ordered by track_number then title.
func (s *Store) GetTracksByAlbumID(albumID int64) ([]Track, error) {
	rows, err := s.db.Query(
		`SELECT id, title, audio_path, video_path, COALESCE(album_id, 0), COALESCE(track_number, 0), COALESCE(producer, ''), COALESCE(vocal, ''), COALESCE(year, 0), COALESCE(duration_seconds, 0), COALESCE(format, '') FROM tracks WHERE album_id = ? ORDER BY track_number, title`,
		albumID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Track
	for rows.Next() {
		var t Track
		if err := rows.Scan(&t.ID, &t.Title, &t.AudioPath, &t.VideoPath, &t.AlbumID, &t.TrackNumber, &t.Producer, &t.Vocal, &t.Year, &t.DurationSeconds, &t.Format); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// ListTracks returns all tracks ordered by title.
func (s *Store) ListTracks() ([]Track, error) {
	rows, err := s.db.Query(`SELECT id, title, audio_path, video_path, COALESCE(album_id, 0), COALESCE(track_number, 0), COALESCE(producer, ''), COALESCE(vocal, ''), COALESCE(year, 0), COALESCE(duration_seconds, 0), COALESCE(format, '') FROM tracks ORDER BY title`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Track
	for rows.Next() {
		var t Track
		if err := rows.Scan(&t.ID, &t.Title, &t.AudioPath, &t.VideoPath, &t.AlbumID, &t.TrackNumber, &t.Producer, &t.Vocal, &t.Year, &t.DurationSeconds, &t.Format); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// GetTrackByID returns a track by id.
func (s *Store) GetTrackByID(id int64) (Track, bool, error) {
	var t Track
	err := s.db.QueryRow(
		`SELECT id, title, audio_path, video_path, COALESCE(album_id, 0), COALESCE(track_number, 0), COALESCE(producer, ''), COALESCE(vocal, ''), COALESCE(year, 0), COALESCE(duration_seconds, 0), COALESCE(format, '') FROM tracks WHERE id = ?`,
		id,
	).Scan(&t.ID, &t.Title, &t.AudioPath, &t.VideoPath, &t.AlbumID, &t.TrackNumber, &t.Producer, &t.Vocal, &t.Year, &t.DurationSeconds, &t.Format)
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

// BackupTo writes a consistent snapshot of the database to destPath (e.g. temp file).
// Safe to call while the DB is in use. Uses VACUUM INTO (SQLite 3.27+).
func (s *Store) BackupTo(destPath string) error {
	// VACUUM INTO requires a literal path; escape single quotes.
	escaped := strings.ReplaceAll(destPath, "'", "''")
	_, err := s.db.Exec(`VACUUM INTO '` + escaped + `'`)
	return err
}
