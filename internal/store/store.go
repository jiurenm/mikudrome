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

// Album represents an album.
type Album struct {
	ID           int64  `json:"id"`
	Title        string `json:"title"`
	CoverPath    string `json:"cover_path"`
	TrackCount   int    `json:"track_count"`
	ProducerID   int64  `json:"producer_id,omitempty"`
	ProducerName string `json:"producer_name,omitempty"` // Denormalized for display
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
	FileMtime         int64  `json:"-"` // File modification time (Unix timestamp)
	FileSize          int64  `json:"-"` // File size in bytes
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

// UpsertAlbum inserts or updates an album by title. Returns album ID.
func (s *Store) UpsertAlbum(title, coverPath string, producerID int64) (int64, error) {
	_, err := s.db.Exec(
		`INSERT INTO albums (title, cover_path, producer_id) VALUES (?, ?, ?)
		 ON CONFLICT(title) DO UPDATE SET cover_path=excluded.cover_path, producer_id=excluded.producer_id`,
		title, coverPath, producerID,
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
		       COALESCE(a.producer_id, 0), COALESCE(p.name, '')
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
		if err := rows.Scan(&a.ID, &a.Title, &a.CoverPath, &a.TrackCount, &a.ProducerID, &a.ProducerName); err != nil {
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
		       COALESCE(a.producer_id, 0), COALESCE(p.name, '')
		FROM albums a
		LEFT JOIN tracks t ON t.album_id = a.id
		LEFT JOIN producers p ON p.id = a.producer_id
		WHERE a.id = ?
		GROUP BY a.id
	`, id).Scan(&a.ID, &a.Title, &a.CoverPath, &a.TrackCount, &a.ProducerID, &a.ProducerName)
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
		`SELECT id, title, audio_path, video_path, COALESCE(video_thumb_path, ''), COALESCE(album_id, 0),
		 COALESCE(disc_number, 1), COALESCE(track_number, 0), COALESCE(artists, ''), COALESCE(year, 0),
		 COALESCE(duration_seconds, 0), COALESCE(format, ''), COALESCE(composer, ''), COALESCE(lyricist, ''),
		 COALESCE(arranger, ''), COALESCE(vocal, ''), COALESCE(voice_manipulator, ''), COALESCE(illustrator, ''),
		 COALESCE(movie, ''), COALESCE(source, ''), COALESCE(lyrics, ''), COALESCE(comment, '')
		 FROM tracks WHERE album_id = ? ORDER BY disc_number, track_number, title`,
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
			&t.Movie, &t.Source, &t.Lyrics, &t.Comment); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// ListTracks returns all tracks ordered by title.
func (s *Store) ListTracks() ([]Track, error) {
	rows, err := s.db.Query(`SELECT id, title, audio_path, video_path, COALESCE(video_thumb_path, ''), COALESCE(album_id, 0),
		 COALESCE(disc_number, 1), COALESCE(track_number, 0), COALESCE(artists, ''), COALESCE(year, 0),
		 COALESCE(duration_seconds, 0), COALESCE(format, ''), COALESCE(composer, ''), COALESCE(lyricist, ''),
		 COALESCE(arranger, ''), COALESCE(vocal, ''), COALESCE(voice_manipulator, ''), COALESCE(illustrator, ''),
		 COALESCE(movie, ''), COALESCE(source, ''), COALESCE(lyrics, ''), COALESCE(comment, '')
		 FROM tracks ORDER BY title`)
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
			&t.Movie, &t.Source, &t.Lyrics, &t.Comment); err != nil {
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
		`SELECT id, title, audio_path, video_path, COALESCE(video_thumb_path, ''), COALESCE(album_id, 0),
		 COALESCE(disc_number, 1), COALESCE(track_number, 0), COALESCE(artists, ''), COALESCE(year, 0),
		 COALESCE(duration_seconds, 0), COALESCE(format, ''), COALESCE(composer, ''), COALESCE(lyricist, ''),
		 COALESCE(arranger, ''), COALESCE(vocal, ''), COALESCE(voice_manipulator, ''), COALESCE(illustrator, ''),
		 COALESCE(movie, ''), COALESCE(source, ''), COALESCE(lyrics, ''), COALESCE(comment, '')
		 FROM tracks WHERE id = ?`,
		id,
	).Scan(&t.ID, &t.Title, &t.AudioPath, &t.VideoPath, &t.VideoThumbPath, &t.AlbumID,
		&t.DiscNumber, &t.TrackNumber, &t.Artists, &t.Year, &t.DurationSeconds, &t.Format,
		&t.Composer, &t.Lyricist, &t.Arranger, &t.Vocal, &t.VoiceManipulator, &t.Illustrator,
		&t.Movie, &t.Source, &t.Lyrics, &t.Comment)
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
		 COALESCE(t.movie, ''), COALESCE(t.source, ''), COALESCE(t.lyrics, ''), COALESCE(t.comment, '')
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
			&t.Movie, &t.Source, &t.Lyrics, &t.Comment); err != nil {
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
		       COALESCE(a.producer_id, 0), COALESCE(p.name, '')
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
		if err := rows.Scan(&a.ID, &a.Title, &a.CoverPath, &a.TrackCount, &a.ProducerID, &a.ProducerName); err != nil {
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
			producerID := int64(0)
			if b.producers[i].Name != "" {
				producerID = b.producerCache[b.producers[i].Name]
			}
			result, err := b.tx.Exec(`INSERT OR REPLACE INTO albums (title, cover_path, producer_id, dir_mtime) VALUES (?, ?, ?, ?)`,
				a.Title, a.CoverPath, producerID, 0)
			if err != nil {
				return err
			}
			id, _ := result.LastInsertId()
			if id == 0 {
				err = b.tx.QueryRow(`SELECT id FROM albums WHERE title = ?`, a.Title).Scan(&id)
				if err != nil {
					return err
				}
			}
			b.albumCache[a.Title] = id
		}
	}

	// Batch insert tracks
	for i, t := range b.tracks {
		albumID := b.albumCache[b.albums[i].Title]

		_, err := b.tx.Exec(`INSERT OR REPLACE INTO tracks
			(title, audio_path, video_path, video_thumb_path, album_id, disc_number, track_number,
			 artists, year, duration_seconds, format, composer, lyricist, arranger, vocal,
			 voice_manipulator, illustrator, movie, source, lyrics, comment, file_mtime, file_size)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
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
