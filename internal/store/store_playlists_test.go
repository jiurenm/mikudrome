package store

import (
	"database/sql"
	"errors"
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

func TestBatchInserterFlushUpsertsExistingAlbumWithoutForeignKeyFailure(t *testing.T) {
	s := newTestStore(t)

	albumID, err := s.UpsertAlbum("Existing Album", "/old-cover.jpg", 0, "")
	if err != nil {
		t.Fatalf("UpsertAlbum: %v", err)
	}
	if err := s.UpsertTrack("Old Track", "/old.flac", "", "", albumID, 1, 1, "", 0, 0, ""); err != nil {
		t.Fatalf("UpsertTrack: %v", err)
	}

	batch, err := s.BeginBatch(1)
	if err != nil {
		t.Fatalf("BeginBatch: %v", err)
	}

	if err := batch.Add(
		Track{Title: "New Track", AudioPath: "/new.flac", DiscNumber: 1, TrackNumber: 2},
		Album{Title: "Existing Album", CoverPath: "/new-cover.jpg"},
		Producer{},
	); err != nil {
		t.Fatalf("batch.Add: %v", err)
	}
	if err := batch.Close(); err != nil {
		t.Fatalf("batch.Close: %v", err)
	}

	var trackCount int
	if err := s.db.QueryRow(`
		SELECT COUNT(*)
		FROM tracks t
		INNER JOIN albums a ON a.id = t.album_id
		WHERE a.title = ?
	`, "Existing Album").Scan(&trackCount); err != nil {
		t.Fatalf("count album tracks: %v", err)
	}
	if trackCount != 2 {
		t.Fatalf("trackCount = %d, want %d", trackCount, 2)
	}
}

func TestBatchInserterFlushUpsertsExistingTrackWithoutDeletingPlaylistItems(t *testing.T) {
	s := newTestStore(t)

	trackID := seedTrack(t, s, "Track A", "/a.flac")
	playlistID, err := s.CreatePlaylist("Mix")
	if err != nil {
		t.Fatalf("CreatePlaylist: %v", err)
	}
	if _, err := s.AddTracksToPlaylist(playlistID, []int64{trackID}); err != nil {
		t.Fatalf("AddTracksToPlaylist: %v", err)
	}

	batch, err := s.BeginBatch(1)
	if err != nil {
		t.Fatalf("BeginBatch: %v", err)
	}

	if err := batch.Add(
		Track{Title: "Track A Updated", AudioPath: "/a.flac", DiscNumber: 1, TrackNumber: 1},
		Album{Title: "Updated Album", CoverPath: "/updated-cover.jpg"},
		Producer{},
	); err != nil {
		t.Fatalf("batch.Add: %v", err)
	}
	if err := batch.Close(); err != nil {
		t.Fatalf("batch.Close: %v", err)
	}

	var gotTrackID int64
	if err := s.db.QueryRow(`SELECT id FROM tracks WHERE audio_path = ?`, "/a.flac").Scan(&gotTrackID); err != nil {
		t.Fatalf("select updated track id: %v", err)
	}
	if gotTrackID != trackID {
		t.Fatalf("track ID changed from %d to %d", trackID, gotTrackID)
	}

	detail, ok, err := s.GetPlaylistDetail(playlistID)
	if err != nil || !ok {
		t.Fatalf("GetPlaylistDetail ok=%v err=%v", ok, err)
	}
	if len(detail.Groups) != 1 || len(detail.Groups[0].Items) != 1 {
		t.Fatalf("playlist items were not preserved: %+v", detail.Groups)
	}
	if detail.Groups[0].Items[0].TrackID != trackID {
		t.Fatalf("playlist item trackID = %d, want %d", detail.Groups[0].Items[0].TrackID, trackID)
	}
}

func TestBatchInserterFlushKeepsExistingProducerIDAndRefreshesAvatar(t *testing.T) {
	s := newTestStore(t)

	eveID, err := s.UpsertProducer("Eve", "")
	if err != nil {
		t.Fatalf("UpsertProducer: %v", err)
	}

	batch, err := s.BeginBatch(2)
	if err != nil {
		t.Fatalf("BeginBatch: %v", err)
	}

	if err := batch.Add(
		Track{Title: "Blank", AudioPath: "/blank.flac", DiscNumber: 1, TrackNumber: 1},
		Album{Title: "Blank Album", CoverPath: "/blank.jpg"},
		Producer{Name: "", AvatarPath: "/app/media/初音ミク/artist.jpg"},
	); err != nil {
		t.Fatalf("batch.Add blank: %v", err)
	}

	if err := batch.Add(
		Track{Title: "Eve Song", AudioPath: "/eve.flac", DiscNumber: 1, TrackNumber: 1},
		Album{Title: "Eve Album", CoverPath: "/eve.jpg", AlbumArtist: "Eve"},
		Producer{Name: "Eve", AvatarPath: "/app/media/Eve/artist.png"},
	); err != nil {
		t.Fatalf("batch.Add Eve: %v", err)
	}

	if err := batch.Close(); err != nil {
		t.Fatalf("batch.Close: %v", err)
	}

	var producerID int64
	if err := s.db.QueryRow(`SELECT producer_id FROM albums WHERE title = ?`, "Eve Album").Scan(&producerID); err != nil {
		t.Fatalf("select album producer_id: %v", err)
	}
	if producerID != eveID {
		t.Fatalf("producer_id = %d, want %d", producerID, eveID)
	}

	var avatarPath string
	if err := s.db.QueryRow(`SELECT avatar_path FROM producers WHERE id = ?`, eveID).Scan(&avatarPath); err != nil {
		t.Fatalf("select producer avatar_path: %v", err)
	}
	if avatarPath != "/app/media/Eve/artist.png" {
		t.Fatalf("avatar_path = %q, want %q", avatarPath, "/app/media/Eve/artist.png")
	}

	var emptyProducerCount int
	if err := s.db.QueryRow(`SELECT COUNT(*) FROM producers WHERE name = ''`).Scan(&emptyProducerCount); err != nil {
		t.Fatalf("count empty-name producers: %v", err)
	}
	if emptyProducerCount != 0 {
		t.Fatalf("empty-name producer count = %d, want 0", emptyProducerCount)
	}
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

func TestPlaylist_CreateIncludesSystemUngroupedGroup(t *testing.T) {
	s := newTestStore(t)
	pid, err := s.CreatePlaylist("Grouped")
	if err != nil {
		t.Fatalf("CreatePlaylist: %v", err)
	}

	detail, ok, err := s.GetPlaylistDetail(pid)
	if err != nil || !ok {
		t.Fatalf("GetPlaylistDetail ok=%v err=%v", ok, err)
	}
	if len(detail.Groups) != 1 {
		t.Fatalf("want 1 default group, got %d", len(detail.Groups))
	}
	group := detail.Groups[0]
	if !group.IsSystem || group.Title != "Ungrouped" || group.Position != 0 {
		t.Fatalf("unexpected default group: %+v", group)
	}
}

func TestPlaylist_AddTracksCreatesItemsInUngrouped(t *testing.T) {
	s := newTestStore(t)
	pid, _ := s.CreatePlaylist("Grouped")
	t1 := seedTrack(t, s, "A", "/a.flac")
	t2 := seedTrack(t, s, "B", "/b.flac")

	added, err := s.AddTracksToPlaylist(pid, []int64{t1, t2, t1})
	if err != nil {
		t.Fatalf("AddTracksToPlaylist: %v", err)
	}
	if added != 3 {
		t.Fatalf("want added=3, got %d", added)
	}

	detail, _, _ := s.GetPlaylistDetail(pid)
	if len(detail.Groups) != 1 {
		t.Fatalf("want only Ungrouped, got %d groups", len(detail.Groups))
	}
	group := detail.Groups[0]
	if group.Title != "Ungrouped" || !group.IsSystem || group.Position != 0 {
		t.Fatalf("unexpected group metadata: %+v", group)
	}
	if len(group.Items) != 3 {
		t.Fatalf("want 3 playlist items, got %d", len(group.Items))
	}
	if group.Items[0].TrackID != t1 || group.Items[1].TrackID != t2 || group.Items[2].TrackID != t1 {
		t.Fatalf("unexpected item order: %+v", group.Items)
	}
}

// --- Task 4: Playlist tracks ---

func TestPlaylist_GetTracksIncludesDuplicatesInFlattenedOrder(t *testing.T) {
	s := newTestStore(t)
	pid, _ := s.CreatePlaylist("Mix")
	t1 := seedTrack(t, s, "A", "/a.flac")
	t2 := seedTrack(t, s, "B", "/b.flac")

	added, err := s.AddTracksToPlaylist(pid, []int64{t1, t2, t1})
	if err != nil {
		t.Fatalf("AddTracksToPlaylist: %v", err)
	}
	if added != 3 {
		t.Fatalf("want added=3, got %d", added)
	}

	got, err := s.GetPlaylistTracks(pid)
	if err != nil {
		t.Fatalf("GetPlaylistTracks: %v", err)
	}
	if len(got) != 3 || got[0].ID != t1 || got[1].ID != t2 || got[2].ID != t1 {
		t.Fatalf("order wrong: %+v", got)
	}

	p, ok, err := s.GetPlaylistByID(pid)
	if err != nil || !ok {
		t.Fatalf("GetPlaylistByID ok=%v err=%v", ok, err)
	}
	if p.TrackCount != 3 {
		t.Fatalf("want TrackCount=3, got %d", p.TrackCount)
	}
	if len(p.CoverTrackIDs) != 3 || p.CoverTrackIDs[0] != t1 || p.CoverTrackIDs[1] != t2 || p.CoverTrackIDs[2] != t1 {
		t.Fatalf("unexpected cover ids: %v", p.CoverTrackIDs)
	}
}

func TestPlaylist_GroupLifecycleAndItemMove(t *testing.T) {
	s := newTestStore(t)
	pid, _ := s.CreatePlaylist("Mix")
	t1 := seedTrack(t, s, "A", "/a.flac")
	t2 := seedTrack(t, s, "B", "/b.flac")
	_, _ = s.AddTracksToPlaylist(pid, []int64{t1, t2})

	groupID, err := s.CreatePlaylistGroup(pid, "Side B")
	if err != nil {
		t.Fatalf("CreatePlaylistGroup: %v", err)
	}

	detail, ok, err := s.GetPlaylistDetail(pid)
	if err != nil || !ok {
		t.Fatalf("GetPlaylistDetail ok=%v err=%v", ok, err)
	}
	if len(detail.Groups) != 2 {
		t.Fatalf("want 2 groups, got %d", len(detail.Groups))
	}
	if len(detail.Groups[0].Items) != 2 || len(detail.Groups[1].Items) != 0 {
		t.Fatalf("creating a group should not move items: %+v", detail.Groups)
	}

	if err := s.RenamePlaylistGroup(groupID, "Disc 2"); err != nil {
		t.Fatalf("RenamePlaylistGroup: %v", err)
	}

	itemID := detail.Groups[0].Items[1].ID
	newGroupID := groupID
	newPosition := 0
	note := "moved"
	if err := s.UpdatePlaylistItem(itemID, PlaylistItemUpdate{
		GroupID:  &newGroupID,
		Position: &newPosition,
		Note:     &note,
	}); err != nil {
		t.Fatalf("UpdatePlaylistItem: %v", err)
	}

	detail, _, _ = s.GetPlaylistDetail(pid)
	if detail.Groups[1].Title != "Disc 2" {
		t.Fatalf("rename not reflected: %+v", detail.Groups[1])
	}
	if len(detail.Groups[0].Items) != 1 || detail.Groups[0].Items[0].TrackID != t1 {
		t.Fatalf("unexpected ungrouped items after move: %+v", detail.Groups[0].Items)
	}
	if len(detail.Groups[1].Items) != 1 || detail.Groups[1].Items[0].TrackID != t2 {
		t.Fatalf("unexpected group items after move: %+v", detail.Groups[1].Items)
	}
	if detail.Groups[1].Items[0].Note != note {
		t.Fatalf("note not updated: %+v", detail.Groups[1].Items[0])
	}

	if err := s.DeletePlaylistGroup(groupID); err != nil {
		t.Fatalf("DeletePlaylistGroup: %v", err)
	}

	detail, _, _ = s.GetPlaylistDetail(pid)
	if len(detail.Groups) != 1 {
		t.Fatalf("want only Ungrouped after delete, got %d groups", len(detail.Groups))
	}
	if len(detail.Groups[0].Items) != 2 || detail.Groups[0].Items[0].TrackID != t1 || detail.Groups[0].Items[1].TrackID != t2 {
		t.Fatalf("group delete should move items back to Ungrouped: %+v", detail.Groups[0].Items)
	}
}

func TestPlaylist_UpdatePlaylistItemInsertAtFrontOfOccupiedGroup(t *testing.T) {
	s := newTestStore(t)
	pid, _ := s.CreatePlaylist("Mix")
	t1 := seedTrack(t, s, "A", "/a.flac")
	t2 := seedTrack(t, s, "B", "/b.flac")
	t3 := seedTrack(t, s, "C", "/c.flac")
	_, _ = s.AddTracksToPlaylist(pid, []int64{t1, t2, t3})

	groupID, err := s.CreatePlaylistGroup(pid, "A")
	if err != nil {
		t.Fatalf("CreatePlaylistGroup: %v", err)
	}

	detail, _, _ := s.GetPlaylistDetail(pid)
	t2ItemID := detail.Groups[0].Items[1].ID
	t3ItemID := detail.Groups[0].Items[2].ID

	groupPos := int64(groupID)
	insertPos := 0
	if err := s.UpdatePlaylistItem(t2ItemID, PlaylistItemUpdate{
		GroupID:  &groupPos,
		Position: &insertPos,
	}); err != nil {
		t.Fatalf("move t2 into empty group: %v", err)
	}
	if err := s.UpdatePlaylistItem(t3ItemID, PlaylistItemUpdate{
		GroupID:  &groupPos,
		Position: &insertPos,
	}); err != nil {
		t.Fatalf("insert t3 at front of occupied group: %v", err)
	}

	detail, _, _ = s.GetPlaylistDetail(pid)
	if len(detail.Groups[1].Items) != 2 {
		t.Fatalf("want 2 items in custom group, got %+v", detail.Groups[1].Items)
	}
	if detail.Groups[1].Items[0].TrackID != t3 || detail.Groups[1].Items[1].TrackID != t2 {
		t.Fatalf("unexpected custom group order: %+v", detail.Groups[1].Items)
	}
}

func TestPlaylist_ReorderPlaylistItems(t *testing.T) {
	s := newTestStore(t)
	pid, _ := s.CreatePlaylist("Mix")
	t1 := seedTrack(t, s, "A", "/a.flac")
	t2 := seedTrack(t, s, "B", "/b.flac")
	t3 := seedTrack(t, s, "C", "/c.flac")
	_, _ = s.AddTracksToPlaylist(pid, []int64{t1, t2, t3})

	groupA, err := s.CreatePlaylistGroup(pid, "A")
	if err != nil {
		t.Fatalf("CreatePlaylistGroup A: %v", err)
	}
	groupB, err := s.CreatePlaylistGroup(pid, "B")
	if err != nil {
		t.Fatalf("CreatePlaylistGroup B: %v", err)
	}

	detail, _, _ := s.GetPlaylistDetail(pid)
	ungrouped := detail.Groups[0]
	if len(ungrouped.Items) != 3 {
		t.Fatalf("want 3 items in Ungrouped, got %d", len(ungrouped.Items))
	}

	err = s.ReorderPlaylistItems(pid, []PlaylistGroupOrder{
		{GroupID: ungrouped.ID, ItemIDs: []int64{ungrouped.Items[2].ID}},
		{GroupID: groupB, ItemIDs: []int64{ungrouped.Items[0].ID}},
		{GroupID: groupA, ItemIDs: []int64{ungrouped.Items[1].ID}},
	})
	if err != nil {
		t.Fatalf("ReorderPlaylistItems: %v", err)
	}

	detail, _, _ = s.GetPlaylistDetail(pid)
	if len(detail.Groups) != 3 {
		t.Fatalf("want 3 groups after reorder, got %d", len(detail.Groups))
	}
	if detail.Groups[0].Title != "Ungrouped" || detail.Groups[1].ID != groupB || detail.Groups[2].ID != groupA {
		t.Fatalf("unexpected group order: %+v", detail.Groups)
	}
	if len(detail.Groups[0].Items) != 1 || detail.Groups[0].Items[0].TrackID != t3 {
		t.Fatalf("unexpected Ungrouped items: %+v", detail.Groups[0].Items)
	}
	if len(detail.Groups[1].Items) != 1 || detail.Groups[1].Items[0].TrackID != t1 {
		t.Fatalf("unexpected group B items: %+v", detail.Groups[1].Items)
	}
	if len(detail.Groups[2].Items) != 1 || detail.Groups[2].Items[0].TrackID != t2 {
		t.Fatalf("unexpected group A items: %+v", detail.Groups[2].Items)
	}

	got, _ := s.GetPlaylistTracks(pid)
	if len(got) != 3 || got[0].ID != t3 || got[1].ID != t1 || got[2].ID != t2 {
		t.Fatalf("flattened order wrong: %+v", got)
	}
}

func TestPlaylist_ReorderPlaylistItemsLargePayload(t *testing.T) {
	s := newTestStore(t)
	pid, _ := s.CreatePlaylist("Large")

	var trackIDs []int64
	for i := 0; i < 1002; i++ {
		path := "/large" + strconv.Itoa(i) + ".flac"
		trackIDs = append(trackIDs, seedTrack(t, s, "L", path))
	}
	if _, err := s.AddTracksToPlaylist(pid, trackIDs); err != nil {
		t.Fatalf("AddTracksToPlaylist: %v", err)
	}

	detail, _, _ := s.GetPlaylistDetail(pid)
	ungrouped := detail.Groups[0]
	itemIDs := make([]int64, 0, len(ungrouped.Items))
	for i := len(ungrouped.Items) - 1; i >= 0; i-- {
		itemIDs = append(itemIDs, ungrouped.Items[i].ID)
	}

	if err := s.ReorderPlaylistItems(pid, []PlaylistGroupOrder{
		{GroupID: ungrouped.ID, ItemIDs: itemIDs},
	}); err != nil {
		t.Fatalf("ReorderPlaylistItems large payload: %v", err)
	}

	got, err := s.GetPlaylistTracks(pid)
	if err != nil {
		t.Fatalf("GetPlaylistTracks: %v", err)
	}
	if len(got) != len(trackIDs) {
		t.Fatalf("want %d tracks, got %d", len(trackIDs), len(got))
	}
	if got[0].ID != trackIDs[len(trackIDs)-1] || got[len(got)-1].ID != trackIDs[0] {
		t.Fatalf("unexpected reordered boundary tracks: first=%d last=%d", got[0].ID, got[len(got)-1].ID)
	}
}

func TestPlaylist_ReorderPlaylistItemsSetMismatch(t *testing.T) {
	s := newTestStore(t)
	pid, _ := s.CreatePlaylist("Mix")
	t1 := seedTrack(t, s, "A", "/a.flac")
	t2 := seedTrack(t, s, "B", "/b.flac")
	_, _ = s.AddTracksToPlaylist(pid, []int64{t1, t2})

	groupID, err := s.CreatePlaylistGroup(pid, "A")
	if err != nil {
		t.Fatalf("CreatePlaylistGroup: %v", err)
	}

	detail, _, _ := s.GetPlaylistDetail(pid)
	ungrouped := detail.Groups[0]

	if err := s.ReorderPlaylistItems(pid, []PlaylistGroupOrder{
		{GroupID: ungrouped.ID, ItemIDs: []int64{ungrouped.Items[0].ID}},
		{GroupID: groupID, ItemIDs: nil},
	}); err == nil {
		t.Fatalf("want error for missing item")
	}
	if err := s.ReorderPlaylistItems(pid, []PlaylistGroupOrder{
		{GroupID: ungrouped.ID, ItemIDs: []int64{ungrouped.Items[0].ID, 999}},
		{GroupID: groupID, ItemIDs: []int64{ungrouped.Items[1].ID}},
	}); err == nil {
		t.Fatalf("want error for unknown item")
	}
}

func TestPlaylist_ReorderPlaylistWithEmptyCustomGroup(t *testing.T) {
	s := newTestStore(t)
	pid, _ := s.CreatePlaylist("Mix")
	t1 := seedTrack(t, s, "A", "/a.flac")
	t2 := seedTrack(t, s, "B", "/b.flac")
	t3 := seedTrack(t, s, "C", "/c.flac")
	_, _ = s.AddTracksToPlaylist(pid, []int64{t1, t2, t3})

	if _, err := s.CreatePlaylistGroup(pid, "Empty"); err != nil {
		t.Fatalf("CreatePlaylistGroup: %v", err)
	}

	if err := s.ReorderPlaylist(pid, []int64{t3, t1, t2}); err != nil {
		t.Fatalf("ReorderPlaylist: %v", err)
	}

	got, err := s.GetPlaylistTracks(pid)
	if err != nil {
		t.Fatalf("GetPlaylistTracks: %v", err)
	}
	if len(got) != 3 || got[0].ID != t3 || got[1].ID != t1 || got[2].ID != t2 {
		t.Fatalf("wrong order after flat reorder with empty custom group: %+v", got)
	}
}

func TestPlaylist_SystemGroupDeleteProtection(t *testing.T) {
	s := newTestStore(t)
	pid, _ := s.CreatePlaylist("Mix")

	detail, _, _ := s.GetPlaylistDetail(pid)
	ungrouped := detail.Groups[0]

	if err := s.DeletePlaylistGroup(ungrouped.ID); !errors.Is(err, ErrSystemPlaylistGroup) {
		t.Fatalf("DeletePlaylistGroup want ErrSystemPlaylistGroup, got %v", err)
	}
}

func TestPlaylist_SystemGroupCanBeRenamed(t *testing.T) {
	s := newTestStore(t)
	pid, _ := s.CreatePlaylist("Mix")

	detail, _, err := s.GetPlaylistDetail(pid)
	if err != nil {
		t.Fatalf("GetPlaylistDetail: %v", err)
	}
	ungrouped := detail.Groups[0]

	if err := s.RenamePlaylistGroup(ungrouped.ID, "Loose Tracks"); err != nil {
		t.Fatalf("RenamePlaylistGroup system group: %v", err)
	}

	updated, _, err := s.GetPlaylistDetail(pid)
	if err != nil {
		t.Fatalf("GetPlaylistDetail after rename: %v", err)
	}
	if updated.Groups[0].Title != "Loose Tracks" {
		t.Fatalf("want renamed system group title, got %q", updated.Groups[0].Title)
	}
}

func TestPlaylist_SystemGroupCanBeReordered(t *testing.T) {
	s := newTestStore(t)
	pid, _ := s.CreatePlaylist("Mix")
	t1 := seedTrack(t, s, "A", "/a.flac")
	t2 := seedTrack(t, s, "B", "/b.flac")
	_, _ = s.AddTracksToPlaylist(pid, []int64{t1, t2})

	groupID, err := s.CreatePlaylistGroup(pid, "A")
	if err != nil {
		t.Fatalf("CreatePlaylistGroup: %v", err)
	}
	groupID2, err := s.CreatePlaylistGroup(pid, "B")
	if err != nil {
		t.Fatalf("CreatePlaylistGroup 2: %v", err)
	}

	detail, _, err := s.GetPlaylistDetail(pid)
	if err != nil {
		t.Fatalf("GetPlaylistDetail: %v", err)
	}
	ungrouped := detail.Groups[0]

	if err := s.ReorderPlaylistItems(pid, []PlaylistGroupOrder{
		{GroupID: groupID, ItemIDs: nil},
		{GroupID: ungrouped.ID, ItemIDs: []int64{ungrouped.Items[0].ID, ungrouped.Items[1].ID}},
		{GroupID: groupID2, ItemIDs: nil},
	}); err != nil {
		t.Fatalf("ReorderPlaylistItems with system group move: %v", err)
	}

	updated, _, err := s.GetPlaylistDetail(pid)
	if err != nil {
		t.Fatalf("GetPlaylistDetail after reorder: %v", err)
	}
	if len(updated.Groups) != 3 {
		t.Fatalf("want 3 groups, got %d", len(updated.Groups))
	}
	if updated.Groups[0].ID != groupID || updated.Groups[1].ID != ungrouped.ID || updated.Groups[2].ID != groupID2 {
		t.Fatalf("unexpected group order after reorder: %+v", updated.Groups)
	}
}

func TestPlaylist_CreateGroupMissingPlaylist(t *testing.T) {
	s := newTestStore(t)
	if _, err := s.CreatePlaylistGroup(9999, "Ghost"); !errors.Is(err, sql.ErrNoRows) {
		t.Fatalf("want sql.ErrNoRows, got %v", err)
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
	detail, _, _ := s.GetPlaylistDetail(pid)
	if len(detail.Groups) != 1 {
		t.Fatalf("want only Ungrouped after remove, got %d groups", len(detail.Groups))
	}
	items := detail.Groups[0].Items
	if len(items) != 2 || items[0].TrackID != t1 || items[1].TrackID != t4 {
		t.Fatalf("wrong remaining: %+v", items)
	}
	if items[0].Position != 0 || items[1].Position != 1 {
		t.Fatalf("positions not contiguous: %+v", items)
	}
}

func TestPlaylist_RemoveTracksMissingPlaylist(t *testing.T) {
	s := newTestStore(t)
	t1 := seedTrack(t, s, "A", "/a.flac")

	if err := s.RemoveTracksFromPlaylist(9999, []int64{t1}); !errors.Is(err, sql.ErrNoRows) {
		t.Fatalf("want sql.ErrNoRows, got %v", err)
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
