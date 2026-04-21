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
