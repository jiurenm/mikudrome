import type { TrackMetadataPatch, TrackMetadataRow } from "../../api/types";

export interface TrackMetadataDraft {
  composer: string;
  lyricist: string;
  arranger: string;
  remix: string;
  vocal: string;
  voice_manipulator: string;
  illustrator: string;
  movie: string;
  source: string;
}

export interface AlbumGroup {
  album: {
    id: number;
    title: string;
    coverPath: string;
    producerName: string;
  };
  tracks: TrackMetadataRow[];
}

export const editableKeys = [
  "composer",
  "lyricist",
  "arranger",
  "remix",
  "vocal",
  "voice_manipulator",
  "illustrator",
  "movie",
  "source"
] as const;

export function createDraftFromRow(row: TrackMetadataRow): TrackMetadataDraft {
  return {
    composer: row.composer,
    lyricist: row.lyricist,
    arranger: row.arranger,
    remix: row.remix,
    vocal: row.vocal,
    voice_manipulator: row.voice_manipulator,
    illustrator: row.illustrator,
    movie: row.movie,
    source: row.source
  };
}

export function hasDraftChanges(row: TrackMetadataRow, draft: TrackMetadataDraft): boolean {
  return editableKeys.some((key) => row[key] !== draft[key]);
}

export function buildPatchPayload(row: TrackMetadataRow, draft: TrackMetadataDraft): TrackMetadataPatch {
  const payload: TrackMetadataPatch = {};

  for (const key of editableKeys) {
    if (row[key] !== draft[key]) {
      payload[key] = draft[key];
    }
  }

  return payload;
}

export function matchesSearch(row: TrackMetadataRow, searchTerm: string): boolean {
  const normalizedTerm = searchTerm.trim().toLowerCase();
  if (normalizedTerm === "") {
    return true;
  }

  return (
    row.album_title.toLowerCase().includes(normalizedTerm) ||
    row.producer_name.toLowerCase().includes(normalizedTerm) ||
    row.title.toLowerCase().includes(normalizedTerm)
  );
}

export function buildAlbumGroups(rows: TrackMetadataRow[]): AlbumGroup[] {
  const groupsByAlbum = new Map<number, AlbumGroup>();

  for (const row of rows) {
    let group = groupsByAlbum.get(row.album_id);
    if (group == null) {
      group = {
        album: {
          id: row.album_id,
          title: row.album_title,
          coverPath: row.album_cover_path,
          producerName: row.producer_name
        },
        tracks: []
      };
      groupsByAlbum.set(row.album_id, group);
    }
    group.tracks.push(row);
  }

  const groups = Array.from(groupsByAlbum.values());
  for (const group of groups) {
    group.tracks.sort(
      (left, right) => left.disc_number - right.disc_number || left.track_number - right.track_number
    );
  }

  groups.sort((left, right) => left.album.title.localeCompare(right.album.title));
  return groups;
}
