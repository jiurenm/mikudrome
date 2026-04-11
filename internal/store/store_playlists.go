package store

import (
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"
)

// --- Favorites ---

// AddFavorite marks a track as favorited. Idempotent: no error if already present.
func (s *Store) AddFavorite(trackID int64) error {
	_, err := s.db.Exec(
		`INSERT OR IGNORE INTO favorites (track_id, created_at) VALUES (?, ?)`,
		trackID, time.Now().Unix(),
	)
	return err
}

// RemoveFavorite clears the favorite mark. Idempotent: no error if not present.
func (s *Store) RemoveFavorite(trackID int64) error {
	_, err := s.db.Exec(`DELETE FROM favorites WHERE track_id = ?`, trackID)
	return err
}

// IsFavorite returns whether the given track is favorited.
func (s *Store) IsFavorite(trackID int64) (bool, error) {
	var one int
	err := s.db.QueryRow(`SELECT 1 FROM favorites WHERE track_id = ?`, trackID).Scan(&one)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, nil
}

// GetFavoriteSet returns a set of all favorited track IDs. O(n) in favorites count.
func (s *Store) GetFavoriteSet() (map[int64]bool, error) {
	rows, err := s.db.Query(`SELECT track_id FROM favorites`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make(map[int64]bool)
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out[id] = true
	}
	return out, rows.Err()
}

// ListFavorites returns all favorited tracks joined with track metadata,
// ordered by created_at DESC (most recently favorited first).
func (s *Store) ListFavorites() ([]Track, error) {
	rows, err := s.db.Query(
		`SELECT t.id, t.title, t.audio_path, t.video_path, COALESCE(t.video_thumb_path, ''), COALESCE(t.album_id, 0),
		 COALESCE(t.disc_number, 1), COALESCE(t.track_number, 0), COALESCE(t.artists, ''), COALESCE(t.year, 0),
		 COALESCE(t.duration_seconds, 0), COALESCE(t.format, ''), COALESCE(t.composer, ''), COALESCE(t.lyricist, ''),
		 COALESCE(t.arranger, ''), COALESCE(t.vocal, ''), COALESCE(t.voice_manipulator, ''), COALESCE(t.illustrator, ''),
		 COALESCE(t.movie, ''), COALESCE(t.source, ''), COALESCE(t.lyrics, ''), COALESCE(t.comment, ''),
		 COALESCE(a.album_artist, '')
		 FROM favorites f
		 INNER JOIN tracks t ON t.id = f.track_id
		 LEFT JOIN albums a ON t.album_id = a.id
		 ORDER BY f.created_at DESC`,
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

// --- Playlists (stub, populated in later tasks) ---

// Playlist is the metadata envelope for a user-created playlist.
type Playlist struct {
	ID            int64   `json:"id"`
	Name          string  `json:"name"`
	CoverPath     string  `json:"cover_path,omitempty"`
	TrackCount    int     `json:"track_count"`
	CoverTrackIDs []int64 `json:"cover_track_ids,omitempty"`
	CreatedAt     int64   `json:"created_at"`
	UpdatedAt     int64   `json:"updated_at"`
}

// Compile-time guard against unused imports until later tasks.
var _ = fmt.Sprintf
var _ = strings.TrimSpace
