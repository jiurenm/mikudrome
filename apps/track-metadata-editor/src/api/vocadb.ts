import type {
  VocaDbAlbumCandidate,
  VocaDbAlbumDetail,
  VocaDbAlbumTrack,
  VocaDbArtistRoleCredit
} from "./types";

const VOCADB_BASE_URL = "https://vocadb.net";
const VOCADB_TIMEOUT_MS = 10000;

class VocaDbClientError extends Error {
  status: number;

  constructor(message: string, status: number) {
    super(message);
    this.name = "VocaDbClientError";
    this.status = status;
  }
}

type JsonRecord = Record<string, unknown>;

function buildVocaDbUrl(path: string, params: Record<string, string>): string {
  const searchParams = new URLSearchParams(params);
  return `${VOCADB_BASE_URL}${path}?${searchParams.toString()}`;
}

async function fetchVocaDbJson<T>(url: string): Promise<T> {
  let response: Response;
  try {
    response = await fetch(url, {
      method: "GET",
      headers: {
        accept: "application/json"
      },
      cache: "no-store",
      signal: AbortSignal.timeout(VOCADB_TIMEOUT_MS)
    });
  } catch {
    throw new VocaDbClientError("Failed to reach VocaDB.", 502);
  }

  if (!response.ok) {
    const message =
      response.headers.get("cf-mitigated") === "challenge"
        ? "VocaDB request was blocked by Cloudflare."
        : "VocaDB returned an error.";
    throw new VocaDbClientError(message, response.status);
  }

  try {
    return (await response.json()) as T;
  } catch {
    throw new VocaDbClientError("Malformed VocaDB response.", 502);
  }
}

function malformedVocaDbResponse(): never {
  throw new VocaDbClientError("Malformed VocaDB response.", 502);
}

function isRecord(value: unknown): value is JsonRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function expectRecord(value: unknown): JsonRecord {
  if (!isRecord(value)) {
    malformedVocaDbResponse();
  }

  return value;
}

function expectArray(value: unknown): unknown[] {
  if (!Array.isArray(value)) {
    malformedVocaDbResponse();
  }

  return value;
}

function expectOptionalArray(value: unknown): unknown[] {
  if (value == null) {
    return [];
  }

  return expectArray(value);
}

function expectOptionalString(value: unknown): string | undefined {
  if (value == null) {
    return undefined;
  }

  return expectString(value);
}

function expectString(value: unknown): string {
  if (typeof value !== "string") {
    malformedVocaDbResponse();
  }

  return value;
}

function expectNumber(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    malformedVocaDbResponse();
  }

  return value;
}

function expectOptionalNumber(value: unknown): number | undefined {
  if (value == null) {
    return undefined;
  }

  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }

  return expectNumber(value);
}

function albumUrl(albumId: number): string {
  return `${VOCADB_BASE_URL}/Al/${albumId}`;
}

function songUrl(songId: number): string {
  return `${VOCADB_BASE_URL}/S/${songId}`;
}

function normalizeString(value: unknown): string {
  return expectOptionalString(value) ?? "";
}

function normalizeReleaseDate(value: unknown): string {
  if (value == null) {
    return "";
  }

  if (typeof value === "string") {
    return value;
  }

  const dateRecord = expectRecord(value);
  if (dateRecord.isEmpty === true) {
    return "";
  }

  const year = expectOptionalNumber(dateRecord.year);
  if (year == null || year <= 0) {
    return "";
  }

  const month = expectOptionalNumber(dateRecord.month);
  if (month == null || month <= 0) {
    return String(year);
  }

  const day = expectOptionalNumber(dateRecord.day);
  if (day == null || day <= 0) {
    return `${year}-${String(month).padStart(2, "0")}`;
  }

  return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

function splitArtistList(value: unknown): string[] {
  const text = expectOptionalString(value);
  if (text == null) {
    return [];
  }

  return text
    .split(/\s*(?:,|;|、|，|；|\/|／|\bfeat\.?)\s*/i)
    .map((item) => item.trim())
    .filter((item) => item !== "");
}

function splitSongArtistString(value: unknown): { producers: string[]; vocalists: string[] } {
  const text = expectOptionalString(value);
  if (text == null || text.trim() === "") {
    return { producers: [], vocalists: [] };
  }

  const parts = text.split(/\s+feat\.?\s+/i);
  if (parts.length < 2) {
    return { producers: splitArtistList(text), vocalists: [] };
  }

  return {
    producers: splitArtistList(parts[0]),
    vocalists: splitArtistList(parts.slice(1).join(" feat. "))
  };
}

function normalizeRoles(value: unknown): string[] {
  if (value == null) {
    return [];
  }

  if (Array.isArray(value)) {
    return value
      .map((item) => expectString(item).trim())
      .filter((item) => item !== "");
  }

  if (typeof value !== "string") {
    malformedVocaDbResponse();
  }

  return splitArtistList(value);
}

function normalizeArtistCredits(rawArtists: unknown): VocaDbArtistRoleCredit[] {
  const artists = expectOptionalArray(rawArtists);

  return artists
    .map((artist) => {
      const artistRecord = expectRecord(artist);
      return {
        name: normalizeString(artistRecord.name).trim(),
        roles: uniqueStrings(
          [
            ...normalizeRoles(artistRecord.effectiveRoles),
            ...normalizeRoles(artistRecord.roles),
            ...normalizeRoles(artistRecord.categories)
          ].filter((role) => role.toLowerCase() !== "default")
        )
      };
    })
    .filter((artist) => artist.name !== "");
}

function normalizeSongDetailArtists(rawSongDetail: unknown): VocaDbArtistRoleCredit[] {
  const detail = expectRecord(rawSongDetail);
  return normalizeArtistCredits(detail.artists);
}

function uniqueStrings(values: string[]): string[] {
  return Array.from(new Set(values.map((value) => value.trim()).filter(Boolean)));
}

function trackKey(discNumber: number, trackNumber: number): string {
  return `${discNumber}:${trackNumber}`;
}

function normalizeSearchItem(item: unknown): VocaDbAlbumCandidate {
  const itemRecord = expectRecord(item);
  const id = expectNumber(itemRecord.id);

  return {
    id,
    name: normalizeString(itemRecord.name),
    artistString: normalizeString(itemRecord.artistString),
    url: albumUrl(id),
    releaseDate: normalizeReleaseDate(itemRecord.releaseDate)
  };
}

function normalizeTrack(
  rawSong: unknown,
  fieldsByTrack: Map<string, JsonRecord>,
  fieldsBySongId: Map<number, JsonRecord>
): VocaDbAlbumTrack {
  const songTrackRecord = expectRecord(rawSong);
  const discNumber = expectNumber(songTrackRecord.discNumber);
  const trackNumber = expectNumber(songTrackRecord.trackNumber);
  const songRecord = songTrackRecord.song == null ? undefined : expectRecord(songTrackRecord.song);
  const songId = songRecord == null ? null : expectNumber(songRecord.id);
  const field =
    fieldsByTrack.get(trackKey(discNumber, trackNumber)) ??
    (songId == null ? undefined : fieldsBySongId.get(songId));
  const songArtists = splitSongArtistString(songRecord?.artistString);
  const fieldProducers = splitArtistList(field?.producers);
  const fieldVocalists = splitArtistList(field?.vocalists);

  return {
    discNumber,
    trackNumber,
    title: normalizeString(field?.title ?? songRecord?.name),
    songId,
    url: normalizeString(field?.url ?? (songId == null ? "" : songUrl(songId))),
    producers: fieldProducers.length > 0 ? fieldProducers : songArtists.producers,
    vocalists: fieldVocalists.length > 0 ? fieldVocalists : songArtists.vocalists,
    artists: normalizeArtistCredits(songRecord?.artists)
  };
}

function normalizeSearchResponse(rawResponse: unknown): VocaDbAlbumCandidate[] {
  const data = expectRecord(rawResponse);
  const items = expectArray(data.items);
  return items.map((item) => normalizeSearchItem(item));
}

function normalizeAlbumDetailResponse(albumResponse: unknown, trackFieldsResponse: unknown): VocaDbAlbumDetail {
  const album = expectRecord(albumResponse);
  const albumId = expectNumber(album.id);
  const tracks = expectArray(album.songs ?? album.tracks);
  const fields = expectArray(trackFieldsResponse);

  const fieldsByTrack = new Map<string, JsonRecord>();
  const fieldsBySongId = new Map<number, JsonRecord>();

  fields.forEach((field) => {
    const fieldRecord = expectRecord(field);
    const discNumber = expectOptionalNumber(fieldRecord.discNumber);
    const trackNumber = expectOptionalNumber(fieldRecord.trackNumber);
    const songId = expectOptionalNumber(fieldRecord.id);

    if (discNumber != null && trackNumber != null) {
      fieldsByTrack.set(trackKey(discNumber, trackNumber), fieldRecord);
    }

    if (songId != null) {
      fieldsBySongId.set(songId, fieldRecord);
    }
  });

  return {
    id: albumId,
    name: normalizeString(album.name),
    artistString: normalizeString(album.artistString),
    url: albumUrl(albumId),
    tracks: tracks.map((rawSong) => normalizeTrack(rawSong, fieldsByTrack, fieldsBySongId))
  };
}

export async function searchVocaDbAlbums(query: string): Promise<VocaDbAlbumCandidate[]> {
  const trimmedQuery = query.trim();
  if (trimmedQuery === "") {
    return [];
  }

  const response = await fetchVocaDbJson<unknown>(
    buildVocaDbUrl("/api/albums", {
      query: trimmedQuery,
      maxResults: "10",
      getTotalCount: "false",
      fields: "MainPicture",
      lang: "Default"
    })
  );

  return normalizeSearchResponse(response);
}

export async function getVocaDbAlbum(albumId: number): Promise<VocaDbAlbumDetail> {
  const [albumResponse, trackFieldsResponse] = await Promise.all([
    fetchVocaDbJson<unknown>(
      buildVocaDbUrl(`/api/albums/${albumId}`, {
        fields: "Artists,Tracks",
        lang: "Default"
      })
    ),
    fetchVocaDbJson<unknown>(
      buildVocaDbUrl(`/api/albums/${albumId}/tracks/fields`, {
        fields: "title,producers,vocalists,url",
        lang: "Default"
      })
    )
  ]);

  const album = normalizeAlbumDetailResponse(albumResponse, trackFieldsResponse);
  const detailResults = await Promise.all(
    album.tracks.map(async (track) => {
      if (track.songId == null) {
        return [];
      }

      const detail = await fetchVocaDbJson<unknown>(
        buildVocaDbUrl(`/api/songs/${track.songId}/details`, {
          albumId: String(albumId)
        })
      );
      return normalizeSongDetailArtists(detail);
    })
  );

  return {
    ...album,
    tracks: album.tracks.map((track, index) => ({
      ...track,
      artists: detailResults[index].length > 0 ? detailResults[index] : track.artists
    }))
  };
}
