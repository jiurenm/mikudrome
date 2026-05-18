import { buildApiUrl, resolveApiCookie } from "./config";
import type { TrackMetadataPatch, TrackMetadataRow } from "./types";

export class ApiError extends Error {
  status: number;

  constructor(message: string, status: number) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

export interface ApiClient {
  listTrackMetadata(): Promise<TrackMetadataRow[]>;
  patchTrackMetadata(trackId: number, patch: TrackMetadataPatch): Promise<TrackMetadataRow>;
  albumCoverUrl(albumId: number): string;
}

interface TrackListResponse {
  tracks?: TrackMetadataRow[];
}

async function throwApiError(response: Response): Promise<never> {
  const text = await response.text();
  throw new ApiError(text || response.statusText, response.status);
}

function buildRequestHeaders(cookie = "", headers: Record<string, string> = {}): HeadersInit {
  const trimmedCookie = cookie.trim();

  if (!trimmedCookie) {
    return headers;
  }

  return {
    ...headers,
    Cookie: trimmedCookie
  };
}

export function createApiClient(baseUrl?: string, cookie = resolveApiCookie()): ApiClient {
  return {
    async listTrackMetadata() {
      const response = await fetch(buildApiUrl("/api/tracks/metadata", baseUrl), {
        method: "GET",
        headers: buildRequestHeaders(cookie)
      });
      if (!response.ok) {
        await throwApiError(response);
      }

      const data = (await response.json()) as TrackListResponse;
      return data.tracks ?? [];
    },

    async patchTrackMetadata(trackId, patch) {
      const response = await fetch(buildApiUrl(`/api/tracks/${trackId}/metadata`, baseUrl), {
        method: "PATCH",
        headers: buildRequestHeaders(cookie, {
          "Content-Type": "application/json"
        }),
        body: JSON.stringify(patch)
      });
      if (!response.ok) {
        await throwApiError(response);
      }

      return (await response.json()) as TrackMetadataRow;
    },

    albumCoverUrl(albumId) {
      return buildApiUrl(`/api/albums/${albumId}/cover`, baseUrl);
    }
  };
}
