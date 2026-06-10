import type {
  VocaDbAlbumCandidate,
  VocaDbAlbumDetail,
  VocaDbAlbumTrack,
  VocaDbArtistRoleCredit
} from "../api/types";

const VOCADB_BASE_URL = "https://vocadb.net";
const USER_AGENT = "mikudrome-track-metadata-editor/0.1";
const VOCADB_TIMEOUT_MS = 10000;

export class VocaDbProxyError extends Error {
  status: number;

  constructor(message: string, status: number) {
    super(message);
    this.name = "VocaDbProxyError";
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
      headers: new Headers({
        accept: "application/json",
        "user-agent": USER_AGENT
      }),
      cache: "no-store",
      signal: AbortSignal.timeout(VOCADB_TIMEOUT_MS)
    });
  } catch {
    throw new VocaDbProxyError("Failed to reach VocaDB.", 502);
  }

  if (!response.ok) {
    throw new VocaDbProxyError("VocaDB returned an error.", response.status);
  }

  return readVocaDbJson<T>(response);
}

async function readVocaDbJson<T>(response: Response): Promise<T> {
  try {
    return (await response.json()) as T;
  } catch {
    throw new VocaDbProxyError("Malformed VocaDB response.", 502);
  }
}

function malformedVocaDbResponse(): never {
  throw new VocaDbProxyError("Malformed VocaDB response.", 502);
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

function albumUrl(albumId: number): string {
  return `${VOCADB_BASE_URL}/Al/${albumId}`;
}

function songUrl(songId: number): string {
  return `${VOCADB_BASE_URL}/S/${songId}`;
}

function normalizeString(value: unknown): string {
  return expectOptionalString(value) ?? "";
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
        roles: normalizeRoles(artistRecord.roles ?? artistRecord.categories)
      };
    })
    .filter((artist) => artist.name !== "");
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
    releaseDate: normalizeString(itemRecord.releaseDate)
  };
}

function normalizeTrack(rawSong: unknown, fieldsByTrack: Map<string, JsonRecord>): VocaDbAlbumTrack {
  const songTrackRecord = expectRecord(rawSong);
  const discNumber = expectNumber(songTrackRecord.discNumber);
  const trackNumber = expectNumber(songTrackRecord.trackNumber);
  const field = fieldsByTrack.get(trackKey(discNumber, trackNumber));
  const songRecord = songTrackRecord.song == null ? undefined : expectRecord(songTrackRecord.song);
  const songId = songRecord == null ? null : expectNumber(songRecord.id);

  return {
    discNumber,
    trackNumber,
    title: normalizeString(field?.title ?? songRecord?.name),
    songId,
    url: normalizeString(field?.url ?? (songId == null ? "" : songUrl(songId))),
    producers: splitArtistList(field?.producers),
    vocalists: splitArtistList(field?.vocalists),
    artists: normalizeArtistCredits(songRecord?.artists)
  };
}

export async function searchVocaDbAlbums(query: string): Promise<VocaDbAlbumCandidate[]> {
  const trimmedQuery = query.trim();
  if (trimmedQuery === "") {
    return [];
  }

  const data = expectRecord(await fetchVocaDbJson<unknown>(
    buildVocaDbUrl("/api/albums", {
      query: trimmedQuery,
      maxResults: "10",
      getTotalCount: "false",
      fields: "MainPicture",
      lang: "Default"
    })
  ));

  const items = expectArray(data.items);

  return items.map((item) => normalizeSearchItem(item));
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

  const album = expectRecord(albumResponse);
  const albumIdFromResponse = expectNumber(album.id);
  const songs = expectArray(album.songs);
  const fields = expectArray(trackFieldsResponse);

  const fieldsByTrack = new Map(
    fields.map((field) => {
      const fieldRecord = expectRecord(field);
      return [
        trackKey(
          expectNumber(fieldRecord.discNumber),
          expectNumber(fieldRecord.trackNumber)
        ),
        fieldRecord
      ];
    })
  );

  return {
    id: albumIdFromResponse,
    name: normalizeString(album.name),
    artistString: normalizeString(album.artistString),
    url: albumUrl(albumIdFromResponse),
    tracks: songs.map((rawSong) => normalizeTrack(rawSong, fieldsByTrack))
  };
}
