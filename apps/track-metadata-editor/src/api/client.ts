import type {
  TrackMetadataBatchPatch,
  TrackMetadataBatchResponse,
  TrackMetadataPatch,
  TrackMetadataRow,
  VocaDbAlbumCandidate,
  VocaDbAlbumDetail,
  VocaDbAlbumDetailResponse,
  VocaDbAlbumSearchResponse
} from "./types";

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
  patchTrackMetadataBatch(patch: TrackMetadataBatchPatch): Promise<TrackMetadataRow[]>;
  albumCoverUrl(albumId: number): string;
  searchVocaDbAlbums(query: string): Promise<VocaDbAlbumCandidate[]>;
  getVocaDbAlbum(albumId: number): Promise<VocaDbAlbumDetail>;
}

interface TrackListResponse {
  tracks?: TrackMetadataRow[];
}

async function throwApiError(response: Response): Promise<never> {
  const text = await response.text();
  throw new ApiError(text || response.statusText, response.status);
}

export function createApiClient(): ApiClient {
  return {
    async listTrackMetadata() {
      const response = await fetch("/api/tracks/metadata", {
        method: "GET"
      });
      if (!response.ok) {
        await throwApiError(response);
      }

      const data = (await response.json()) as TrackListResponse;
      return data.tracks ?? [];
    },

    async patchTrackMetadata(trackId, patch) {
      const response = await fetch(`/api/tracks/${trackId}/metadata`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify(patch)
      });
      if (!response.ok) {
        await throwApiError(response);
      }

      return (await response.json()) as TrackMetadataRow;
    },

    async patchTrackMetadataBatch(patch) {
      const response = await fetch("/api/tracks/metadata", {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify(patch)
      });
      if (!response.ok) {
        await throwApiError(response);
      }

      const data = (await response.json()) as TrackMetadataBatchResponse;
      return data.tracks;
    },

    albumCoverUrl(albumId) {
      return `/api/albums/${albumId}/cover`;
    },

    async searchVocaDbAlbums(query) {
      const params = new URLSearchParams({ query });
      const response = await fetch(`/api/vocadb/albums/search?${params.toString()}`, {
        method: "GET"
      });
      if (!response.ok) {
        await throwApiError(response);
      }

      const data = (await response.json()) as VocaDbAlbumSearchResponse;
      return data.albums;
    },

    async getVocaDbAlbum(albumId) {
      const response = await fetch(`/api/vocadb/albums/${albumId}`, {
        method: "GET"
      });
      if (!response.ok) {
        await throwApiError(response);
      }

      const data = (await response.json()) as VocaDbAlbumDetailResponse;
      return data.album;
    }
  };
}
