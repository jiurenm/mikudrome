package store

import "fmt"

// UpsertPlaybackHistory records the latest playback state for a track and
// keeps the table bounded to the newest playbackHistoryMaxRows rows.
func (s *Store) UpsertPlaybackHistory(update PlaybackHistoryUpdate) error {
	if update.TrackID <= 0 {
		return fmt.Errorf("track id must be positive")
	}
	if update.PositionMS < 0 {
		update.PositionMS = 0
	}
	if update.DurationMS < 0 {
		update.DurationMS = 0
	}
	if update.DurationMS > 0 && update.PositionMS > update.DurationMS {
		update.PositionMS = update.DurationMS
	}
	if update.PlaybackMode != "video" {
		update.PlaybackMode = "audio"
	}

	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("begin playback history tx: %w", err)
	}
	defer tx.Rollback()

	if _, err := tx.Exec(
		`INSERT INTO playback_history
			(track_id, position_ms, duration_ms, playback_mode, context_label, played_at)
		 VALUES (?, ?, ?, ?, ?, ?)
		 ON CONFLICT(track_id) DO UPDATE SET
			position_ms = excluded.position_ms,
			duration_ms = excluded.duration_ms,
			playback_mode = excluded.playback_mode,
			context_label = excluded.context_label,
			played_at = excluded.played_at`,
		update.TrackID,
		update.PositionMS,
		update.DurationMS,
		update.PlaybackMode,
		update.ContextLabel,
		update.PlayedAt,
	); err != nil {
		return fmt.Errorf("upsert playback history: %w", err)
	}

	if _, err := tx.Exec(
		`DELETE FROM playback_history
		 WHERE track_id NOT IN (
			SELECT track_id
			FROM playback_history
			ORDER BY played_at DESC, track_id DESC
			LIMIT ?
		 )`,
		playbackHistoryMaxRows,
	); err != nil {
		return fmt.Errorf("prune playback history: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit playback history tx: %w", err)
	}
	return nil
}

// ListPlaybackHistory returns recently played tracks ordered newest first.
func (s *Store) ListPlaybackHistory(limit int) ([]PlaybackHistoryItem, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > playbackHistoryMaxRows {
		limit = playbackHistoryMaxRows
	}
	rows, err := s.db.Query(
		`SELECT `+trackSelectColumns("t", "a")+`,
		        h.position_ms, h.duration_ms, h.playback_mode, h.context_label, h.played_at
		   FROM playback_history h
		   JOIN tracks t ON t.id = h.track_id
		   LEFT JOIN albums a ON a.id = t.album_id
		  ORDER BY h.played_at DESC, h.track_id DESC
		  LIMIT ?`,
		limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []PlaybackHistoryItem
	for rows.Next() {
		var item PlaybackHistoryItem
		dest := append(
			trackScanDest(&item.Track),
			&item.PositionMS,
			&item.DurationMS,
			&item.PlaybackMode,
			&item.ContextLabel,
			&item.PlayedAt,
		)
		if err := rows.Scan(dest...); err != nil {
			return nil, err
		}
		out = append(out, item)
	}
	return out, rows.Err()
}
