import { describe, expect, it } from "vitest";
import type { TrackMetadataRow } from "../../api/types";
import {
  buildAlbumGroups,
  buildPatchPayload,
  createDraftFromRow,
  hasDraftChanges,
  matchesSearch
} from "./model";

const baseRow: TrackMetadataRow = {
  id: 101,
  title: "Tell Your World",
  track_number: 9,
  disc_number: 2,
  album_id: 11,
  album_title: "Miku Collection",
  album_cover_path: "/covers/miku.jpg",
  producer_id: 77,
  producer_name: "livetune",
  composer: "kz",
  lyricist: "kz",
  arranger: "kz",
  remix: "tilt-six",
  vocal: "Hatsune Miku",
  voice_manipulator: "kz",
  illustrator: "redjuice",
  movie: "wakamuraP",
  source: "YouTube",
  composer_source: "manual",
  lyricist_source: "scanned"
};

describe("track model", () => {
  it("buildAlbumGroups groups by album and sorts tracks by disc then track number", () => {
    const rows: TrackMetadataRow[] = [
      { ...baseRow, id: 1, album_id: 2, album_title: "Zoo", disc_number: 2, track_number: 5, title: "Z-2-5" },
      { ...baseRow, id: 2, album_id: 1, album_title: "Alpha", disc_number: 1, track_number: 3, title: "A-1-3" },
      { ...baseRow, id: 3, album_id: 2, album_title: "Zoo", disc_number: 1, track_number: 7, title: "Z-1-7" },
      { ...baseRow, id: 4, album_id: 2, album_title: "Zoo", disc_number: 1, track_number: 1, title: "Z-1-1" },
      { ...baseRow, id: 5, album_id: 1, album_title: "Alpha", disc_number: 1, track_number: 1, title: "A-1-1" }
    ];

    const groups = buildAlbumGroups(rows);

    expect(groups).toHaveLength(2);
    expect(groups.map((group) => group.album.title)).toEqual(["Alpha", "Zoo"]);
    expect(groups[0].tracks.map((track) => track.title)).toEqual(["A-1-1", "A-1-3"]);
    expect(groups[1].tracks.map((track) => track.title)).toEqual(["Z-1-1", "Z-1-7", "Z-2-5"]);
  });

  it("matchesSearch matches album title, producer name, and track title", () => {
    const row = { ...baseRow, title: "World Is Mine", album_title: "Supercell Classics", producer_name: "ryo" };

    expect(matchesSearch(row, "  supercell ")).toBe(true);
    expect(matchesSearch(row, "RYO")).toBe(true);
    expect(matchesSearch(row, "world")).toBe(true);
    expect(matchesSearch(row, "not-found")).toBe(false);
  });

  it("buildPatchPayload returns only changed editable fields", () => {
    const draft = createDraftFromRow(baseRow);
    draft.composer = "ryo";
    draft.remix = "TeddyLoid";
    draft.source = "Niconico";

    expect(buildPatchPayload(baseRow, draft)).toEqual({
      composer: "ryo",
      remix: "TeddyLoid",
      source: "Niconico"
    });
  });

  it("hasDraftChanges checks only editable fields", () => {
    const unchangedDraft = createDraftFromRow(baseRow) as Record<string, string>;
    unchangedDraft.title = "Different Title";
    expect(hasDraftChanges(baseRow, unchangedDraft as ReturnType<typeof createDraftFromRow>)).toBe(false);

    const changedDraft = createDraftFromRow(baseRow);
    changedDraft.vocal = "Kagamine Rin";
    expect(hasDraftChanges(baseRow, changedDraft)).toBe(true);
  });
});
