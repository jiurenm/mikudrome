package store

import (
	"database/sql"
	"fmt"
	"strings"

	_ "modernc.org/sqlite"
)

// Producer aggregates track producer (P主) with track and album counts.
type Producer struct {
	ID         int64  `json:"id"`
	Name       string `json:"name"`
	TrackCount int    `json:"track_count"`
	AlbumCount int    `json:"album_count"`
	AvatarPath string `json:"avatar_path,omitempty"` // artist.jpg in P主 folder
}

// Album represents an album (artist/album folder under media root).
type Album struct {
	ID         int64  `json:"id"`
	Artist     string `json:"artist"`
	Title      string `json:"title"`
	CoverPath  string `json:"cover_path"`
	TrackCount int    `json:"track_count"`
	ProducerID int64  `json:"producer_id,omitempty"`
}

// Track represents a single track with audio and optional video path.
type Track struct {
	ID              int64  `json:"id"`
	Title           string `json:"title"`
	AudioPath       string `json:"audio_path"`
	VideoPath       string `json:"video_path"`
	VideoThumbPath  string `json:"video_thumb_path"` // MV thumbnail (same name as video, or ffmpeg-generated)
	AlbumID         int64  `json:"album_id,omitempty"`
	TrackNumber     int    `json:"track_number"`
	ProducerID      int64  `json:"producer_id,omitempty"`
	Producer        string `json:"producer"` // P主 name (denormalized for display)
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
		CREATE TABLE IF NOT EXISTS producers (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL UNIQUE,
			avatar_path TEXT NOT NULL DEFAULT ''
		);
		CREATE INDEX IF NOT EXISTS idx_producers_name ON producers(name);

		CREATE TABLE IF NOT EXISTS albums (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			dir_path TEXT NOT NULL UNIQUE,
			artist TEXT NOT NULL DEFAULT '',
			title TEXT NOT NULL,
			cover_path TEXT NOT NULL DEFAULT '',
			producer_id INTEGER REFERENCES producers(id)
		);
		CREATE INDEX IF NOT EXISTS idx_albums_dir ON albums(dir_path);
		CREATE INDEX IF NOT EXISTS idx_albums_producer ON albums(producer_id);

		CREATE TABLE IF NOT EXISTS tracks (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			title TEXT NOT NULL,
			audio_path TEXT NOT NULL UNIQUE,
			video_path TEXT NOT NULL DEFAULT '',
			video_thumb_path TEXT NOT NULL DEFAULT '',
			album_id INTEGER REFERENCES albums(id),
			track_number INTEGER NOT NULL DEFAULT 0,
			producer_id INTEGER REFERENCES producers(id),
			producer TEXT NOT NULL DEFAULT '',
			vocal TEXT NOT NULL DEFAULT '',
			year INTEGER NOT NULL DEFAULT 0,
			duration_seconds INTEGER NOT NULL DEFAULT 0,
			format TEXT NOT NULL DEFAULT ''
		);
		CREATE INDEX IF NOT EXISTS idx_tracks_audio ON tracks(audio_path);
		CREATE INDEX IF NOT EXISTS idx_tracks_album ON tracks(album_id);
		CREATE INDEX IF NOT EXISTS idx_tracks_producer ON tracks(producer_id);
	`)
	return err
}

// UpsertProducer inserts or updates a producer by name. Returns producer ID.
func (s *Store) UpsertProducer(name, avatarPath string) (int64, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return 0, nil
	}
	_, err := s.db.Exec(
		`INSERT INTO producers (name, avatar_path) VALUES (?, ?)
		 ON CONFLICT(name) DO UPDATE SET avatar_path=excluded.avatar_path`,
		name, avatarPath,
	)
	if err != nil {
		return 0, err
	}
	var id int64
	err = s.db.QueryRow(`SELECT id FROM producers WHERE name = ?`, name).Scan(&id)
	return id, err
}

// UpsertAlbum inserts or updates an album by dir_path. Returns album ID (always by querying, so INSERT vs UPDATE is consistent).
func (s *Store) UpsertAlbum(dirPath, artist, title, coverPath string, producerID int64) (int64, error) {
	_, err := s.db.Exec(
		`INSERT INTO albums (dir_path, artist, title, cover_path, producer_id) VALUES (?, ?, ?, ?, ?)
		 ON CONFLICT(dir_path) DO UPDATE SET artist=excluded.artist, title=excluded.title, cover_path=excluded.cover_path, producer_id=excluded.producer_id`,
		dirPath, artist, title, coverPath, producerID,
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
func (s *Store) UpsertTrack(title, audioPath, videoPath, videoThumbPath string, albumID, producerID int64, trackNumber int, producer, vocal string, year, durationSeconds int, format string) error {
	_, err := s.db.Exec(
		`INSERT INTO tracks (title, audio_path, video_path, video_thumb_path, album_id, track_number, producer_id, producer, vocal, year, duration_seconds, format) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		 ON CONFLICT(audio_path) DO UPDATE SET title=excluded.title, video_path=excluded.video_path, video_thumb_path=excluded.video_thumb_path, album_id=excluded.album_id, track_number=excluded.track_number, producer_id=excluded.producer_id, producer=excluded.producer, vocal=excluded.vocal, year=excluded.year, duration_seconds=excluded.duration_seconds, format=excluded.format`,
		title, audioPath, videoPath, videoThumbPath, albumID, trackNumber, producerID, producer, vocal, year, durationSeconds, format,
	)
	return err
}

// UpdateTrackVideo sets video_path and video_thumb_path for a track by id (e.g. after downloading MV via yt-dlp).
func (s *Store) UpdateTrackVideo(trackID int64, videoPath, videoThumbPath string) error {
	_, err := s.db.Exec(
		`UPDATE tracks SET video_path = ?, video_thumb_path = ? WHERE id = ?`,
		videoPath, videoThumbPath, trackID,
	)
	return err
}

// ListAlbums returns all albums ordered by artist, title.
func (s *Store) ListAlbums() ([]Album, error) {
	rows, err := s.db.Query(`
		SELECT a.id, a.artist, a.title, a.cover_path, COUNT(t.id) AS track_count, COALESCE(a.producer_id, 0)
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
		if err := rows.Scan(&a.ID, &a.Artist, &a.Title, &a.CoverPath, &a.TrackCount, &a.ProducerID); err != nil {
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
		SELECT a.id, a.artist, a.title, a.cover_path, COUNT(t.id), COALESCE(a.producer_id, 0)
		FROM albums a
		LEFT JOIN tracks t ON t.album_id = a.id
		WHERE a.id = ?
		GROUP BY a.id
	`, id).Scan(&a.ID, &a.Artist, &a.Title, &a.CoverPath, &a.TrackCount, &a.ProducerID)
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
		`SELECT id, title, audio_path, video_path, COALESCE(video_thumb_path, ''), COALESCE(album_id, 0), COALESCE(track_number, 0), COALESCE(producer_id, 0), COALESCE(producer, ''), COALESCE(vocal, ''), COALESCE(year, 0), COALESCE(duration_seconds, 0), COALESCE(format, '') FROM tracks WHERE album_id = ? ORDER BY track_number, title`,
		albumID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Track
	for rows.Next() {
		var t Track
		if err := rows.Scan(&t.ID, &t.Title, &t.AudioPath, &t.VideoPath, &t.VideoThumbPath, &t.AlbumID, &t.TrackNumber, &t.ProducerID, &t.Producer, &t.Vocal, &t.Year, &t.DurationSeconds, &t.Format); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// ListTracks returns all tracks ordered by title.
func (s *Store) ListTracks() ([]Track, error) {
	rows, err := s.db.Query(`SELECT id, title, audio_path, video_path, COALESCE(video_thumb_path, ''), COALESCE(album_id, 0), COALESCE(track_number, 0), COALESCE(producer_id, 0), COALESCE(producer, ''), COALESCE(vocal, ''), COALESCE(year, 0), COALESCE(duration_seconds, 0), COALESCE(format, '') FROM tracks ORDER BY title`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Track
	for rows.Next() {
		var t Track
		if err := rows.Scan(&t.ID, &t.Title, &t.AudioPath, &t.VideoPath, &t.VideoThumbPath, &t.AlbumID, &t.TrackNumber, &t.ProducerID, &t.Producer, &t.Vocal, &t.Year, &t.DurationSeconds, &t.Format); err != nil {
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
		`SELECT id, title, audio_path, video_path, COALESCE(video_thumb_path, ''), COALESCE(album_id, 0), COALESCE(track_number, 0), COALESCE(producer_id, 0), COALESCE(producer, ''), COALESCE(vocal, ''), COALESCE(year, 0), COALESCE(duration_seconds, 0), COALESCE(format, '') FROM tracks WHERE id = ?`,
		id,
	).Scan(&t.ID, &t.Title, &t.AudioPath, &t.VideoPath, &t.VideoThumbPath, &t.AlbumID, &t.TrackNumber, &t.ProducerID, &t.Producer, &t.Vocal, &t.Year, &t.DurationSeconds, &t.Format)
	if err == sql.ErrNoRows {
		return Track{}, false, nil
	}
	if err != nil {
		return Track{}, false, err
	}
	return t, true, nil
}

// ListProducers returns all distinct producers from tracks with track and album counts.
func (s *Store) ListProducers() ([]Producer, error) {
	rows, err := s.db.Query(`
		SELECT p.id, p.name,
		       COUNT(t.id) AS track_count,
		       COUNT(DISTINCT CASE WHEN t.album_id > 0 THEN t.album_id END) AS album_count,
		       COALESCE(p.avatar_path, '') AS avatar_path
		FROM producers p
		INNER JOIN tracks t ON t.producer_id = p.id
		GROUP BY p.id
		ORDER BY track_count DESC, p.name
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Producer
	for rows.Next() {
		var p Producer
		if err := rows.Scan(&p.ID, &p.Name, &p.TrackCount, &p.AlbumCount, &p.AvatarPath); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

// GetProducerByID returns producer by id, or false if not found.
func (s *Store) GetProducerByID(id int64) (Producer, bool, error) {
	var p Producer
	err := s.db.QueryRow(`
		SELECT p.id, p.name,
		       COUNT(t.id) AS track_count,
		       COUNT(DISTINCT CASE WHEN t.album_id > 0 THEN t.album_id END) AS album_count,
		       COALESCE(p.avatar_path, '') AS avatar_path
		FROM producers p
		LEFT JOIN tracks t ON t.producer_id = p.id
		WHERE p.id = ?
		GROUP BY p.id
	`, id).Scan(&p.ID, &p.Name, &p.TrackCount, &p.AlbumCount, &p.AvatarPath)
	if err == sql.ErrNoRows {
		return Producer{}, false, nil
	}
	if err != nil {
		return Producer{}, false, err
	}
	return p, true, nil
}

// GetProducerByName returns producer stats by name, or false if not found.
func (s *Store) GetProducerByName(name string) (Producer, bool, error) {
	name = strings.TrimSpace(name)
	var p Producer
	err := s.db.QueryRow(`
		SELECT p.id, p.name,
		       COUNT(t.id) AS track_count,
		       COUNT(DISTINCT CASE WHEN t.album_id > 0 THEN t.album_id END) AS album_count,
		       COALESCE(p.avatar_path, '') AS avatar_path
		FROM producers p
		LEFT JOIN tracks t ON t.producer_id = p.id
		WHERE p.name = ?
		GROUP BY p.id
	`, name).Scan(&p.ID, &p.Name, &p.TrackCount, &p.AlbumCount, &p.AvatarPath)
	if err == sql.ErrNoRows {
		return Producer{}, false, nil
	}
	if err != nil {
		return Producer{}, false, err
	}
	return p, true, nil
}

// GetTracksByProducer returns all tracks by producer id.
func (s *Store) GetTracksByProducer(id int64) ([]Track, error) {
	rows, err := s.db.Query(
		`SELECT id, title, audio_path, video_path, COALESCE(video_thumb_path, ''), COALESCE(album_id, 0), COALESCE(track_number, 0), COALESCE(producer_id, 0), COALESCE(producer, ''), COALESCE(vocal, ''), COALESCE(year, 0), COALESCE(duration_seconds, 0), COALESCE(format, '') FROM tracks WHERE producer_id = ? ORDER BY album_id, track_number, title`,
		id,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Track
	for rows.Next() {
		var t Track
		if err := rows.Scan(&t.ID, &t.Title, &t.AudioPath, &t.VideoPath, &t.VideoThumbPath, &t.AlbumID, &t.TrackNumber, &t.ProducerID, &t.Producer, &t.Vocal, &t.Year, &t.DurationSeconds, &t.Format); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// GetAlbumsByProducer returns albums that have at least one track by the given producer id.
func (s *Store) GetAlbumsByProducer(id int64) ([]Album, error) {
	rows, err := s.db.Query(`
		SELECT a.id, a.artist, a.title, a.cover_path, COUNT(t.id) AS track_count, COALESCE(a.producer_id, 0)
		FROM albums a
		INNER JOIN tracks t ON t.album_id = a.id AND t.producer_id = ?
		GROUP BY a.id
		ORDER BY a.artist, a.title
	`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Album
	for rows.Next() {
		var a Album
		if err := rows.Scan(&a.ID, &a.Artist, &a.Title, &a.CoverPath, &a.TrackCount, &a.ProducerID); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
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
