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

// --- Playlists ---

// Playlist is the metadata envelope for a user-created playlist.
type Playlist struct {
	ID             int64   `json:"id"`
	Name           string  `json:"name"`
	CoverPath      string  `json:"cover_path,omitempty"`
	TrackCount     int     `json:"track_count"`
	CoverTrackIDs  []int64 `json:"cover_track_ids,omitempty"`
	CoverAlbumIDs  []int64 `json:"cover_album_ids,omitempty"`
	CreatedAt      int64   `json:"created_at"`
	UpdatedAt      int64   `json:"updated_at"`
}

// ErrInvalidName is returned when a playlist name is empty or too long.
var ErrInvalidName = errors.New("invalid name")

// normalizeName trims whitespace and validates a playlist name.
func normalizeName(name string) (string, error) {
	n := strings.TrimSpace(name)
	if n == "" {
		return "", ErrInvalidName
	}
	if len(n) > 200 {
		return "", ErrInvalidName
	}
	return n, nil
}

// CreatePlaylist inserts a new playlist with the given name. Returns the new playlist ID.
func (s *Store) CreatePlaylist(name string) (int64, error) {
	n, err := normalizeName(name)
	if err != nil {
		return 0, err
	}
	now := time.Now().Unix()
	res, err := s.db.Exec(
		`INSERT INTO playlists (name, created_at, updated_at) VALUES (?, ?, ?)`,
		n, now, now,
	)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

// RenamePlaylist updates the name of a playlist. Returns sql.ErrNoRows if not found.
func (s *Store) RenamePlaylist(id int64, name string) error {
	n, err := normalizeName(name)
	if err != nil {
		return err
	}
	now := time.Now().Unix()
	res, err := s.db.Exec(
		`UPDATE playlists SET name = ?, updated_at = ? WHERE id = ?`,
		n, now, id,
	)
	if err != nil {
		return err
	}
	rows, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return sql.ErrNoRows
	}
	return nil
}

// DeletePlaylist removes a playlist by ID. Cascade deletes playlist_tracks. Returns sql.ErrNoRows if not found.
func (s *Store) DeletePlaylist(id int64) error {
	res, err := s.db.Exec(`DELETE FROM playlists WHERE id = ?`, id)
	if err != nil {
		return err
	}
	rows, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return sql.ErrNoRows
	}
	return nil
}

// SetPlaylistCover sets the cover_path for a playlist.
func (s *Store) SetPlaylistCover(id int64, coverPath string) error {
	now := time.Now().Unix()
	res, err := s.db.Exec(
		`UPDATE playlists SET cover_path = ?, updated_at = ? WHERE id = ?`,
		coverPath, now, id,
	)
	if err != nil {
		return err
	}
	rows, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return sql.ErrNoRows
	}
	return nil
}

// ClearPlaylistCover resets cover_path to empty for a playlist.
func (s *Store) ClearPlaylistCover(id int64) error {
	return s.SetPlaylistCover(id, "")
}

// firstNTrackIDs returns the first N track IDs and their album IDs from a playlist ordered by position.
func (s *Store) firstNTrackIDs(playlistID int64, n int) (trackIDs []int64, albumIDs []int64, err error) {
	rows, err := s.db.Query(
		`SELECT pt.track_id, COALESCE(t.album_id, 0)
		 FROM playlist_tracks pt
		 LEFT JOIN tracks t ON t.id = pt.track_id
		 WHERE pt.playlist_id = ?
		 ORDER BY pt.position
		 LIMIT ?`,
		playlistID, n,
	)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var trackID, albumID int64
		if err := rows.Scan(&trackID, &albumID); err != nil {
			return nil, nil, err
		}
		trackIDs = append(trackIDs, trackID)
		albumIDs = append(albumIDs, albumID)
	}
	return trackIDs, albumIDs, rows.Err()
}

// scanPlaylist reads a playlist row and populates CoverTrackIDs and CoverAlbumIDs.
func (s *Store) scanPlaylist(p *Playlist) error {
	trackIDs, albumIDs, err := s.firstNTrackIDs(p.ID, 4)
	if err != nil {
		return err
	}
	p.CoverTrackIDs = trackIDs
	p.CoverAlbumIDs = albumIDs
	return nil
}

// ListPlaylists returns all playlists ordered by updated_at DESC, with track count and cover track IDs.
func (s *Store) ListPlaylists() ([]Playlist, error) {
	rows, err := s.db.Query(`
		SELECT p.id, p.name, p.cover_path, p.created_at, p.updated_at,
		       COUNT(pt.track_id) AS track_count
		FROM playlists p
		LEFT JOIN playlist_tracks pt ON pt.playlist_id = p.id
		GROUP BY p.id
		ORDER BY p.updated_at DESC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Playlist
	for rows.Next() {
		var p Playlist
		if err := rows.Scan(&p.ID, &p.Name, &p.CoverPath, &p.CreatedAt, &p.UpdatedAt, &p.TrackCount); err != nil {
			return nil, err
		}
		if err := s.scanPlaylist(&p); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

// GetPlaylistByID returns a single playlist by ID with track count and cover track IDs.
func (s *Store) GetPlaylistByID(id int64) (Playlist, bool, error) {
	var p Playlist
	err := s.db.QueryRow(`
		SELECT p.id, p.name, p.cover_path, p.created_at, p.updated_at,
		       COUNT(pt.track_id) AS track_count
		FROM playlists p
		LEFT JOIN playlist_tracks pt ON pt.playlist_id = p.id
		WHERE p.id = ?
		GROUP BY p.id
	`, id).Scan(&p.ID, &p.Name, &p.CoverPath, &p.CreatedAt, &p.UpdatedAt, &p.TrackCount)
	if err == sql.ErrNoRows {
		return Playlist{}, false, nil
	}
	if err != nil {
		return Playlist{}, false, err
	}
	if err := s.scanPlaylist(&p); err != nil {
		return Playlist{}, false, err
	}
	return p, true, nil
}

// --- Playlist Tracks ---

// GetPlaylistTracks returns the tracks in a playlist ordered by position.
func (s *Store) GetPlaylistTracks(playlistID int64) ([]Track, error) {
	rows, err := s.db.Query(
		`SELECT t.id, t.title, t.audio_path, t.video_path, COALESCE(t.video_thumb_path, ''), COALESCE(t.album_id, 0),
		 COALESCE(t.disc_number, 1), COALESCE(t.track_number, 0), COALESCE(t.artists, ''), COALESCE(t.year, 0),
		 COALESCE(t.duration_seconds, 0), COALESCE(t.format, ''), COALESCE(t.composer, ''), COALESCE(t.lyricist, ''),
		 COALESCE(t.arranger, ''), COALESCE(t.vocal, ''), COALESCE(t.voice_manipulator, ''), COALESCE(t.illustrator, ''),
		 COALESCE(t.movie, ''), COALESCE(t.source, ''), COALESCE(t.lyrics, ''), COALESCE(t.comment, ''),
		 COALESCE(a.album_artist, '')
		 FROM playlist_tracks pt
		 INNER JOIN tracks t ON t.id = pt.track_id
		 LEFT JOIN albums a ON t.album_id = a.id
		 WHERE pt.playlist_id = ?
		 ORDER BY pt.position`,
		playlistID,
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

// AddTracksToPlaylist appends tracks to a playlist, skipping duplicates.
// Returns the number of actually inserted rows.
func (s *Store) AddTracksToPlaylist(playlistID int64, trackIDs []int64) (int, error) {
	if len(trackIDs) == 0 {
		return 0, nil
	}

	tx, err := s.db.Begin()
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()

	// Dedupe input, preserving order
	seen := make(map[int64]bool)
	var unique []int64
	for _, id := range trackIDs {
		if !seen[id] {
			seen[id] = true
			unique = append(unique, id)
		}
	}

	// Get current max position
	var maxPos sql.NullInt64
	err = tx.QueryRow(
		`SELECT MAX(position) FROM playlist_tracks WHERE playlist_id = ?`,
		playlistID,
	).Scan(&maxPos)
	if err != nil {
		return 0, err
	}
	nextPos := int64(0)
	if maxPos.Valid {
		nextPos = maxPos.Int64 + 1
	}

	now := time.Now().Unix()
	added := 0
	for _, tid := range unique {
		// Verify track exists
		var exists int
		err := tx.QueryRow(`SELECT 1 FROM tracks WHERE id = ?`, tid).Scan(&exists)
		if err == sql.ErrNoRows {
			continue // skip non-existent tracks
		}
		if err != nil {
			return 0, err
		}

		// Try to insert; skip if already present (PRIMARY KEY conflict)
		res, err := tx.Exec(
			`INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position, added_at) VALUES (?, ?, ?, ?)`,
			playlistID, tid, nextPos, now,
		)
		if err != nil {
			return 0, err
		}
		rows, err := res.RowsAffected()
		if err != nil {
			return 0, err
		}
		if rows > 0 {
			added++
			nextPos++
		}
	}

	// Update playlist updated_at
	if added > 0 {
		if _, err := tx.Exec(`UPDATE playlists SET updated_at = ? WHERE id = ?`, now, playlistID); err != nil {
			return 0, err
		}
	}

	if err := tx.Commit(); err != nil {
		return 0, err
	}
	return added, nil
}

// RemoveTracksFromPlaylist deletes specified tracks from a playlist and rebalances positions.
func (s *Store) RemoveTracksFromPlaylist(playlistID int64, trackIDs []int64) error {
	if len(trackIDs) == 0 {
		return nil
	}

	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Delete specified tracks
	placeholders := make([]string, len(trackIDs))
	args := make([]any, 0, len(trackIDs)+1)
	args = append(args, playlistID)
	for i, tid := range trackIDs {
		placeholders[i] = "?"
		args = append(args, tid)
	}
	query := `DELETE FROM playlist_tracks WHERE playlist_id = ? AND track_id IN (` + strings.Join(placeholders, ",") + `)`
	if _, err := tx.Exec(query, args...); err != nil {
		return err
	}

	// Rebalance positions
	if err := rebalancePositionsTx(tx, playlistID); err != nil {
		return err
	}

	// Update playlist updated_at
	now := time.Now().Unix()
	if _, err := tx.Exec(`UPDATE playlists SET updated_at = ? WHERE id = ?`, now, playlistID); err != nil {
		return err
	}

	return tx.Commit()
}

// ReorderPlaylist sets new positions for all tracks in a playlist.
// orderedTrackIDs must be exactly the same set as current playlist tracks.
func (s *Store) ReorderPlaylist(playlistID int64, orderedTrackIDs []int64) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Get current track IDs
	rows, err := tx.Query(
		`SELECT track_id FROM playlist_tracks WHERE playlist_id = ? ORDER BY position`,
		playlistID,
	)
	if err != nil {
		return err
	}
	currentSet := make(map[int64]bool)
	for rows.Next() {
		var tid int64
		if err := rows.Scan(&tid); err != nil {
			rows.Close()
			return err
		}
		currentSet[tid] = true
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return err
	}

	// Validate: orderedTrackIDs must be same set as currentSet (no dups, same cardinality)
	if len(orderedTrackIDs) != len(currentSet) {
		return fmt.Errorf("reorder set mismatch: have %d tracks, got %d ids", len(currentSet), len(orderedTrackIDs))
	}
	newSet := make(map[int64]bool)
	for _, tid := range orderedTrackIDs {
		if newSet[tid] {
			return fmt.Errorf("reorder set mismatch: duplicate id %d", tid)
		}
		if !currentSet[tid] {
			return fmt.Errorf("reorder set mismatch: unknown id %d", tid)
		}
		newSet[tid] = true
	}

	// Update positions
	for i, tid := range orderedTrackIDs {
		if _, err := tx.Exec(
			`UPDATE playlist_tracks SET position = ? WHERE playlist_id = ? AND track_id = ?`,
			i, playlistID, tid,
		); err != nil {
			return err
		}
	}

	// Update playlist updated_at
	now := time.Now().Unix()
	if _, err := tx.Exec(`UPDATE playlists SET updated_at = ? WHERE id = ?`, now, playlistID); err != nil {
		return err
	}

	return tx.Commit()
}

// rebalancePositionsTx rewrites positions to 0..N-1 in current order within a transaction.
func rebalancePositionsTx(tx *sql.Tx, playlistID int64) error {
	rows, err := tx.Query(
		`SELECT track_id FROM playlist_tracks WHERE playlist_id = ? ORDER BY position`,
		playlistID,
	)
	if err != nil {
		return err
	}
	var trackIDs []int64
	for rows.Next() {
		var tid int64
		if err := rows.Scan(&tid); err != nil {
			rows.Close()
			return err
		}
		trackIDs = append(trackIDs, tid)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return err
	}

	for i, tid := range trackIDs {
		if _, err := tx.Exec(
			`UPDATE playlist_tracks SET position = ? WHERE playlist_id = ? AND track_id = ?`,
			i, playlistID, tid,
		); err != nil {
			return err
		}
	}
	return nil
}
