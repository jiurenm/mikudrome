package store

import (
	"os"
	"path/filepath"
	"testing"
)

func newTestStore(t *testing.T) *Store {
	t.Helper()
	dir := t.TempDir()
	s, err := New(filepath.Join(dir, "test.db"))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	t.Cleanup(func() { s.Close() })
	return s
}

func seedTrack(t *testing.T, s *Store, title, path string) int64 {
	t.Helper()
	albumID, err := s.UpsertAlbum("TestAlbum", "", 0, "")
	if err != nil {
		t.Fatalf("UpsertAlbum: %v", err)
	}
	if err := s.UpsertTrack(title, path, "", "", albumID, 1, 0, "", 0, 0, ""); err != nil {
		t.Fatalf("UpsertTrack: %v", err)
	}
	var id int64
	if err := s.db.QueryRow(`SELECT id FROM tracks WHERE audio_path = ?`, path).Scan(&id); err != nil {
		t.Fatalf("select track id: %v", err)
	}
	return id
}

func TestFavorites_AddRemoveListIdempotent(t *testing.T) {
	s := newTestStore(t)
	t1 := seedTrack(t, s, "A", "/a.flac")
	t2 := seedTrack(t, s, "B", "/b.flac")

	if err := s.AddFavorite(t1); err != nil {
		t.Fatalf("AddFavorite t1: %v", err)
	}
	if err := s.AddFavorite(t1); err != nil { // idempotent
		t.Fatalf("AddFavorite t1 dup: %v", err)
	}
	if err := s.AddFavorite(t2); err != nil {
		t.Fatalf("AddFavorite t2: %v", err)
	}

	list, err := s.ListFavorites()
	if err != nil {
		t.Fatalf("ListFavorites: %v", err)
	}
	if len(list) != 2 {
		t.Fatalf("want 2 favorites, got %d", len(list))
	}

	set, err := s.GetFavoriteSet()
	if err != nil {
		t.Fatalf("GetFavoriteSet: %v", err)
	}
	if !set[t1] || !set[t2] {
		t.Fatalf("favorite set missing ids: %v", set)
	}

	if err := s.RemoveFavorite(t1); err != nil {
		t.Fatalf("RemoveFavorite: %v", err)
	}
	if err := s.RemoveFavorite(t1); err != nil { // idempotent
		t.Fatalf("RemoveFavorite dup: %v", err)
	}

	isFav, err := s.IsFavorite(t1)
	if err != nil || isFav {
		t.Fatalf("IsFavorite t1 want false, got %v err=%v", isFav, err)
	}
	isFav, _ = s.IsFavorite(t2)
	if !isFav {
		t.Fatalf("IsFavorite t2 want true")
	}
}

func TestFavorites_CascadeOnTrackDelete(t *testing.T) {
	s := newTestStore(t)
	tid := seedTrack(t, s, "A", "/a.flac")
	if err := s.AddFavorite(tid); err != nil {
		t.Fatalf("AddFavorite: %v", err)
	}

	// Delete the track via the same path the scanner would use.
	if err := s.DeleteTracksByPaths([]string{"/a.flac"}); err != nil {
		t.Fatalf("DeleteTracksByPaths: %v", err)
	}

	set, err := s.GetFavoriteSet()
	if err != nil {
		t.Fatalf("GetFavoriteSet: %v", err)
	}
	if len(set) != 0 {
		t.Fatalf("want 0 favorites after cascade, got %d: %v", len(set), set)
	}

	// Silence unused variable.
	_ = os.Getenv
}
