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
		`SELECT ` + trackSelectColumns("t", "a") + `
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
		t, err := scanTrack(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// --- Playlists ---

// Playlist is the metadata envelope for a user-created playlist.
type Playlist struct {
	ID            int64   `json:"id"`
	Name          string  `json:"name"`
	CoverPath     string  `json:"cover_path,omitempty"`
	TrackCount    int     `json:"track_count"`
	CoverTrackIDs []int64 `json:"cover_track_ids,omitempty"`
	CoverAlbumIDs []int64 `json:"cover_album_ids,omitempty"`
	CreatedAt     int64   `json:"created_at"`
	UpdatedAt     int64   `json:"updated_at"`
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

func playlistNow() int64 {
	return time.Now().UnixNano()
}

// PlaylistGroup represents a visual section inside a playlist.
type PlaylistGroup struct {
	ID         int64  `json:"id"`
	PlaylistID int64  `json:"playlist_id"`
	Title      string `json:"title"`
	Position   int    `json:"position"`
	IsSystem   bool   `json:"is_system"`
	CreatedAt  int64  `json:"created_at"`
	UpdatedAt  int64  `json:"updated_at"`
}

// PlaylistItem stores playlist-local metadata for a track entry.
type PlaylistItem struct {
	ID              int64  `json:"id"`
	PlaylistID      int64  `json:"playlist_id"`
	TrackID         int64  `json:"track_id"`
	GroupID         int64  `json:"group_id"`
	Position        int    `json:"position"`
	Note            string `json:"note"`
	CoverMode       string `json:"cover_mode"`
	LibraryCoverID  string `json:"library_cover_id"`
	CachedCoverURL  string `json:"cached_cover_url"`
	CustomCoverPath string `json:"custom_cover_path"`
	CreatedAt       int64  `json:"created_at"`
	UpdatedAt       int64  `json:"updated_at"`
	Track           Track  `json:"track"`
}

// PlaylistGroupDetail includes the items belonging to a playlist group.
type PlaylistGroupDetail struct {
	PlaylistGroup
	Items []PlaylistItem `json:"items"`
}

// PlaylistDetail is the grouped playlist read model used by the API and tests.
type PlaylistDetail struct {
	Playlist Playlist              `json:"playlist"`
	Groups   []PlaylistGroupDetail `json:"groups"`
}

// PlaylistGroupOrder defines a grouped reorder payload.
type PlaylistGroupOrder struct {
	GroupID int64
	ItemIDs []int64
}

// PlaylistItemUpdate updates playlist-local metadata on an item.
type PlaylistItemUpdate struct {
	GroupID         *int64
	Position        *int
	Note            *string
	CoverMode       *string
	LibraryCoverID  *string
	CachedCoverURL  *string
	CustomCoverPath *string
}

// ErrSystemPlaylistGroup is returned when callers try to delete the system group.
var ErrSystemPlaylistGroup = errors.New("system playlist group")

// CreatePlaylist inserts a new playlist and its default Ungrouped group.
func (s *Store) CreatePlaylist(name string) (int64, error) {
	n, err := normalizeName(name)
	if err != nil {
		return 0, err
	}

	now := playlistNow()
	tx, err := s.db.Begin()
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()

	res, err := tx.Exec(
		`INSERT INTO playlists (name, created_at, updated_at) VALUES (?, ?, ?)`,
		n, now, now,
	)
	if err != nil {
		return 0, err
	}
	playlistID, err := res.LastInsertId()
	if err != nil {
		return 0, err
	}
	if _, err := tx.Exec(
		`INSERT INTO playlist_groups (playlist_id, title, position, is_system, created_at, updated_at)
		 VALUES (?, 'Ungrouped', 0, 1, ?, ?)`,
		playlistID, now, now,
	); err != nil {
		return 0, err
	}
	if err := tx.Commit(); err != nil {
		return 0, err
	}
	return playlistID, nil
}

// RenamePlaylist updates the name of a playlist. Returns sql.ErrNoRows if not found.
func (s *Store) RenamePlaylist(id int64, name string) error {
	n, err := normalizeName(name)
	if err != nil {
		return err
	}
	now := playlistNow()
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
	now := playlistNow()
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

type sqlQueryer interface {
	Query(string, ...any) (*sql.Rows, error)
	QueryRow(string, ...any) *sql.Row
}

// firstNTrackIDs returns the first N track IDs and their album IDs from a playlist
// ordered by group position then item position.
func (s *Store) firstNTrackIDs(playlistID int64, n int) (trackIDs []int64, albumIDs []int64, err error) {
	return firstNTrackIDsWithQueryer(s.db, playlistID, n)
}

func firstNTrackIDsWithQueryer(queryer sqlQueryer, playlistID int64, n int) (trackIDs []int64, albumIDs []int64, err error) {
	rows, err := queryer.Query(
		`SELECT pi.track_id, COALESCE(t.album_id, 0)
		 FROM playlist_items pi
		 INNER JOIN playlist_groups pg ON pg.id = pi.group_id
		 LEFT JOIN tracks t ON t.id = pi.track_id
		 WHERE pi.playlist_id = ?
		 ORDER BY pg.position, pi.position
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
	return scanPlaylistWithQueryer(s.db, p)
}

func scanPlaylistWithQueryer(queryer sqlQueryer, p *Playlist) error {
	trackIDs, albumIDs, err := firstNTrackIDsWithQueryer(queryer, p.ID, 4)
	if err != nil {
		return err
	}
	p.CoverTrackIDs = trackIDs
	p.CoverAlbumIDs = albumIDs
	return nil
}

// ListPlaylists returns all playlists ordered by updated_at DESC, with track count and cover track IDs.
func (s *Store) ListPlaylists() ([]Playlist, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	rows, err := tx.Query(`
		SELECT p.id, p.name, p.cover_path, p.created_at, p.updated_at,
		       COUNT(pi.id) AS track_count
		FROM playlists p
		LEFT JOIN playlist_items pi ON pi.playlist_id = p.id
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
		if err := scanPlaylistWithQueryer(tx, &p); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return out, nil
}

// GetPlaylistByID returns a single playlist by ID with track count and cover track IDs.
func (s *Store) GetPlaylistByID(id int64) (Playlist, bool, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return Playlist{}, false, err
	}
	defer tx.Rollback()

	p, ok, err := getPlaylistByIDWithQueryer(tx, id)
	if err != nil || !ok {
		return Playlist{}, ok, err
	}
	if err := tx.Commit(); err != nil {
		return Playlist{}, false, err
	}
	return p, true, nil
}

func getPlaylistByIDWithQueryer(queryer sqlQueryer, id int64) (Playlist, bool, error) {
	var p Playlist
	err := queryer.QueryRow(`
		SELECT p.id, p.name, p.cover_path, p.created_at, p.updated_at,
		       COUNT(pi.id) AS track_count
		FROM playlists p
		LEFT JOIN playlist_items pi ON pi.playlist_id = p.id
		WHERE p.id = ?
		GROUP BY p.id
	`, id).Scan(&p.ID, &p.Name, &p.CoverPath, &p.CreatedAt, &p.UpdatedAt, &p.TrackCount)
	if err == sql.ErrNoRows {
		return Playlist{}, false, nil
	}
	if err != nil {
		return Playlist{}, false, err
	}
	if err := scanPlaylistWithQueryer(queryer, &p); err != nil {
		return Playlist{}, false, err
	}
	return p, true, nil
}

// GetPlaylistDetail returns grouped playlist data with embedded track metadata.
func (s *Store) GetPlaylistDetail(id int64) (PlaylistDetail, bool, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return PlaylistDetail{}, false, err
	}
	defer tx.Rollback()

	playlist, ok, err := getPlaylistByIDWithQueryer(tx, id)
	if err != nil || !ok {
		return PlaylistDetail{}, ok, err
	}

	groupRows, err := tx.Query(
		`SELECT id, playlist_id, title, position, is_system, created_at, updated_at
		 FROM playlist_groups
		 WHERE playlist_id = ?
		 ORDER BY position`,
		id,
	)
	if err != nil {
		return PlaylistDetail{}, false, err
	}
	defer groupRows.Close()

	detail := PlaylistDetail{Playlist: playlist}
	groupIndex := make(map[int64]int)
	for groupRows.Next() {
		var group PlaylistGroupDetail
		var isSystem int
		if err := groupRows.Scan(
			&group.ID,
			&group.PlaylistID,
			&group.Title,
			&group.Position,
			&isSystem,
			&group.CreatedAt,
			&group.UpdatedAt,
		); err != nil {
			return PlaylistDetail{}, false, err
		}
		group.IsSystem = isSystem != 0
		groupIndex[group.ID] = len(detail.Groups)
		detail.Groups = append(detail.Groups, group)
	}
	if err := groupRows.Err(); err != nil {
		return PlaylistDetail{}, false, err
	}

	itemRows, err := tx.Query(
		`SELECT pi.id, pi.playlist_id, pi.track_id, pi.group_id, pi.position, pi.note,
		        pi.cover_mode, pi.library_cover_id, pi.cached_cover_url, pi.custom_cover_path,
		        pi.created_at, pi.updated_at,
		        `+trackSelectColumns("t", "a")+`
		 FROM playlist_items pi
		 INNER JOIN playlist_groups pg ON pg.id = pi.group_id
		 INNER JOIN tracks t ON t.id = pi.track_id
		 LEFT JOIN albums a ON t.album_id = a.id
		 WHERE pi.playlist_id = ?
		 ORDER BY pg.position, pi.position`,
		id,
	)
	if err != nil {
		return PlaylistDetail{}, false, err
	}
	defer itemRows.Close()

	for itemRows.Next() {
		var item PlaylistItem
		dest := []any{
			&item.ID,
			&item.PlaylistID,
			&item.TrackID,
			&item.GroupID,
			&item.Position,
			&item.Note,
			&item.CoverMode,
			&item.LibraryCoverID,
			&item.CachedCoverURL,
			&item.CustomCoverPath,
			&item.CreatedAt,
			&item.UpdatedAt,
		}
		dest = append(dest, trackScanDest(&item.Track)...)
		if err := itemRows.Scan(dest...); err != nil {
			return PlaylistDetail{}, false, err
		}
		idx, exists := groupIndex[item.GroupID]
		if !exists {
			return PlaylistDetail{}, false, fmt.Errorf("playlist item %d references unknown group %d", item.ID, item.GroupID)
		}
		detail.Groups[idx].Items = append(detail.Groups[idx].Items, item)
	}
	if err := itemRows.Err(); err != nil {
		return PlaylistDetail{}, false, err
	}
	if err := tx.Commit(); err != nil {
		return PlaylistDetail{}, false, err
	}
	return detail, true, nil
}

// --- Playlist Tracks ---

// GetPlaylistTracks returns the tracks in a playlist ordered by group position
// then item position.
func (s *Store) GetPlaylistTracks(playlistID int64) ([]Track, error) {
	rows, err := s.db.Query(
		`SELECT `+trackSelectColumns("t", "a")+`
		 FROM playlist_items pi
		 INNER JOIN playlist_groups pg ON pg.id = pi.group_id
		 INNER JOIN tracks t ON t.id = pi.track_id
		 LEFT JOIN albums a ON t.album_id = a.id
		 WHERE pi.playlist_id = ?
		 ORDER BY pg.position, pi.position`,
		playlistID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Track
	for rows.Next() {
		t, err := scanTrack(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// AddTracksToPlaylist appends track items into the system Ungrouped section.
func (s *Store) AddTracksToPlaylist(playlistID int64, trackIDs []int64) (int, error) {
	if len(trackIDs) == 0 {
		return 0, nil
	}

	tx, err := s.db.Begin()
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()

	ungroupedID, err := lookupSystemGroupIDTx(tx, playlistID)
	if err != nil {
		return 0, err
	}

	var maxPos sql.NullInt64
	if err := tx.QueryRow(
		`SELECT MAX(position) FROM playlist_items WHERE group_id = ?`,
		ungroupedID,
	).Scan(&maxPos); err != nil {
		return 0, err
	}
	nextPos := int64(0)
	if maxPos.Valid {
		nextPos = maxPos.Int64 + 1
	}

	now := playlistNow()
	added := 0
	for _, tid := range trackIDs {
		var exists int
		err := tx.QueryRow(`SELECT 1 FROM tracks WHERE id = ?`, tid).Scan(&exists)
		if err == sql.ErrNoRows {
			continue
		}
		if err != nil {
			return 0, err
		}

		if _, err := tx.Exec(
			`INSERT INTO playlist_items
			 (playlist_id, track_id, group_id, position, created_at, updated_at)
			 VALUES (?, ?, ?, ?, ?, ?)`,
			playlistID, tid, ungroupedID, nextPos, now, now,
		); err != nil {
			return 0, err
		}
		added++
		nextPos++
	}

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

// RemoveTracksFromPlaylist deletes all playlist items whose track IDs match.
func (s *Store) RemoveTracksFromPlaylist(playlistID int64, trackIDs []int64) error {
	if len(trackIDs) == 0 {
		return nil
	}

	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var exists int
	if err := tx.QueryRow(`SELECT 1 FROM playlists WHERE id = ?`, playlistID).Scan(&exists); err != nil {
		if err == sql.ErrNoRows {
			return sql.ErrNoRows
		}
		return err
	}

	placeholders := make([]string, len(trackIDs))
	args := make([]any, 0, len(trackIDs)+1)
	args = append(args, playlistID)
	for i, tid := range trackIDs {
		placeholders[i] = "?"
		args = append(args, tid)
	}
	query := `DELETE FROM playlist_items WHERE playlist_id = ? AND track_id IN (` + strings.Join(placeholders, ",") + `)`
	if _, err := tx.Exec(query, args...); err != nil {
		return err
	}

	if err := rebalancePlaylistItemPositionsTx(tx, playlistID); err != nil {
		return err
	}

	now := playlistNow()
	if _, err := tx.Exec(`UPDATE playlists SET updated_at = ? WHERE id = ?`, now, playlistID); err != nil {
		return err
	}

	return tx.Commit()
}

// ReorderPlaylist preserves the old flat API by reordering items inside the
// current Ungrouped section when a playlist has no custom groups in use.
func (s *Store) ReorderPlaylist(playlistID int64, orderedTrackIDs []int64) error {
	detail, ok, err := s.GetPlaylistDetail(playlistID)
	if err != nil {
		return err
	}
	if !ok {
		return sql.ErrNoRows
	}

	group := detail.Groups[0]
	for _, currentGroup := range detail.Groups[1:] {
		if len(currentGroup.Items) > 0 {
			return fmt.Errorf("flat reorder unsupported once playlist has items outside Ungrouped")
		}
	}

	if len(orderedTrackIDs) != len(group.Items) {
		return fmt.Errorf("reorder set mismatch: have %d tracks, got %d ids", len(group.Items), len(orderedTrackIDs))
	}

	itemQueues := make(map[int64][]int64)
	for _, item := range group.Items {
		itemQueues[item.TrackID] = append(itemQueues[item.TrackID], item.ID)
	}
	var itemIDs []int64
	for _, trackID := range orderedTrackIDs {
		queue := itemQueues[trackID]
		if len(queue) == 0 {
			return fmt.Errorf("reorder set mismatch: unknown id %d", trackID)
		}
		itemIDs = append(itemIDs, queue[0])
		itemQueues[trackID] = queue[1:]
	}

	order := make([]PlaylistGroupOrder, 0, len(detail.Groups))
	for idx, currentGroup := range detail.Groups {
		groupOrder := PlaylistGroupOrder{GroupID: currentGroup.ID}
		if idx == 0 {
			groupOrder.ItemIDs = itemIDs
		}
		order = append(order, groupOrder)
	}
	return s.ReorderPlaylistItems(playlistID, order)
}

// ReorderPlaylistItems rewrites group order and item order within each group.
func (s *Store) ReorderPlaylistItems(playlistID int64, order []PlaylistGroupOrder) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	now := playlistNow()
	if err := reorderPlaylistItemsTx(tx, playlistID, order, now); err != nil {
		return err
	}
	return tx.Commit()
}

func reorderPlaylistItemsTx(tx *sql.Tx, playlistID int64, order []PlaylistGroupOrder, now int64) error {
	groups, err := listPlaylistGroupsTx(tx, playlistID)
	if err != nil {
		return err
	}
	if len(groups) == 0 {
		return sql.ErrNoRows
	}
	if len(order) != len(groups) {
		return fmt.Errorf("reorder group mismatch: have %d groups, got %d", len(groups), len(order))
	}

	groupByID := make(map[int64]PlaylistGroup, len(groups))
	for _, group := range groups {
		groupByID[group.ID] = group
	}

	seenGroups := make(map[int64]bool, len(order))
	for _, groupOrder := range order {
		_, ok := groupByID[groupOrder.GroupID]
		if !ok {
			return fmt.Errorf("reorder group mismatch: unknown group %d", groupOrder.GroupID)
		}
		if seenGroups[groupOrder.GroupID] {
			return fmt.Errorf("reorder group mismatch: duplicate group %d", groupOrder.GroupID)
		}
		seenGroups[groupOrder.GroupID] = true
	}

	rows, err := tx.Query(`SELECT id FROM playlist_items WHERE playlist_id = ?`, playlistID)
	if err != nil {
		return err
	}
	defer rows.Close()

	currentItems := make(map[int64]bool)
	itemCount := 0
	for rows.Next() {
		var itemID int64
		if err := rows.Scan(&itemID); err != nil {
			return err
		}
		currentItems[itemID] = true
		itemCount++
	}
	if err := rows.Err(); err != nil {
		return err
	}

	payloadItems := make(map[int64]bool, itemCount)
	seenItemCount := 0
	for _, groupOrder := range order {
		for _, itemID := range groupOrder.ItemIDs {
			if payloadItems[itemID] {
				return fmt.Errorf("reorder set mismatch: duplicate item %d", itemID)
			}
			if !currentItems[itemID] {
				return fmt.Errorf("reorder set mismatch: unknown item %d", itemID)
			}
			payloadItems[itemID] = true
			seenItemCount++
		}
	}
	if seenItemCount != itemCount {
		return fmt.Errorf("reorder set mismatch: have %d items, got %d ids", itemCount, seenItemCount)
	}

	if _, err := tx.Exec(
		`UPDATE playlist_groups SET position = -position - 1, updated_at = ? WHERE playlist_id = ?`,
		now, playlistID,
	); err != nil {
		return err
	}
	if _, err := tx.Exec(
		`UPDATE playlist_items SET position = -position - 1, updated_at = ? WHERE playlist_id = ?`,
		now, playlistID,
	); err != nil {
		return err
	}

	for groupPos, groupOrder := range order {
		if _, err := tx.Exec(
			`UPDATE playlist_groups SET position = ?, updated_at = ? WHERE id = ? AND playlist_id = ?`,
			groupPos, now, groupOrder.GroupID, playlistID,
		); err != nil {
			return err
		}
		for itemPos, itemID := range groupOrder.ItemIDs {
			if _, err := tx.Exec(
				`UPDATE playlist_items
				 SET group_id = ?, position = ?, updated_at = ?
				 WHERE id = ? AND playlist_id = ?`,
				groupOrder.GroupID, itemPos, now, itemID, playlistID,
			); err != nil {
				return err
			}
		}
	}
	if _, err := tx.Exec(`UPDATE playlists SET updated_at = ? WHERE id = ?`, now, playlistID); err != nil {
		return err
	}
	return nil
}

// CreatePlaylistGroup appends a new user-defined group to a playlist.
func (s *Store) CreatePlaylistGroup(playlistID int64, title string) (int64, error) {
	n, err := normalizeName(title)
	if err != nil {
		return 0, err
	}

	tx, err := s.db.Begin()
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()

	var exists int
	if err := tx.QueryRow(`SELECT 1 FROM playlists WHERE id = ?`, playlistID).Scan(&exists); err != nil {
		if err == sql.ErrNoRows {
			return 0, sql.ErrNoRows
		}
		return 0, err
	}

	var maxPos sql.NullInt64
	if err := tx.QueryRow(
		`SELECT MAX(position) FROM playlist_groups WHERE playlist_id = ?`,
		playlistID,
	).Scan(&maxPos); err != nil {
		return 0, err
	}
	nextPos := int64(1)
	if maxPos.Valid {
		nextPos = maxPos.Int64 + 1
	}
	now := playlistNow()
	res, err := tx.Exec(
		`INSERT INTO playlist_groups (playlist_id, title, position, is_system, created_at, updated_at)
		 VALUES (?, ?, ?, 0, ?, ?)`,
		playlistID, n, nextPos, now, now,
	)
	if err != nil {
		return 0, err
	}
	if _, err := tx.Exec(`UPDATE playlists SET updated_at = ? WHERE id = ?`, now, playlistID); err != nil {
		return 0, err
	}
	groupID, err := res.LastInsertId()
	if err != nil {
		return 0, err
	}
	if err := tx.Commit(); err != nil {
		return 0, err
	}
	return groupID, nil
}

// RenamePlaylistGroup renames a playlist group, including the system group.
func (s *Store) RenamePlaylistGroup(groupID int64, title string) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	group, err := getPlaylistGroupTx(tx, groupID)
	if err != nil {
		return err
	}
	n, err := normalizeName(title)
	if err != nil {
		return err
	}
	now := playlistNow()
	res, err := tx.Exec(
		`UPDATE playlist_groups SET title = ?, updated_at = ? WHERE id = ?`,
		n, now, groupID,
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
	if _, err := tx.Exec(`UPDATE playlists SET updated_at = ? WHERE id = ?`, now, group.PlaylistID); err != nil {
		return err
	}
	return tx.Commit()
}

// DeletePlaylistGroup deletes a non-system group and moves its items to Ungrouped.
func (s *Store) DeletePlaylistGroup(groupID int64) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	group, err := getPlaylistGroupTx(tx, groupID)
	if err != nil {
		return err
	}
	if group.IsSystem {
		return ErrSystemPlaylistGroup
	}

	ungroupedID, err := lookupSystemGroupIDTx(tx, group.PlaylistID)
	if err != nil {
		return err
	}

	var maxPos sql.NullInt64
	if err := tx.QueryRow(
		`SELECT MAX(position) FROM playlist_items WHERE group_id = ?`,
		ungroupedID,
	).Scan(&maxPos); err != nil {
		return err
	}
	nextPos := int64(0)
	if maxPos.Valid {
		nextPos = maxPos.Int64 + 1
	}

	rows, err := tx.Query(
		`SELECT id FROM playlist_items WHERE group_id = ? ORDER BY position`,
		groupID,
	)
	if err != nil {
		return err
	}
	var itemIDs []int64
	for rows.Next() {
		var itemID int64
		if err := rows.Scan(&itemID); err != nil {
			rows.Close()
			return err
		}
		itemIDs = append(itemIDs, itemID)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return err
	}

	now := playlistNow()
	for _, itemID := range itemIDs {
		if _, err := tx.Exec(
			`UPDATE playlist_items
			 SET group_id = ?, position = ?, updated_at = ?
			 WHERE id = ?`,
			ungroupedID, nextPos, now, itemID,
		); err != nil {
			return err
		}
		nextPos++
	}
	res, err := tx.Exec(`DELETE FROM playlist_groups WHERE id = ?`, groupID)
	if err != nil {
		return err
	}
	rowsAffected, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if rowsAffected == 0 {
		return sql.ErrNoRows
	}
	if err := rebalancePlaylistGroupPositionsTx(tx, group.PlaylistID); err != nil {
		return err
	}
	if _, err := tx.Exec(`UPDATE playlists SET updated_at = ? WHERE id = ?`, now, group.PlaylistID); err != nil {
		return err
	}
	return tx.Commit()
}

// UpdatePlaylistItem updates playlist-local item metadata and optional placement.
func (s *Store) UpdatePlaylistItem(itemID int64, update PlaylistItemUpdate) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	item, err := getPlaylistItemTx(tx, itemID)
	if err != nil {
		return err
	}

	note := item.Note
	coverMode := item.CoverMode
	libraryCoverID := item.LibraryCoverID
	cachedCoverURL := item.CachedCoverURL
	customCoverPath := item.CustomCoverPath

	if update.Note != nil {
		note = *update.Note
	}
	if update.CoverMode != nil {
		coverMode = *update.CoverMode
	}
	if update.LibraryCoverID != nil {
		libraryCoverID = *update.LibraryCoverID
	}
	if update.CachedCoverURL != nil {
		cachedCoverURL = *update.CachedCoverURL
	}
	if update.CustomCoverPath != nil {
		customCoverPath = *update.CustomCoverPath
	}

	targetGroupID := item.GroupID
	if update.GroupID != nil {
		targetGroupID = *update.GroupID
	}
	targetPosition := item.Position
	if update.Position != nil {
		targetPosition = *update.Position
	}

	now := playlistNow()
	if targetGroupID != item.GroupID || targetPosition != item.Position {
		targetGroup, err := getPlaylistGroupTx(tx, targetGroupID)
		if err != nil {
			return err
		}
		if targetGroup.PlaylistID != item.PlaylistID {
			return sql.ErrNoRows
		}

		groupOrders, err := loadPlaylistGroupOrdersTx(tx, item.PlaylistID)
		if err != nil {
			return err
		}

		sourceGroupIdx := -1
		targetGroupIdx := -1
		for groupIdx := range groupOrders {
			if groupOrders[groupIdx].GroupID == targetGroupID {
				targetGroupIdx = groupIdx
			}
			for itemIdx, currentItemID := range groupOrders[groupIdx].ItemIDs {
				if currentItemID != item.ID {
					continue
				}
				sourceGroupIdx = groupIdx
				groupOrders[groupIdx].ItemIDs = append(
					groupOrders[groupIdx].ItemIDs[:itemIdx],
					groupOrders[groupIdx].ItemIDs[itemIdx+1:]...,
				)
				break
			}
		}
		if sourceGroupIdx == -1 || targetGroupIdx == -1 {
			return sql.ErrNoRows
		}

		targetItems := groupOrders[targetGroupIdx].ItemIDs
		if update.GroupID != nil && update.Position == nil && targetGroupID != item.GroupID {
			targetPosition = len(targetItems)
		}
		if targetPosition < 0 {
			targetPosition = 0
		}
		if targetPosition > len(targetItems) {
			targetPosition = len(targetItems)
		}
		targetItems = append(targetItems, 0)
		copy(targetItems[targetPosition+1:], targetItems[targetPosition:])
		targetItems[targetPosition] = item.ID
		groupOrders[targetGroupIdx].ItemIDs = targetItems

		if err := reorderPlaylistItemsTx(tx, item.PlaylistID, groupOrders, now); err != nil {
			return err
		}
	}

	if _, err := tx.Exec(
		`UPDATE playlist_items
		 SET group_id = ?, position = ?, note = ?, cover_mode = ?, library_cover_id = ?, cached_cover_url = ?, custom_cover_path = ?, updated_at = ?
		 WHERE id = ?`,
		targetGroupID, targetPosition, note, coverMode, libraryCoverID, cachedCoverURL, customCoverPath, now, itemID,
	); err != nil {
		return err
	}
	if _, err := tx.Exec(`UPDATE playlists SET updated_at = ? WHERE id = ?`, now, item.PlaylistID); err != nil {
		return err
	}
	return tx.Commit()
}

func (s *Store) getPlaylistGroup(groupID int64) (PlaylistGroup, error) {
	return getPlaylistGroupTx(s.db, groupID)
}

func getPlaylistGroupTx(queryer interface {
	QueryRow(string, ...any) *sql.Row
}, groupID int64) (PlaylistGroup, error) {
	var group PlaylistGroup
	var isSystem int
	err := queryer.QueryRow(
		`SELECT id, playlist_id, title, position, is_system, created_at, updated_at
		 FROM playlist_groups
		 WHERE id = ?`,
		groupID,
	).Scan(
		&group.ID,
		&group.PlaylistID,
		&group.Title,
		&group.Position,
		&isSystem,
		&group.CreatedAt,
		&group.UpdatedAt,
	)
	if err != nil {
		return PlaylistGroup{}, err
	}
	group.IsSystem = isSystem != 0
	return group, nil
}

func (s *Store) getPlaylistItem(itemID int64) (PlaylistItem, error) {
	return getPlaylistItemTx(s.db, itemID)
}

func getPlaylistItemTx(queryer interface {
	QueryRow(string, ...any) *sql.Row
}, itemID int64) (PlaylistItem, error) {
	var item PlaylistItem
	err := queryer.QueryRow(
		`SELECT id, playlist_id, track_id, group_id, position, note, cover_mode,
		        library_cover_id, cached_cover_url, custom_cover_path, created_at, updated_at
		 FROM playlist_items
		 WHERE id = ?`,
		itemID,
	).Scan(
		&item.ID,
		&item.PlaylistID,
		&item.TrackID,
		&item.GroupID,
		&item.Position,
		&item.Note,
		&item.CoverMode,
		&item.LibraryCoverID,
		&item.CachedCoverURL,
		&item.CustomCoverPath,
		&item.CreatedAt,
		&item.UpdatedAt,
	)
	return item, err
}

func (s *Store) listPlaylistGroups(playlistID int64) ([]PlaylistGroup, error) {
	return listPlaylistGroupsTx(s.db, playlistID)
}

func listPlaylistGroupsTx(queryer interface {
	Query(string, ...any) (*sql.Rows, error)
}, playlistID int64) ([]PlaylistGroup, error) {
	rows, err := queryer.Query(
		`SELECT id, playlist_id, title, position, is_system, created_at, updated_at
		 FROM playlist_groups
		 WHERE playlist_id = ?
		 ORDER BY position`,
		playlistID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []PlaylistGroup
	for rows.Next() {
		var group PlaylistGroup
		var isSystem int
		if err := rows.Scan(
			&group.ID,
			&group.PlaylistID,
			&group.Title,
			&group.Position,
			&isSystem,
			&group.CreatedAt,
			&group.UpdatedAt,
		); err != nil {
			return nil, err
		}
		group.IsSystem = isSystem != 0
		out = append(out, group)
	}
	return out, rows.Err()
}

func (s *Store) lookupSystemGroupID(playlistID int64) (int64, error) {
	return lookupSystemGroupIDTx(s.db, playlistID)
}

func lookupSystemGroupIDTx(queryer interface {
	QueryRow(string, ...any) *sql.Row
}, playlistID int64) (int64, error) {
	var groupID int64
	err := queryer.QueryRow(
		`SELECT id FROM playlist_groups
		 WHERE playlist_id = ? AND is_system = 1
		 ORDER BY position
		 LIMIT 1`,
		playlistID,
	).Scan(&groupID)
	return groupID, err
}

func rebalancePlaylistGroupPositionsTx(tx *sql.Tx, playlistID int64) error {
	rows, err := tx.Query(
		`SELECT id FROM playlist_groups WHERE playlist_id = ? ORDER BY position`,
		playlistID,
	)
	if err != nil {
		return err
	}
	defer rows.Close()

	var groupIDs []int64
	for rows.Next() {
		var groupID int64
		if err := rows.Scan(&groupID); err != nil {
			return err
		}
		groupIDs = append(groupIDs, groupID)
	}
	if err := rows.Err(); err != nil {
		return err
	}
	for idx, groupID := range groupIDs {
		if _, err := tx.Exec(
			`UPDATE playlist_groups SET position = ? WHERE id = ?`,
			idx, groupID,
		); err != nil {
			return err
		}
	}
	return nil
}

func rebalancePlaylistItemPositionsTx(tx *sql.Tx, playlistID int64) error {
	rows, err := tx.Query(
		`SELECT id FROM playlist_groups WHERE playlist_id = ? ORDER BY position`,
		playlistID,
	)
	if err != nil {
		return err
	}
	defer rows.Close()

	var groupIDs []int64
	for rows.Next() {
		var groupID int64
		if err := rows.Scan(&groupID); err != nil {
			return err
		}
		groupIDs = append(groupIDs, groupID)
	}
	if err := rows.Err(); err != nil {
		return err
	}
	for _, groupID := range groupIDs {
		if err := rebalanceGroupItemsTx(tx, groupID); err != nil {
			return err
		}
	}
	return nil
}

func rebalanceGroupItemsTx(tx *sql.Tx, groupID int64) error {
	rows, err := tx.Query(
		`SELECT id FROM playlist_items WHERE group_id = ? ORDER BY position`,
		groupID,
	)
	if err != nil {
		return err
	}
	defer rows.Close()

	var itemIDs []int64
	for rows.Next() {
		var itemID int64
		if err := rows.Scan(&itemID); err != nil {
			return err
		}
		itemIDs = append(itemIDs, itemID)
	}
	if err := rows.Err(); err != nil {
		return err
	}
	for idx, itemID := range itemIDs {
		if _, err := tx.Exec(
			`UPDATE playlist_items SET position = ? WHERE id = ?`,
			idx, itemID,
		); err != nil {
			return err
		}
	}
	return nil
}

func loadPlaylistGroupOrdersTx(tx *sql.Tx, playlistID int64) ([]PlaylistGroupOrder, error) {
	groups, err := listPlaylistGroupsTx(tx, playlistID)
	if err != nil {
		return nil, err
	}

	out := make([]PlaylistGroupOrder, 0, len(groups))
	for _, group := range groups {
		rows, err := tx.Query(
			`SELECT id FROM playlist_items WHERE group_id = ? ORDER BY position`,
			group.ID,
		)
		if err != nil {
			return nil, err
		}

		order := PlaylistGroupOrder{GroupID: group.ID}
		for rows.Next() {
			var itemID int64
			if err := rows.Scan(&itemID); err != nil {
				rows.Close()
				return nil, err
			}
			order.ItemIDs = append(order.ItemIDs, itemID)
		}
		if err := rows.Err(); err != nil {
			rows.Close()
			return nil, err
		}
		rows.Close()
		out = append(out, order)
	}
	return out, nil
}
