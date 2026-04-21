package store

import (
	"database/sql"
	"fmt"
	"regexp"
	"sort"
	"strings"

	_ "modernc.org/sqlite"
)

// Producer aggregates track producer (P主) with track and album counts.
type Producer struct {
	ID         int64  `json:"id"`
	Name       string `json:"name"`
	TrackCount int    `json:"track_count"`
	AlbumCount int    `json:"album_count"`
	AvatarPath string `json:"avatar_path,omitempty"` // supported artist image in P主 folder
}

// Vocalist aggregates a unique vocalist name with track and album counts.
type Vocalist struct {
	Name       string `json:"name"`
	TrackCount int    `json:"track_count"`
	AlbumCount int    `json:"album_count"`
}

// Album represents an album.
type Album struct {
	ID           int64  `json:"id"`
	Title        string `json:"title"`
	CoverPath    string `json:"cover_path"`
	TrackCount   int    `json:"track_count"`
	ProducerID   int64  `json:"producer_id,omitempty"`
	ProducerName string `json:"producer_name,omitempty"` // Denormalized for display
	AlbumArtist  string `json:"album_artist,omitempty"`
}

// Track represents a single track with audio and optional video path.
type Track struct {
	ID              int64  `json:"id"`
	Title           string `json:"title"`
	AudioPath       string `json:"audio_path"`
	VideoPath       string `json:"video_path"`
	VideoThumbPath  string `json:"video_thumb_path"` // MV thumbnail (same name as video, or ffmpeg-generated)
	AlbumID         int64  `json:"album_id,omitempty"`
	DiscNumber      int    `json:"disc_number"`  // 碟号，多碟专辑时从元数据读取，默认 1
	TrackNumber     int    `json:"track_number"`
	Artists         string `json:"artists"`      // 艺术家，可能包含多个（如 "初音ミク, 镜音リン"）
	Year            int    `json:"year"`         // 年份
	DurationSeconds int    `json:"duration_seconds"` // 时长（秒）
	Format          string `json:"format"`           // 码率/格式，如 "24bit FLAC"
	// Extended metadata fields
	Composer          string `json:"composer,omitempty"`           // 作曲
	Lyricist          string `json:"lyricist,omitempty"`           // 作词
	Arranger          string `json:"arranger,omitempty"`           // 编曲
	Vocal             string `json:"vocal,omitempty"`              // Vocal（如 "初音ミク"）
	VoiceManipulator  string `json:"voice_manipulator,omitempty"`  // 调教
	Illustrator       string `json:"illustrator,omitempty"`        // 插画
	Movie             string `json:"movie,omitempty"`              // PV制作
	Source            string `json:"source,omitempty"`             // 投稿平台（如 "NicoNico", "YouTube"）
	Lyrics            string `json:"lyrics,omitempty"`             // 歌词
	Comment           string `json:"comment,omitempty"`            // 备注
	AlbumArtist       string `json:"album_artist,omitempty"`
	FileMtime         int64  `json:"-"` // File modification time (Unix timestamp)
	FileSize          int64  `json:"-"` // File size in bytes
}

// Video represents a standalone or track-linked video (MV).
type Video struct {
	ID              int64  `json:"id"`
	Title           string `json:"title"`
	Artist          string `json:"artist"`
	Path            string `json:"path"`
	ThumbPath       string `json:"thumb_path"`
	DurationSeconds int    `json:"duration_seconds"`
	TrackID         *int64 `json:"track_id,omitempty"`
	ProducerID      *int64 `json:"producer_id,omitempty"`
	Source          string `json:"source"`
	// Joined fields from track/album (populated by ListVideos/GetVideoByID)
	TrackTitle string `json:"track_title,omitempty"`
	AlbumTitle string `json:"album_title,omitempty"`
	CoverPath  string `json:"cover_path,omitempty"`
	Composer   string `json:"composer,omitempty"`
	Vocal      string `json:"vocal,omitempty"`
	FileMtime  int64  `json:"-"`
	FileSize   int64  `json:"-"`
}

// VideoMeta holds minimal video metadata for incremental scan comparison.
type VideoMeta struct {
	Path    string
	ModTime int64
	Size    int64
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
	// SQLite PRAGMA settings are connection-local. Keep a single pooled
	// connection so foreign-key enforcement and cascades remain reliable.
	db.SetMaxOpenConns(1)
	db.SetMaxIdleConns(1)
	// WAL mode reduces locking so the db file is less often "busy or locked" when copying.
	if _, err := db.Exec(`PRAGMA journal_mode=WAL`); err != nil {
		db.Close()
		return nil, fmt.Errorf("enable WAL: %w", err)
	}
	if _, err := db.Exec(`PRAGMA foreign_keys = ON`); err != nil {
		db.Close()
		return nil, fmt.Errorf("enable foreign_keys: %w", err)
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
			title TEXT NOT NULL UNIQUE,
			cover_path TEXT NOT NULL DEFAULT '',
			producer_id INTEGER REFERENCES producers(id),
			dir_mtime INTEGER NOT NULL DEFAULT 0
		);
		CREATE INDEX IF NOT EXISTS idx_albums_title ON albums(title);
		CREATE INDEX IF NOT EXISTS idx_albums_producer ON albums(producer_id);

		CREATE TABLE IF NOT EXISTS tracks (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			title TEXT NOT NULL,
			audio_path TEXT NOT NULL UNIQUE,
			video_path TEXT NOT NULL DEFAULT '',
			video_thumb_path TEXT NOT NULL DEFAULT '',
			album_id INTEGER REFERENCES albums(id),
			disc_number INTEGER NOT NULL DEFAULT 1,
			track_number INTEGER NOT NULL DEFAULT 0,
			artists TEXT NOT NULL DEFAULT '',
			year INTEGER NOT NULL DEFAULT 0,
			duration_seconds INTEGER NOT NULL DEFAULT 0,
			format TEXT NOT NULL DEFAULT '',
			composer TEXT NOT NULL DEFAULT '',
			lyricist TEXT NOT NULL DEFAULT '',
			arranger TEXT NOT NULL DEFAULT '',
			vocal TEXT NOT NULL DEFAULT '',
			voice_manipulator TEXT NOT NULL DEFAULT '',
			illustrator TEXT NOT NULL DEFAULT '',
			movie TEXT NOT NULL DEFAULT '',
			source TEXT NOT NULL DEFAULT '',
			lyrics TEXT NOT NULL DEFAULT '',
			comment TEXT NOT NULL DEFAULT '',
			file_mtime INTEGER NOT NULL DEFAULT 0,
			file_size INTEGER NOT NULL DEFAULT 0
		);
		CREATE INDEX IF NOT EXISTS idx_tracks_audio ON tracks(audio_path);
		CREATE INDEX IF NOT EXISTS idx_tracks_album ON tracks(album_id);

		CREATE TABLE IF NOT EXISTS videos (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			title TEXT NOT NULL,
			artist TEXT NOT NULL DEFAULT '',
			path TEXT NOT NULL UNIQUE,
			thumb_path TEXT NOT NULL DEFAULT '',
			duration_seconds INTEGER NOT NULL DEFAULT 0,
			track_id INTEGER DEFAULT NULL REFERENCES tracks(id),
			producer_id INTEGER DEFAULT NULL REFERENCES producers(id),
			source TEXT NOT NULL DEFAULT 'scan',
			file_mtime INTEGER NOT NULL DEFAULT 0,
			file_size INTEGER NOT NULL DEFAULT 0
		);
		CREATE INDEX IF NOT EXISTS idx_videos_path ON videos(path);
		CREATE INDEX IF NOT EXISTS idx_videos_track ON videos(track_id);

		CREATE TABLE IF NOT EXISTS favorites (
			track_id    INTEGER PRIMARY KEY
			            REFERENCES tracks(id) ON DELETE CASCADE,
			created_at  INTEGER NOT NULL
		);

		CREATE TABLE IF NOT EXISTS playlists (
			id          INTEGER PRIMARY KEY AUTOINCREMENT,
			name        TEXT NOT NULL,
			cover_path  TEXT NOT NULL DEFAULT '',
			created_at  INTEGER NOT NULL,
			updated_at  INTEGER NOT NULL
		);
		CREATE INDEX IF NOT EXISTS idx_playlists_updated
			ON playlists(updated_at DESC);

		CREATE TABLE IF NOT EXISTS playlist_groups (
			id          INTEGER PRIMARY KEY AUTOINCREMENT,
			playlist_id INTEGER NOT NULL
			            REFERENCES playlists(id) ON DELETE CASCADE,
			title       TEXT NOT NULL,
			position    INTEGER NOT NULL,
			is_system   INTEGER NOT NULL DEFAULT 0,
			created_at  INTEGER NOT NULL,
			updated_at  INTEGER NOT NULL,
			UNIQUE (playlist_id, position)
		);
		CREATE INDEX IF NOT EXISTS idx_playlist_groups_playlist
			ON playlist_groups(playlist_id, position);
		CREATE UNIQUE INDEX IF NOT EXISTS idx_playlist_groups_id_playlist
			ON playlist_groups(id, playlist_id);
		CREATE UNIQUE INDEX IF NOT EXISTS idx_playlist_groups_single_system
			ON playlist_groups(playlist_id)
			WHERE is_system = 1;

		CREATE TABLE IF NOT EXISTS playlist_items (
			id                INTEGER PRIMARY KEY AUTOINCREMENT,
			playlist_id        INTEGER NOT NULL
			                  REFERENCES playlists(id) ON DELETE CASCADE,
			track_id           INTEGER NOT NULL
			                  REFERENCES tracks(id) ON DELETE CASCADE,
			group_id           INTEGER NOT NULL
			                  REFERENCES playlist_groups(id) ON DELETE CASCADE,
			position           INTEGER NOT NULL,
			note               TEXT NOT NULL DEFAULT '',
			cover_mode         TEXT NOT NULL DEFAULT 'default',
			library_cover_id   TEXT NOT NULL DEFAULT '',
			cached_cover_url   TEXT NOT NULL DEFAULT '',
			custom_cover_path  TEXT NOT NULL DEFAULT '',
			created_at         INTEGER NOT NULL,
			updated_at         INTEGER NOT NULL,
			FOREIGN KEY (group_id, playlist_id)
				REFERENCES playlist_groups(id, playlist_id) ON DELETE CASCADE,
			UNIQUE (group_id, position)
		);
		CREATE INDEX IF NOT EXISTS idx_playlist_items_playlist
			ON playlist_items(playlist_id);
		CREATE INDEX IF NOT EXISTS idx_playlist_items_group_order
			ON playlist_items(group_id, position);
	`)
	if err != nil {
		return err
	}
	// Add album_artist column (idempotent: ALTER TABLE fails silently if column exists).
	db.Exec(`ALTER TABLE albums ADD COLUMN album_artist TEXT DEFAULT ''`)
	return nil
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

// UpsertAlbum inserts or updates an album by title. Returns album ID.
func (s *Store) UpsertAlbum(title, coverPath string, producerID int64, albumArtist string) (int64, error) {
	// Use NULL for producer_id when 0, so foreign-key constraints are satisfied.
	var pid any
	if producerID != 0 {
		pid = producerID
	}
	_, err := s.db.Exec(
		`INSERT INTO albums (title, cover_path, producer_id, album_artist) VALUES (?, ?, ?, ?)
		 ON CONFLICT(title) DO UPDATE SET cover_path=excluded.cover_path, producer_id=excluded.producer_id, album_artist=excluded.album_artist`,
		title, coverPath, pid, albumArtist,
	)
	if err != nil {
		return 0, err
	}
	var id int64
	err = s.db.QueryRow(`SELECT id FROM albums WHERE title = ?`, title).Scan(&id)
	return id, err
}

// UpdateAlbumCover sets the cover path for an album (e.g. after extracting from track).
func (s *Store) UpdateAlbumCover(albumID int64, coverPath string) error {
	_, err := s.db.Exec(`UPDATE albums SET cover_path = ? WHERE id = ?`, coverPath, albumID)
	return err
}

// UpsertTrack inserts or updates a track by audio_path.
func (s *Store) UpsertTrack(title, audioPath, videoPath, videoThumbPath string, albumID int64, discNumber, trackNumber int, artists string, year, durationSeconds int, format string) error {
	_, err := s.db.Exec(
		`INSERT INTO tracks (title, audio_path, video_path, video_thumb_path, album_id, disc_number, track_number, artists, year, duration_seconds, format) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		 ON CONFLICT(audio_path) DO UPDATE SET title=excluded.title, video_path=excluded.video_path, video_thumb_path=excluded.video_thumb_path, album_id=excluded.album_id, disc_number=excluded.disc_number, track_number=excluded.track_number, artists=excluded.artists, year=excluded.year, duration_seconds=excluded.duration_seconds, format=excluded.format`,
		title, audioPath, videoPath, videoThumbPath, albumID, discNumber, trackNumber, artists, year, durationSeconds, format,
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

// ListAlbums returns all albums ordered by title.
func (s *Store) ListAlbums() ([]Album, error) {
	rows, err := s.db.Query(`
		SELECT a.id, a.title, a.cover_path, COUNT(t.id) AS track_count,
		       COALESCE(a.producer_id, 0), COALESCE(p.name, ''),
		       COALESCE(a.album_artist, '')
		FROM albums a
		LEFT JOIN tracks t ON t.album_id = a.id
		LEFT JOIN producers p ON p.id = a.producer_id
		GROUP BY a.id
		ORDER BY a.title
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Album
	for rows.Next() {
		var a Album
		if err := rows.Scan(&a.ID, &a.Title, &a.CoverPath, &a.TrackCount, &a.ProducerID, &a.ProducerName, &a.AlbumArtist); err != nil {
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
		SELECT a.id, a.title, a.cover_path, COUNT(t.id),
		       COALESCE(a.producer_id, 0), COALESCE(p.name, ''),
		       COALESCE(a.album_artist, '')
		FROM albums a
		LEFT JOIN tracks t ON t.album_id = a.id
		LEFT JOIN producers p ON p.id = a.producer_id
		WHERE a.id = ?
		GROUP BY a.id
	`, id).Scan(&a.ID, &a.Title, &a.CoverPath, &a.TrackCount, &a.ProducerID, &a.ProducerName, &a.AlbumArtist)
	if err == sql.ErrNoRows {
		return Album{}, false, nil
	}
	if err != nil {
		return Album{}, false, err
	}
	return a, true, nil
}

// GetTracksByAlbumID returns tracks for an album, ordered by disc_number then track_number then title.
func (s *Store) GetTracksByAlbumID(albumID int64) ([]Track, error) {
	rows, err := s.db.Query(
		`SELECT t.id, t.title, t.audio_path, t.video_path, COALESCE(t.video_thumb_path, ''), COALESCE(t.album_id, 0),
		 COALESCE(t.disc_number, 1), COALESCE(t.track_number, 0), COALESCE(t.artists, ''), COALESCE(t.year, 0),
		 COALESCE(t.duration_seconds, 0), COALESCE(t.format, ''), COALESCE(t.composer, ''), COALESCE(t.lyricist, ''),
		 COALESCE(t.arranger, ''), COALESCE(t.vocal, ''), COALESCE(t.voice_manipulator, ''), COALESCE(t.illustrator, ''),
		 COALESCE(t.movie, ''), COALESCE(t.source, ''), COALESCE(t.lyrics, ''), COALESCE(t.comment, ''),
		 COALESCE(a.album_artist, '')
		 FROM tracks t
		 LEFT JOIN albums a ON t.album_id = a.id
		 WHERE t.album_id = ? ORDER BY t.disc_number, t.track_number, t.title`,
		albumID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Track
	for rows.Next() {
		var t Track
		if err := rows.Scan(&t.ID, &t.Title, &t.AudioPath, &t.VideoPath, &t.VideoThumbPath, &t.AlbumID,
			&t.DiscNumber, &t.TrackNumber, &t.Artists, &t.Year, &t.DurationSeconds, &t.Format,
			&t.Composer, &t.Lyricist, &t.Arranger, &t.Vocal, &t.VoiceManipulator, &t.Illustrator,
			&t.Movie, &t.Source, &t.Lyrics, &t.Comment, &t.AlbumArtist); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// ListTracks returns all tracks ordered by title.
func (s *Store) ListTracks() ([]Track, error) {
	rows, err := s.db.Query(`SELECT t.id, t.title, t.audio_path, t.video_path, COALESCE(t.video_thumb_path, ''), COALESCE(t.album_id, 0),
		 COALESCE(t.disc_number, 1), COALESCE(t.track_number, 0), COALESCE(t.artists, ''), COALESCE(t.year, 0),
		 COALESCE(t.duration_seconds, 0), COALESCE(t.format, ''), COALESCE(t.composer, ''), COALESCE(t.lyricist, ''),
		 COALESCE(t.arranger, ''), COALESCE(t.vocal, ''), COALESCE(t.voice_manipulator, ''), COALESCE(t.illustrator, ''),
		 COALESCE(t.movie, ''), COALESCE(t.source, ''), COALESCE(t.lyrics, ''), COALESCE(t.comment, ''),
		 COALESCE(a.album_artist, '')
		 FROM tracks t
		 LEFT JOIN albums a ON t.album_id = a.id
		 ORDER BY t.title`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Track
	for rows.Next() {
		var t Track
		if err := rows.Scan(&t.ID, &t.Title, &t.AudioPath, &t.VideoPath, &t.VideoThumbPath, &t.AlbumID,
			&t.DiscNumber, &t.TrackNumber, &t.Artists, &t.Year, &t.DurationSeconds, &t.Format,
			&t.Composer, &t.Lyricist, &t.Arranger, &t.Vocal, &t.VoiceManipulator, &t.Illustrator,
			&t.Movie, &t.Source, &t.Lyrics, &t.Comment, &t.AlbumArtist); err != nil {
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
		`SELECT t.id, t.title, t.audio_path, t.video_path, COALESCE(t.video_thumb_path, ''), COALESCE(t.album_id, 0),
		 COALESCE(t.disc_number, 1), COALESCE(t.track_number, 0), COALESCE(t.artists, ''), COALESCE(t.year, 0),
		 COALESCE(t.duration_seconds, 0), COALESCE(t.format, ''), COALESCE(t.composer, ''), COALESCE(t.lyricist, ''),
		 COALESCE(t.arranger, ''), COALESCE(t.vocal, ''), COALESCE(t.voice_manipulator, ''), COALESCE(t.illustrator, ''),
		 COALESCE(t.movie, ''), COALESCE(t.source, ''), COALESCE(t.lyrics, ''), COALESCE(t.comment, ''),
		 COALESCE(a.album_artist, '')
		 FROM tracks t
		 LEFT JOIN albums a ON t.album_id = a.id
		 WHERE t.id = ?`,
		id,
	).Scan(&t.ID, &t.Title, &t.AudioPath, &t.VideoPath, &t.VideoThumbPath, &t.AlbumID,
		&t.DiscNumber, &t.TrackNumber, &t.Artists, &t.Year, &t.DurationSeconds, &t.Format,
		&t.Composer, &t.Lyricist, &t.Arranger, &t.Vocal, &t.VoiceManipulator, &t.Illustrator,
		&t.Movie, &t.Source, &t.Lyrics, &t.Comment, &t.AlbumArtist)
	if err == sql.ErrNoRows {
		return Track{}, false, nil
	}
	if err != nil {
		return Track{}, false, err
	}
	return t, true, nil
}

// ListProducers returns all distinct producers from albums with track and album counts.
func (s *Store) ListProducers() ([]Producer, error) {
	rows, err := s.db.Query(`
		SELECT p.id, p.name,
		       COUNT(DISTINCT t.id) AS track_count,
		       COUNT(DISTINCT a.id) AS album_count,
		       COALESCE(p.avatar_path, '') AS avatar_path
		FROM producers p
		INNER JOIN albums a ON a.producer_id = p.id
		LEFT JOIN tracks t ON t.album_id = a.id
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
		       COUNT(DISTINCT t.id) AS track_count,
		       COUNT(DISTINCT a.id) AS album_count,
		       COALESCE(p.avatar_path, '') AS avatar_path
		FROM producers p
		LEFT JOIN albums a ON a.producer_id = p.id
		LEFT JOIN tracks t ON t.album_id = a.id
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
		       COUNT(DISTINCT t.id) AS track_count,
		       COUNT(DISTINCT a.id) AS album_count,
		       COALESCE(p.avatar_path, '') AS avatar_path
		FROM producers p
		LEFT JOIN albums a ON a.producer_id = p.id
		LEFT JOIN tracks t ON t.album_id = a.id
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

// GetTracksByProducer returns all tracks by producer id (via albums).
func (s *Store) GetTracksByProducer(id int64) ([]Track, error) {
	rows, err := s.db.Query(
		`SELECT t.id, t.title, t.audio_path, t.video_path, COALESCE(t.video_thumb_path, ''), COALESCE(t.album_id, 0),
		 COALESCE(t.disc_number, 1), COALESCE(t.track_number, 0), COALESCE(t.artists, ''), COALESCE(t.year, 0),
		 COALESCE(t.duration_seconds, 0), COALESCE(t.format, ''), COALESCE(t.composer, ''), COALESCE(t.lyricist, ''),
		 COALESCE(t.arranger, ''), COALESCE(t.vocal, ''), COALESCE(t.voice_manipulator, ''), COALESCE(t.illustrator, ''),
		 COALESCE(t.movie, ''), COALESCE(t.source, ''), COALESCE(t.lyrics, ''), COALESCE(t.comment, ''),
		 COALESCE(a.album_artist, '')
		FROM tracks t
		INNER JOIN albums a ON t.album_id = a.id
		WHERE a.producer_id = ?
		ORDER BY t.album_id, t.disc_number, t.track_number, t.title`,
		id,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Track
	for rows.Next() {
		var t Track
		if err := rows.Scan(&t.ID, &t.Title, &t.AudioPath, &t.VideoPath, &t.VideoThumbPath, &t.AlbumID,
			&t.DiscNumber, &t.TrackNumber, &t.Artists, &t.Year, &t.DurationSeconds, &t.Format,
			&t.Composer, &t.Lyricist, &t.Arranger, &t.Vocal, &t.VoiceManipulator, &t.Illustrator,
			&t.Movie, &t.Source, &t.Lyrics, &t.Comment, &t.AlbumArtist); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// GetAlbumsByProducer returns albums by the given producer id.
func (s *Store) GetAlbumsByProducer(id int64) ([]Album, error) {
	rows, err := s.db.Query(`
		SELECT a.id, a.title, a.cover_path, COUNT(t.id) AS track_count,
		       COALESCE(a.producer_id, 0), COALESCE(p.name, ''),
		       COALESCE(a.album_artist, '')
		FROM albums a
		LEFT JOIN tracks t ON t.album_id = a.id
		LEFT JOIN producers p ON p.id = a.producer_id
		WHERE a.producer_id = ?
		GROUP BY a.id
		ORDER BY a.title
	`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Album
	for rows.Next() {
		var a Album
		if err := rows.Scan(&a.ID, &a.Title, &a.CoverPath, &a.TrackCount, &a.ProducerID, &a.ProducerName, &a.AlbumArtist); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// ListVocalists returns unique vocalists aggregated from tracks.vocal with track and album counts.
func (s *Store) ListVocalists() ([]Vocalist, error) {
	rows, err := s.db.Query(`SELECT vocal, album_id FROM tracks WHERE vocal != ''`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	type counts struct {
		tracks int
		albums map[int64]bool
	}
	agg := make(map[string]*counts)

	splitRe := regexp.MustCompile(`\s*[;,，；/／]+\s*`)
	for rows.Next() {
		var vocal string
		var albumID int64
		if err := rows.Scan(&vocal, &albumID); err != nil {
			return nil, err
		}
		parts := splitRe.Split(vocal, -1)
		for _, name := range parts {
			name = strings.TrimSpace(name)
			if name == "" {
				continue
			}
			c, ok := agg[name]
			if !ok {
				c = &counts{albums: make(map[int64]bool)}
				agg[name] = c
			}
			c.tracks++
			if albumID > 0 {
				c.albums[albumID] = true
			}
		}
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	out := make([]Vocalist, 0, len(agg))
	for name, c := range agg {
		out = append(out, Vocalist{Name: name, TrackCount: c.tracks, AlbumCount: len(c.albums)})
	}
	// Sort by track count descending, then name ascending
	sort.Slice(out, func(i, j int) bool {
		if out[i].TrackCount != out[j].TrackCount {
			return out[i].TrackCount > out[j].TrackCount
		}
		return out[i].Name < out[j].Name
	})
	return out, nil
}

// GetTracksByVocalist returns all tracks featuring the named vocalist.
func (s *Store) GetTracksByVocalist(name string) ([]Track, error) {
	rows, err := s.db.Query(
		`SELECT t.id, t.title, t.audio_path, t.video_path, COALESCE(t.video_thumb_path, ''), COALESCE(t.album_id, 0),
		 COALESCE(t.disc_number, 1), COALESCE(t.track_number, 0), COALESCE(t.artists, ''), COALESCE(t.year, 0),
		 COALESCE(t.duration_seconds, 0), COALESCE(t.format, ''), COALESCE(t.composer, ''), COALESCE(t.lyricist, ''),
		 COALESCE(t.arranger, ''), COALESCE(t.vocal, ''), COALESCE(t.voice_manipulator, ''), COALESCE(t.illustrator, ''),
		 COALESCE(t.movie, ''), COALESCE(t.source, ''), COALESCE(t.lyrics, ''), COALESCE(t.comment, ''),
		 COALESCE(a.album_artist, '')
		 FROM tracks t
		 LEFT JOIN albums a ON t.album_id = a.id
		 WHERE t.vocal != ''
		 ORDER BY t.album_id, t.disc_number, t.track_number, t.title`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	splitRe := regexp.MustCompile(`\s*[;,，；/／]+\s*`)
	var out []Track
	for rows.Next() {
		var t Track
		if err := rows.Scan(&t.ID, &t.Title, &t.AudioPath, &t.VideoPath, &t.VideoThumbPath, &t.AlbumID,
			&t.DiscNumber, &t.TrackNumber, &t.Artists, &t.Year, &t.DurationSeconds, &t.Format,
			&t.Composer, &t.Lyricist, &t.Arranger, &t.Vocal, &t.VoiceManipulator, &t.Illustrator,
			&t.Movie, &t.Source, &t.Lyrics, &t.Comment, &t.AlbumArtist); err != nil {
			return nil, err
		}
		// Check if this track features the named vocalist
		parts := splitRe.Split(t.Vocal, -1)
		for _, part := range parts {
			if strings.TrimSpace(part) == name {
				out = append(out, t)
				break
			}
		}
	}
	return out, rows.Err()
}

// GetAlbumsByVocalist returns albums that have tracks featuring the named vocalist.
func (s *Store) GetAlbumsByVocalist(name string) ([]Album, error) {
	// First get the track list, then extract unique album IDs
	tracks, err := s.GetTracksByVocalist(name)
	if err != nil {
		return nil, err
	}
	albumIDs := make(map[int64]bool)
	for _, t := range tracks {
		if t.AlbumID > 0 {
			albumIDs[t.AlbumID] = true
		}
	}
	if len(albumIDs) == 0 {
		return nil, nil
	}
	var out []Album
	for id := range albumIDs {
		a, ok, err := s.GetAlbumByID(id)
		if err != nil {
			return nil, err
		}
		if ok {
			out = append(out, a)
		}
	}
	sort.Slice(out, func(i, j int) bool {
		return out[i].Title < out[j].Title
	})
	return out, nil
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

// TrackMeta holds minimal track metadata for incremental scan comparison.
type TrackMeta struct {
	Path    string
	ModTime int64
	Size    int64
}

// GetAllTracksMeta returns a map of audio_path -> TrackMeta for all tracks.
func (s *Store) GetAllTracksMeta() (map[string]TrackMeta, error) {
	rows, err := s.db.Query(`SELECT audio_path, file_mtime, file_size FROM tracks`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := make(map[string]TrackMeta)
	for rows.Next() {
		var tm TrackMeta
		if err := rows.Scan(&tm.Path, &tm.ModTime, &tm.Size); err != nil {
			return nil, err
		}
		result[tm.Path] = tm
	}
	return result, rows.Err()
}

// DeleteTracksByPaths deletes tracks with the given audio paths.
func (s *Store) DeleteTracksByPaths(paths []string) error {
	if len(paths) == 0 {
		return nil
	}
	placeholders := make([]string, len(paths))
	args := make([]any, len(paths))
	for i, p := range paths {
		placeholders[i] = "?"
		args[i] = p
	}
	query := `DELETE FROM tracks WHERE audio_path IN (` + strings.Join(placeholders, ",") + `)`
	_, err := s.db.Exec(query, args...)
	return err
}

// CleanOrphanedAlbums deletes albums that have no associated tracks.
func (s *Store) CleanOrphanedAlbums() error {
	_, err := s.db.Exec(`DELETE FROM albums WHERE id NOT IN (SELECT DISTINCT album_id FROM tracks WHERE album_id > 0)`)
	return err
}

// CleanOrphanedProducers deletes producers that have no associated albums.
func (s *Store) CleanOrphanedProducers() error {
	_, err := s.db.Exec(`DELETE FROM producers WHERE id NOT IN (SELECT DISTINCT producer_id FROM albums WHERE producer_id > 0)`)
	return err
}

// UpsertVideo inserts or updates a video by path. Returns video ID.
func (s *Store) UpsertVideo(v Video) (int64, error) {
	_, err := s.db.Exec(
		`INSERT INTO videos (title, artist, path, thumb_path, duration_seconds, track_id, producer_id, source, file_mtime, file_size)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		 ON CONFLICT(path) DO UPDATE SET title=excluded.title, artist=excluded.artist, thumb_path=excluded.thumb_path,
		 duration_seconds=excluded.duration_seconds, track_id=excluded.track_id, producer_id=excluded.producer_id,
		 source=excluded.source, file_mtime=excluded.file_mtime, file_size=excluded.file_size`,
		v.Title, v.Artist, v.Path, v.ThumbPath, v.DurationSeconds, v.TrackID, v.ProducerID, v.Source, v.FileMtime, v.FileSize,
	)
	if err != nil {
		return 0, err
	}
	var id int64
	err = s.db.QueryRow(`SELECT id FROM videos WHERE path = ?`, v.Path).Scan(&id)
	return id, err
}

// ListVideos returns all videos with joined track/album info.
func (s *Store) ListVideos() ([]Video, error) {
	rows, err := s.db.Query(`
		SELECT v.id, v.title, v.artist, v.path, v.thumb_path, v.duration_seconds,
		       v.track_id, v.producer_id, v.source, v.file_mtime, v.file_size,
		       COALESCE(t.title, ''), COALESCE(al.title, ''), COALESCE(al.cover_path, ''),
		       COALESCE(t.composer, ''), COALESCE(t.vocal, '')
		FROM videos v
		LEFT JOIN tracks t ON v.track_id = t.id
		LEFT JOIN albums al ON t.album_id = al.id
		ORDER BY v.title
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Video
	for rows.Next() {
		var v Video
		if err := rows.Scan(&v.ID, &v.Title, &v.Artist, &v.Path, &v.ThumbPath, &v.DurationSeconds,
			&v.TrackID, &v.ProducerID, &v.Source, &v.FileMtime, &v.FileSize,
			&v.TrackTitle, &v.AlbumTitle, &v.CoverPath, &v.Composer, &v.Vocal); err != nil {
			return nil, err
		}
		out = append(out, v)
	}
	return out, rows.Err()
}

// GetVideoByID returns a video by id with joined track/album info.
func (s *Store) GetVideoByID(id int64) (Video, bool, error) {
	var v Video
	err := s.db.QueryRow(`
		SELECT v.id, v.title, v.artist, v.path, v.thumb_path, v.duration_seconds,
		       v.track_id, v.producer_id, v.source, v.file_mtime, v.file_size,
		       COALESCE(t.title, ''), COALESCE(al.title, ''), COALESCE(al.cover_path, ''),
		       COALESCE(t.composer, ''), COALESCE(t.vocal, '')
		FROM videos v
		LEFT JOIN tracks t ON v.track_id = t.id
		LEFT JOIN albums al ON t.album_id = al.id
		WHERE v.id = ?
	`, id).Scan(&v.ID, &v.Title, &v.Artist, &v.Path, &v.ThumbPath, &v.DurationSeconds,
		&v.TrackID, &v.ProducerID, &v.Source, &v.FileMtime, &v.FileSize,
		&v.TrackTitle, &v.AlbumTitle, &v.CoverPath, &v.Composer, &v.Vocal)
	if err == sql.ErrNoRows {
		return Video{}, false, nil
	}
	if err != nil {
		return Video{}, false, err
	}
	return v, true, nil
}

// GetAllVideosMeta returns a map of path -> VideoMeta for all videos.
func (s *Store) GetAllVideosMeta() (map[string]VideoMeta, error) {
	rows, err := s.db.Query(`SELECT path, file_mtime, file_size FROM videos`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := make(map[string]VideoMeta)
	for rows.Next() {
		var vm VideoMeta
		if err := rows.Scan(&vm.Path, &vm.ModTime, &vm.Size); err != nil {
			return nil, err
		}
		result[vm.Path] = vm
	}
	return result, rows.Err()
}

// DeleteVideosByPaths deletes videos with the given paths.
func (s *Store) DeleteVideosByPaths(paths []string) error {
	if len(paths) == 0 {
		return nil
	}
	placeholders := make([]string, len(paths))
	args := make([]any, len(paths))
	for i, p := range paths {
		placeholders[i] = "?"
		args[i] = p
	}
	query := `DELETE FROM videos WHERE path IN (` + strings.Join(placeholders, ",") + `)`
	_, err := s.db.Exec(query, args...)
	return err
}

// SyncTrackVideos syncs the videos table from tracks that have video_path set.
// For each track with a non-empty video_path, upserts a video with track_id and source='scan'.
// Removes videos where track_id is set but the track no longer has a video_path.
func (s *Store) SyncTrackVideos() error {
	// Upsert videos from tracks with video_path
	_, err := s.db.Exec(`
		INSERT INTO videos (title, artist, path, thumb_path, track_id, producer_id, source)
		SELECT t.title, COALESCE(t.artists, ''), t.video_path, COALESCE(t.video_thumb_path, ''),
		       t.id, a.producer_id, 'scan'
		FROM tracks t
		LEFT JOIN albums a ON t.album_id = a.id
		WHERE t.video_path != ''
		ON CONFLICT(path) DO UPDATE SET
			title=excluded.title, artist=excluded.artist, thumb_path=excluded.thumb_path,
			track_id=excluded.track_id, producer_id=excluded.producer_id, source=excluded.source
	`)
	if err != nil {
		return err
	}
	// Delete videos whose track no longer has a video_path
	_, err = s.db.Exec(`
		DELETE FROM videos
		WHERE track_id IS NOT NULL
		  AND track_id NOT IN (SELECT id FROM tracks WHERE video_path != '')
	`)
	return err
}

// GetStandaloneVideoPathsByPrefix returns paths of videos with source='scan' and no track_id
// whose path starts with the given prefix.
func (s *Store) GetStandaloneVideoPathsByPrefix(prefix string) ([]string, error) {
	rows, err := s.db.Query(
		`SELECT path FROM videos WHERE source='scan' AND track_id IS NULL AND path LIKE ?`,
		prefix+"%",
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var p string
		if err := rows.Scan(&p); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

// GetTracksWithVideo returns tracks that have a non-empty video_path.
func (s *Store) GetTracksWithVideo() ([]Track, error) {
	rows, err := s.db.Query(`SELECT id, video_path, video_thumb_path FROM tracks WHERE video_path != ''`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Track
	for rows.Next() {
		var t Track
		if err := rows.Scan(&t.ID, &t.VideoPath, &t.VideoThumbPath); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// ClearTrackVideo clears video_path and video_thumb_path for a track.
func (s *Store) ClearTrackVideo(trackID int64) error {
	_, err := s.db.Exec(`UPDATE tracks SET video_path='', video_thumb_path='' WHERE id=?`, trackID)
	return err
}

// GetTracksByAudioPaths returns tracks matching the given audio paths (id, audio_path, video_path).
func (s *Store) GetTracksByAudioPaths(paths []string) ([]Track, error) {
	if len(paths) == 0 {
		return nil, nil
	}
	placeholders := make([]string, len(paths))
	args := make([]any, len(paths))
	for i, p := range paths {
		placeholders[i] = "?"
		args[i] = p
	}
	query := `SELECT id, audio_path, video_path FROM tracks WHERE video_path = '' AND audio_path IN (` + strings.Join(placeholders, ",") + `)`
	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Track
	for rows.Next() {
		var t Track
		if err := rows.Scan(&t.ID, &t.AudioPath, &t.VideoPath); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// BatchInserter handles batch insertion of tracks with transaction support.
type BatchInserter struct {
	store         *Store
	tx            *sql.Tx
	producerCache map[string]int64
	albumCache    map[string]int64
	producers     []Producer
	albums        []Album
	tracks        []Track
	batchSize     int
}

// BeginBatch starts a new batch insertion transaction.
func (s *Store) BeginBatch(batchSize int) (*BatchInserter, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, err
	}
	return &BatchInserter{
		store:         s,
		tx:            tx,
		producerCache: make(map[string]int64),
		albumCache:    make(map[string]int64),
		batchSize:     batchSize,
	}, nil
}

// Add adds a track, album, and producer to the batch.
func (b *BatchInserter) Add(track Track, album Album, producer Producer) error {
	b.producers = append(b.producers, producer)
	b.albums = append(b.albums, album)
	b.tracks = append(b.tracks, track)

	if len(b.tracks) >= b.batchSize {
		return b.Flush()
	}
	return nil
}

// Flush commits the current batch to the database.
func (b *BatchInserter) Flush() error {
	if len(b.tracks) == 0 {
		return nil
	}

	// Batch upsert producers
	for _, p := range b.producers {
		if _, exists := b.producerCache[p.Name]; !exists {
			result, err := b.tx.Exec(`INSERT OR IGNORE INTO producers (name, avatar_path) VALUES (?, ?)`, p.Name, p.AvatarPath)
			if err != nil {
				return err
			}
			id, _ := result.LastInsertId()
			if id == 0 {
				// Already exists, fetch it
				err = b.tx.QueryRow(`SELECT id FROM producers WHERE name = ?`, p.Name).Scan(&id)
				if err != nil {
					return err
				}
			}
			b.producerCache[p.Name] = id
		}
	}

	// Batch upsert albums
	for i, a := range b.albums {
		if _, exists := b.albumCache[a.Title]; !exists {
			var pid any // NULL when no producer, so FK constraint is satisfied
			if b.producers[i].Name != "" {
				pid = b.producerCache[b.producers[i].Name]
			}
			_, err := b.tx.Exec(`
				INSERT INTO albums (title, cover_path, producer_id, dir_mtime, album_artist)
				VALUES (?, ?, ?, ?, ?)
				ON CONFLICT(title) DO UPDATE SET
					cover_path = excluded.cover_path,
					producer_id = excluded.producer_id,
					dir_mtime = excluded.dir_mtime,
					album_artist = excluded.album_artist
			`, a.Title, a.CoverPath, pid, 0, a.AlbumArtist)
			if err != nil {
				return err
			}
			var id int64
			err = b.tx.QueryRow(`SELECT id FROM albums WHERE title = ?`, a.Title).Scan(&id)
			if err != nil {
				return err
			}
			b.albumCache[a.Title] = id
		}
	}

	// Batch insert tracks
	for i, t := range b.tracks {
		albumID := b.albumCache[b.albums[i].Title]
		_, err := b.tx.Exec(`INSERT INTO tracks
			(title, audio_path, video_path, video_thumb_path, album_id, disc_number, track_number,
			 artists, year, duration_seconds, format, composer, lyricist, arranger, vocal,
			 voice_manipulator, illustrator, movie, source, lyrics, comment, file_mtime, file_size)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
			ON CONFLICT(audio_path) DO UPDATE SET
				title = excluded.title,
				video_path = excluded.video_path,
				video_thumb_path = excluded.video_thumb_path,
				album_id = excluded.album_id,
				disc_number = excluded.disc_number,
				track_number = excluded.track_number,
				artists = excluded.artists,
				year = excluded.year,
				duration_seconds = excluded.duration_seconds,
				format = excluded.format,
				composer = excluded.composer,
				lyricist = excluded.lyricist,
				arranger = excluded.arranger,
				vocal = excluded.vocal,
				voice_manipulator = excluded.voice_manipulator,
				illustrator = excluded.illustrator,
				movie = excluded.movie,
				source = excluded.source,
				lyrics = excluded.lyrics,
				comment = excluded.comment,
				file_mtime = excluded.file_mtime,
				file_size = excluded.file_size`,
			t.Title, t.AudioPath, t.VideoPath, t.VideoThumbPath, albumID, t.DiscNumber, t.TrackNumber,
			t.Artists, t.Year, t.DurationSeconds, t.Format, t.Composer, t.Lyricist, t.Arranger, t.Vocal,
			t.VoiceManipulator, t.Illustrator, t.Movie, t.Source, t.Lyrics, t.Comment, t.FileMtime, t.FileSize)
		if err != nil {
			return err
		}
	}

	// Clear buffers
	b.producers = b.producers[:0]
	b.albums = b.albums[:0]
	b.tracks = b.tracks[:0]

	return nil
}

// Close commits the transaction and closes the batch inserter.
func (b *BatchInserter) Close() error {
	if err := b.Flush(); err != nil {
		b.tx.Rollback()
		return err
	}
	return b.tx.Commit()
}
