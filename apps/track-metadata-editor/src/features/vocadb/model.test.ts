import { describe, expect, it } from "vitest";
import type { TrackMetadataRow, VocaDbAlbumDetail } from "../../api/types";
import {
  alignAlbumTracks,
  buildBatchPatchFromSelections,
  buildBatchPatchFromTrackReviews,
  buildVocaDbSuggestions,
  buildVocaDbTrackReviews,
  normalizeVocalName,
  parseVocaDbAlbumId
} from "./model";

const baseRow: TrackMetadataRow = {
  id: 101,
  title: "World",
  track_number: 1,
  disc_number: 1,
  album_id: 11,
  album_title: "Album",
  album_cover_path: "/covers/album.jpg",
  producer_id: 77,
  producer_name: "ryo",
  composer: "",
  lyricist: "",
  arranger: "",
  remix: "",
  vocal: "",
  voice_manipulator: "",
  illustrator: "",
  movie: "",
  source: "",
  composer_source: "empty",
  lyricist_source: "empty"
};

const baseAlbum: VocaDbAlbumDetail = {
  id: 42,
  name: "Album",
  artistString: "ryo feat. Hatsune Miku V6",
  url: "https://vocadb.net/Al/42",
  tracks: [
    {
      discNumber: 1,
      trackNumber: 1,
      title: "World",
      songId: 9001,
      url: "https://vocadb.net/S/9001",
      producers: ["ryo"],
      vocalists: ["Hatsune Miku V6"],
      artists: [
        { name: "ryo", roles: ["Composer", "Lyricist"] },
        { name: "Hatsune Miku V6", roles: ["Vocalist"] }
      ]
    }
  ]
};

function suggestionValue(
  suggestions: ReturnType<typeof buildVocaDbSuggestions>,
  field: string
) {
  const suggestion = suggestions.find((item) => item.field === field);
  expect(suggestion).toBeDefined();
  return suggestion!;
}

describe("VocaDB metadata model", () => {
  it("parseVocaDbAlbumId accepts numeric IDs and album URLs, then rejects invalid input", () => {
    expect(parseVocaDbAlbumId("42")).toBe(42);
    expect(parseVocaDbAlbumId("  42  ")).toBe(42);
    expect(parseVocaDbAlbumId("https://vocadb.net/Al/42")).toBe(42);
    expect(parseVocaDbAlbumId("https://vocadb.net/Al/42/world-is-mine")).toBe(42);

    expect(parseVocaDbAlbumId("")).toBeNull();
    expect(parseVocaDbAlbumId("abc")).toBeNull();
    expect(parseVocaDbAlbumId("https://vocadb.net/S/42")).toBeNull();
    expect(parseVocaDbAlbumId("0")).toBeNull();
  });

  it("alignAlbumTracks matches by disc and track number first", () => {
    const rows = [
      { ...baseRow, id: 1, title: "Different Title", disc_number: 1, track_number: 1 },
      { ...baseRow, id: 2, title: "World", disc_number: 1, track_number: 2 }
    ];
    const album = {
      ...baseAlbum,
      tracks: [
        { ...baseAlbum.tracks[0], discNumber: 1, trackNumber: 1, title: "World" }
      ]
    };

    const matches = alignAlbumTracks(rows, album);

    expect(matches).toHaveLength(2);
    expect(matches[0]).toMatchObject({
      localTrack: rows[0],
      vocaTrack: album.tracks[0],
      status: "matched"
    });
  });

  it("normalizeVocalName collapses known Hatsune Miku versions", () => {
    expect(normalizeVocalName("Hatsune Miku V6")).toBe("Hatsune Miku");
    expect(normalizeVocalName("Hatsune Miku V4X")).toBe("Hatsune Miku");
    expect(normalizeVocalName("Hatsune Miku Append")).toBe("Hatsune Miku");
    expect(normalizeVocalName("Hatsune Miku NT")).toBe("Hatsune Miku");
    expect(normalizeVocalName("Hatsune Miku AI")).toBe("Hatsune Miku");
    expect(normalizeVocalName("初音ミクV6")).toBe("初音ミク");
    expect(normalizeVocalName("初音ミク V6")).toBe("初音ミク");
    expect(normalizeVocalName("Kagamine Rin V4X")).toBe("Kagamine Rin");
    expect(normalizeVocalName("巡音ルカ V4X")).toBe("巡音ルカ");
    expect(normalizeVocalName("Kagamine Rin Power")).toBe("Kagamine Rin Power");
  });

  it("normalizeVocalName prefers existing local vocal spelling when available", () => {
    expect(normalizeVocalName("Hatsune Miku V6", "初音ミク")).toBe("初音ミク");
    expect(normalizeVocalName("初音ミクV6", "Hatsune Miku")).toBe("Hatsune Miku");
  });

  it("buildVocaDbSuggestions uses explicit roles, selects empty fields, and preserves vocal values", () => {
    const suggestions = buildVocaDbSuggestions([baseRow], baseAlbum);

    expect(suggestionValue(suggestions, "composer")).toMatchObject({
      field: "composer",
      currentValue: "",
      originalValue: "ryo",
      suggestedValue: "ryo",
      confidence: "explicit",
      selected: true
    });
    expect(suggestionValue(suggestions, "lyricist")).toMatchObject({
      suggestedValue: "ryo",
      confidence: "explicit",
      selected: true
    });
    expect(suggestionValue(suggestions, "vocal")).toMatchObject({
      currentValue: "",
      originalValue: "Hatsune Miku V6",
      suggestedValue: "Hatsune Miku",
      confidence: "explicit",
      selected: true
    });
    expect(suggestionValue(suggestions, "source")).toMatchObject({
      suggestedValue: "https://vocadb.net/S/9001",
      confidence: "explicit",
      selected: true
    });
  });

  it("buildVocaDbSuggestions uses producer fallback for empty composer and lyricist", () => {
    const album = {
      ...baseAlbum,
      tracks: [
        {
          ...baseAlbum.tracks[0],
          artists: [{ name: "Hatsune Miku V6", roles: ["Vocalist"] }]
        }
      ]
    };

    const suggestions = buildVocaDbSuggestions([baseRow], album);

    expect(suggestionValue(suggestions, "composer")).toMatchObject({
      suggestedValue: "ryo",
      confidence: "fallback",
      selected: true
    });
    expect(suggestionValue(suggestions, "lyricist")).toMatchObject({
      suggestedValue: "ryo",
      confidence: "fallback",
      selected: true
    });
  });

  it("buildVocaDbSuggestions leaves existing local values as unselected overwrite suggestions", () => {
    const row = {
      ...baseRow,
      composer: "local composer",
      lyricist: "local lyricist",
      vocal: "local vocal",
      source: "local source"
    };

    const suggestions = buildVocaDbSuggestions([row], baseAlbum);

    expect(suggestionValue(suggestions, "composer")).toMatchObject({
      currentValue: "local composer",
      suggestedValue: "ryo",
      selected: false
    });
    expect(suggestionValue(suggestions, "vocal")).toMatchObject({
      currentValue: "local vocal",
      originalValue: "Hatsune Miku V6",
      suggestedValue: "Hatsune Miku",
      selected: false
    });
  });

  it("buildVocaDbSuggestions skips unchanged suggestions", () => {
    const explicitRow = {
      ...baseRow,
      composer: " ryo ",
      lyricist: "ryo",
      vocal: "Hatsune Miku",
      source: "https://vocadb.net/S/9001"
    };

    expect(buildVocaDbSuggestions([explicitRow], baseAlbum)).toEqual([]);

    const fallbackAlbum = {
      ...baseAlbum,
      tracks: [
        {
          ...baseAlbum.tracks[0],
          artists: [],
          vocalists: ["Hatsune Miku V6"]
        }
      ]
    };
    const fallbackRow = {
      ...baseRow,
      composer: "ryo",
      lyricist: " ryo ",
      vocal: "Hatsune Miku",
      source: "https://vocadb.net/S/9001"
    };

    expect(buildVocaDbSuggestions([fallbackRow], fallbackAlbum)).toEqual([]);
  });

  it("buildBatchPatchFromSelections includes only selected changed fields", () => {
    const suggestions = buildVocaDbSuggestions([baseRow], baseAlbum);
    const sourceSuggestion = suggestionValue(suggestions, "source");
    sourceSuggestion.selected = false;

    const patch = buildBatchPatchFromSelections([
      ...suggestions,
      {
        id: "101-source-manual",
        trackId: 101,
        field: "source",
        currentValue: "",
        originalValue: "https://vocadb.net/S/9001",
        suggestedValue: "https://vocadb.net/S/9001",
        confidence: "explicit",
        selected: true
      }
    ]);

    expect(patch).toEqual({
      updates: [
        {
          track_id: 101,
          patch: {
            composer: "ryo",
            lyricist: "ryo",
            vocal: "Hatsune Miku",
            source: "https://vocadb.net/S/9001"
          }
        }
      ]
    });
  });

  it("buildVocaDbTrackReviews includes every editable field and explicit song-detail roles", () => {
    const album: VocaDbAlbumDetail = {
      ...baseAlbum,
      tracks: [
        {
          ...baseAlbum.tracks[0],
          artists: [
            { name: "吉田夜世", roles: ["Composer", "Lyricist", "Animator", "Mixer"] },
            { name: "シシア", roles: ["Illustrator"] },
            { name: "重音テトSV", roles: ["Vocalist"] }
          ]
        }
      ]
    };

    const reviews = buildVocaDbTrackReviews([baseRow], album);

    expect(reviews).toHaveLength(1);
    expect(reviews[0].status).toBe("matched");
    expect(reviews[0].fields.map((field) => field.field)).toEqual([
      "composer",
      "lyricist",
      "arranger",
      "remix",
      "vocal",
      "voice_manipulator",
      "illustrator",
      "movie",
      "source"
    ]);
    expect(reviews[0].fields.find((field) => field.field === "composer")).toMatchObject({
      originalValue: "吉田夜世",
      suggestedValue: "吉田夜世",
      confidence: "explicit",
      selected: true
    });
    expect(reviews[0].fields.find((field) => field.field === "vocal")).toMatchObject({
      originalValue: "重音テトSV",
      suggestedValue: "重音テト",
      selected: true
    });
    expect(reviews[0].fields.find((field) => field.field === "illustrator")).toMatchObject({
      originalValue: "シシア",
      selected: true
    });
    expect(reviews[0].fields.find((field) => field.field === "arranger")).toMatchObject({
      originalValue: "",
      suggestedValue: "",
      selected: false
    });
  });

  it("buildBatchPatchFromTrackReviews saves edited checked values only", () => {
    const reviews = buildVocaDbTrackReviews([baseRow], baseAlbum).map((review) => ({
      ...review,
      fields: review.fields.map((field) =>
        field.field === "composer"
          ? { ...field, suggestedValue: "edited composer", selected: true }
          : field.field === "source"
            ? { ...field, selected: false }
            : field
      )
    }));

    expect(buildBatchPatchFromTrackReviews(reviews)).toEqual({
      updates: [
        {
          track_id: 101,
          patch: {
            composer: "edited composer",
            lyricist: "ryo",
            vocal: "Hatsune Miku"
          }
        }
      ]
    });
  });
});
