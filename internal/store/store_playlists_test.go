package store

import (
	"os"
	"path/filepath"
	"strconv"
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

// --- Task 3: Playlist CRUD ---

func TestPlaylist_CRUD(t *testing.T) {
	s := newTestStore(t)
	id, err := s.CreatePlaylist("My Mix")
	if err != nil {
		t.Fatalf("CreatePlaylist: %v", err)
	}
	if id <= 0 {
		t.Fatalf("want positive id, got %d", id)
	}

	p, ok, err := s.GetPlaylistByID(id)
	if err != nil || !ok {
		t.Fatalf("GetPlaylistByID ok=%v err=%v", ok, err)
	}
	if p.Name != "My Mix" {
		t.Fatalf("name mismatch: %q", p.Name)
	}
	if p.TrackCount != 0 {
		t.Fatalf("new playlist trackCount want 0, got %d", p.TrackCount)
	}

	if err := s.RenamePlaylist(id, "Chill Mix"); err != nil {
		t.Fatalf("RenamePlaylist: %v", err)
	}
	p, _, _ = s.GetPlaylistByID(id)
	if p.Name != "Chill Mix" {
		t.Fatalf("rename failed: %q", p.Name)
	}

	list, err := s.ListPlaylists()
	if err != nil {
		t.Fatalf("ListPlaylists: %v", err)
	}
	if len(list) != 1 {
		t.Fatalf("want 1 playlist, got %d", len(list))
	}

	if err := s.DeletePlaylist(id); err != nil {
		t.Fatalf("DeletePlaylist: %v", err)
	}
	_, ok, _ = s.GetPlaylistByID(id)
	if ok {
		t.Fatalf("playlist should be gone")
	}
}

func TestPlaylist_CreateEmptyNameRejected(t *testing.T) {
	s := newTestStore(t)
	if _, err := s.CreatePlaylist(""); err == nil {
		t.Fatalf("want error for empty name")
	}
	if _, err := s.CreatePlaylist("   "); err == nil {
		t.Fatalf("want error for whitespace name")
	}
}

// --- Task 4: Playlist tracks ---

func TestPlaylist_AddTracksDedupe(t *testing.T) {
	s := newTestStore(t)
	pid, _ := s.CreatePlaylist("Mix")
	t1 := seedTrack(t, s, "A", "/a.flac")
	t2 := seedTrack(t, s, "B", "/b.flac")

	added, err := s.AddTracksToPlaylist(pid, []int64{t1, t2, t1})
	if err != nil {
		t.Fatalf("AddTracksToPlaylist: %v", err)
	}
	if added != 2 {
		t.Fatalf("want added=2, got %d", added)
	}

	added, _ = s.AddTracksToPlaylist(pid, []int64{t1})
	if added != 0 {
		t.Fatalf("want added=0 on dup, got %d", added)
	}

	got, err := s.GetPlaylistTracks(pid)
	if err != nil {
		t.Fatalf("GetPlaylistTracks: %v", err)
	}
	if len(got) != 2 || got[0].ID != t1 || got[1].ID != t2 {
		t.Fatalf("order wrong: %+v", got)
	}
}

func TestPlaylist_Reorder(t *testing.T) {
	s := newTestStore(t)
	pid, _ := s.CreatePlaylist("Mix")
	t1 := seedTrack(t, s, "A", "/a.flac")
	t2 := seedTrack(t, s, "B", "/b.flac")
	t3 := seedTrack(t, s, "C", "/c.flac")
	_, _ = s.AddTracksToPlaylist(pid, []int64{t1, t2, t3})

	if err := s.ReorderPlaylist(pid, []int64{t3, t1, t2}); err != nil {
		t.Fatalf("Reorder: %v", err)
	}
	got, _ := s.GetPlaylistTracks(pid)
	if len(got) != 3 || got[0].ID != t3 || got[1].ID != t1 || got[2].ID != t2 {
		t.Fatalf("wrong order")
	}
}

func TestPlaylist_ReorderSetMismatch(t *testing.T) {
	s := newTestStore(t)
	pid, _ := s.CreatePlaylist("Mix")
	t1 := seedTrack(t, s, "A", "/a.flac")
	t2 := seedTrack(t, s, "B", "/b.flac")
	_, _ = s.AddTracksToPlaylist(pid, []int64{t1, t2})

	if err := s.ReorderPlaylist(pid, []int64{t1}); err == nil {
		t.Fatalf("want error for missing id")
	}
	if err := s.ReorderPlaylist(pid, []int64{t1, t2, 999}); err == nil {
		t.Fatalf("want error for extra id")
	}
}

func TestPlaylist_RemoveTracksRebalance(t *testing.T) {
	s := newTestStore(t)
	pid, _ := s.CreatePlaylist("Mix")
	t1 := seedTrack(t, s, "A", "/a.flac")
	t2 := seedTrack(t, s, "B", "/b.flac")
	t3 := seedTrack(t, s, "C", "/c.flac")
	t4 := seedTrack(t, s, "D", "/d.flac")
	_, _ = s.AddTracksToPlaylist(pid, []int64{t1, t2, t3, t4})

	if err := s.RemoveTracksFromPlaylist(pid, []int64{t2, t3}); err != nil {
		t.Fatalf("Remove: %v", err)
	}
	got, _ := s.GetPlaylistTracks(pid)
	if len(got) != 2 || got[0].ID != t1 || got[1].ID != t4 {
		t.Fatalf("wrong remaining: %v", got)
	}

	// positions should be contiguous 0, 1
	rows, _ := s.db.Query(`SELECT position FROM playlist_tracks WHERE playlist_id = ? ORDER BY position`, pid)
	defer rows.Close()
	var positions []int
	for rows.Next() {
		var p int
		rows.Scan(&p)
		positions = append(positions, p)
	}
	if len(positions) != 2 || positions[0] != 0 || positions[1] != 1 {
		t.Fatalf("positions not contiguous: %v", positions)
	}
}

func TestPlaylist_CascadeViaScanner(t *testing.T) {
	s := newTestStore(t)
	pid, _ := s.CreatePlaylist("Mix")
	t1 := seedTrack(t, s, "A", "/a.flac")
	_, _ = s.AddTracksToPlaylist(pid, []int64{t1})
	s.AddFavorite(t1)

	if err := s.DeleteTracksByPaths([]string{"/a.flac"}); err != nil {
		t.Fatalf("DeleteTracksByPaths: %v", err)
	}

	got, _ := s.GetPlaylistTracks(pid)
	if len(got) != 0 {
		t.Fatalf("playlist_tracks should cascade, got %d rows", len(got))
	}
	set, _ := s.GetFavoriteSet()
	if len(set) != 0 {
		t.Fatalf("favorites should cascade, got %d rows", len(set))
	}
}

func TestPlaylist_CoverTrackIDs(t *testing.T) {
	s := newTestStore(t)
	pid, _ := s.CreatePlaylist("Mix")

	p, _, _ := s.GetPlaylistByID(pid)
	if len(p.CoverTrackIDs) != 0 {
		t.Fatalf("empty playlist should have 0 cover ids")
	}

	var ids []int64
	for i := 0; i < 6; i++ {
		ids = append(ids, seedTrack(t, s, "t", "/t"+strconv.Itoa(i)+".flac"))
	}
	_, _ = s.AddTracksToPlaylist(pid, ids)
	p, _, _ = s.GetPlaylistByID(pid)
	if len(p.CoverTrackIDs) != 4 {
		t.Fatalf("want 4 cover ids, got %d", len(p.CoverTrackIDs))
	}
	for i := 0; i < 4; i++ {
		if p.CoverTrackIDs[i] != ids[i] {
			t.Fatalf("order mismatch at %d: want %d got %d", i, ids[i], p.CoverTrackIDs[i])
		}
	}
}
