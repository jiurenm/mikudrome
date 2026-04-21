package store

import (
	"database/sql"
	"path/filepath"
	"testing"
)

func TestStoreNewMigratesTrackMetadataScannedColumns(t *testing.T) {
	dbPath := filepath.Join(t.TempDir(), "legacy.db")

	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		t.Fatalf("open legacy db: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	_, err = db.Exec(`
		CREATE TABLE tracks (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			title TEXT NOT NULL,
			audio_path TEXT NOT NULL UNIQUE,
			video_path TEXT NOT NULL DEFAULT '',
			video_thumb_path TEXT NOT NULL DEFAULT '',
			album_id INTEGER,
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
		INSERT INTO tracks (title, audio_path, composer, lyricist)
		VALUES ('Track', '/tmp/track.flac', 'kz', 'ryo');
	`)
	if err != nil {
		t.Fatalf("seed legacy schema: %v", err)
	}
	if err := db.Close(); err != nil {
		t.Fatalf("close legacy db: %v", err)
	}

	st, err := New(dbPath)
	if err != nil {
		t.Fatalf("migrate db: %v", err)
	}
	defer st.Close()

	var composerScanned, lyricistScanned string
	err = st.db.QueryRow(`
		SELECT composer_scanned, lyricist_scanned
		FROM tracks
		WHERE audio_path = '/tmp/track.flac'
	`).Scan(&composerScanned, &lyricistScanned)
	if err != nil {
		t.Fatalf("query migrated row: %v", err)
	}
	if composerScanned != "kz" || lyricistScanned != "ryo" {
		t.Fatalf("scanned columns = (%q, %q), want (%q, %q)", composerScanned, lyricistScanned, "kz", "ryo")
	}
}

func TestStoreNewDoesNotRebackfillScannedColumnsOnReopen(t *testing.T) {
	dbPath := filepath.Join(t.TempDir(), "legacy.db")

	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		t.Fatalf("open legacy db: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	_, err = db.Exec(`
		CREATE TABLE tracks (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			title TEXT NOT NULL,
			audio_path TEXT NOT NULL UNIQUE,
			video_path TEXT NOT NULL DEFAULT '',
			video_thumb_path TEXT NOT NULL DEFAULT '',
			album_id INTEGER,
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
		INSERT INTO tracks (title, audio_path, composer, lyricist)
		VALUES ('Track', '/tmp/track.flac', 'kz', 'ryo');
	`)
	if err != nil {
		t.Fatalf("seed legacy schema: %v", err)
	}
	if err := db.Close(); err != nil {
		t.Fatalf("close legacy db: %v", err)
	}

	st, err := New(dbPath)
	if err != nil {
		t.Fatalf("migrate db: %v", err)
	}
	_, err = st.db.Exec(`
		UPDATE tracks
		SET composer_scanned = '', lyricist_scanned = 'manual override'
		WHERE audio_path = '/tmp/track.flac'
	`)
	if err != nil {
		st.Close()
		t.Fatalf("prepare scanned values: %v", err)
	}
	if err := st.Close(); err != nil {
		t.Fatalf("close migrated db: %v", err)
	}

	st, err = New(dbPath)
	if err != nil {
		t.Fatalf("reopen db: %v", err)
	}
	defer st.Close()

	var composerScanned, lyricistScanned string
	err = st.db.QueryRow(`
		SELECT composer_scanned, lyricist_scanned
		FROM tracks
		WHERE audio_path = '/tmp/track.flac'
	`).Scan(&composerScanned, &lyricistScanned)
	if err != nil {
		t.Fatalf("query reopened row: %v", err)
	}
	if composerScanned != "" || lyricistScanned != "manual override" {
		t.Fatalf("scanned columns after reopen = (%q, %q), want (%q, %q)", composerScanned, lyricistScanned, "", "manual override")
	}
}

func TestListTrackMetadataPrefersManualComposerAndLyricist(t *testing.T) {
	st := newTestStore(t)

	_, err := st.db.Exec(`
		INSERT INTO producers (id, name) VALUES (1, 'kz');
		INSERT INTO albums (id, title, cover_path, producer_id, album_artist)
		VALUES (1, 'Album', '/cover.png', 1, 'kz');
		INSERT INTO tracks (
			id, title, audio_path, album_id, disc_number, track_number,
			composer, composer_scanned, lyricist, lyricist_scanned,
			arranger, vocal, voice_manipulator, illustrator, movie, source
		) VALUES (
			1, 'Track', '/tmp/track.flac', 1, 1, 3,
			'manual composer', 'scan composer', '', 'scan lyricist',
			'', 'Teto', '', '', '', ''
		);
	`)
	if err != nil {
		t.Fatalf("seed metadata row: %v", err)
	}

	rows, err := st.ListTrackMetadata()
	if err != nil {
		t.Fatalf("list metadata: %v", err)
	}
	if len(rows) != 1 {
		t.Fatalf("rows = %d, want 1", len(rows))
	}
	if rows[0].Composer != "manual composer" || rows[0].ComposerSource != "manual" {
		t.Fatalf("composer = %q (%s)", rows[0].Composer, rows[0].ComposerSource)
	}
	if rows[0].Lyricist != "scan lyricist" || rows[0].LyricistSource != "scanned" {
		t.Fatalf("lyricist = %q (%s)", rows[0].Lyricist, rows[0].LyricistSource)
	}
}

func TestUpdateTrackMetadataOnlyTouchesRequestedFields(t *testing.T) {
	st := newTestStore(t)

	_, err := st.db.Exec(`
		INSERT INTO tracks (
			id, title, audio_path, composer, composer_scanned, lyricist, lyricist_scanned, arranger, vocal
		) VALUES (
			1, 'Track', '/tmp/track.flac', 'manual', 'scan', 'manual lyric', 'scan lyric', 'old arranger', 'old vocal'
		);
	`)
	if err != nil {
		t.Fatalf("seed track: %v", err)
	}

	arranger := "new arranger"
	patch := TrackMetadataPatch{
		Arranger: &arranger,
	}
	if err := st.UpdateTrackMetadata(1, patch); err != nil {
		t.Fatalf("update track metadata: %v", err)
	}

	row, ok, err := st.GetTrackMetadataByID(1)
	if err != nil || !ok {
		t.Fatalf("get updated metadata: ok=%v err=%v", ok, err)
	}
	if row.Arranger != "new arranger" {
		t.Fatalf("arranger = %q, want %q", row.Arranger, "new arranger")
	}
	if row.Composer != "manual" || row.ComposerSource != "manual" {
		t.Fatalf("composer changed unexpectedly: %q (%s)", row.Composer, row.ComposerSource)
	}
}

func TestGetTracksByAlbumIDUsesEffectiveComposerAndLyricist(t *testing.T) {
	st := newTestStore(t)

	_, err := st.db.Exec(`
		INSERT INTO albums (id, title) VALUES (1, 'Album');
		INSERT INTO tracks (
			id, title, audio_path, album_id, composer, composer_scanned, lyricist, lyricist_scanned
		) VALUES (
			1, 'Track', '/tmp/track.flac', 1, '', 'scan composer', 'manual lyricist', 'scan lyricist'
		);
	`)
	if err != nil {
		t.Fatalf("seed track: %v", err)
	}

	tracks, err := st.GetTracksByAlbumID(1)
	if err != nil {
		t.Fatalf("get tracks by album: %v", err)
	}
	if len(tracks) != 1 {
		t.Fatalf("tracks = %d, want 1", len(tracks))
	}

	if tracks[0].Composer != "scan composer" {
		t.Fatalf("composer = %q, want %q", tracks[0].Composer, "scan composer")
	}
	if tracks[0].Lyricist != "manual lyricist" {
		t.Fatalf("lyricist = %q, want %q", tracks[0].Lyricist, "manual lyricist")
	}
}
