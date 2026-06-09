// @vitest-environment node

import { afterEach, describe, expect, it, vi } from "vitest";
import { GET as getAlbumCover } from "./albums/[albumId]/cover/route";
import { PATCH as patchTrackMetadata } from "./tracks/[trackId]/metadata/route";
import { GET as getTrackMetadata } from "./tracks/metadata/route";

describe("Next API proxy routes", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllEnvs();
  });

  it("forwards metadata list requests to the configured backend", async () => {
    vi.stubEnv("API_BASE_URL", "http://backend.test/");
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ tracks: [] }), {
        status: 200,
        headers: { "content-type": "application/json" }
      })
    );

    const response = await getTrackMetadata();

    expect(fetchMock).toHaveBeenCalledWith(
      "http://backend.test/api/tracks/metadata",
      expect.objectContaining({ method: "GET", cache: "no-store" })
    );
    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toContain("application/json");
    expect(await response.json()).toEqual({ tracks: [] });
  });

  it("forwards patch requests with JSON body and server cookie", async () => {
    vi.stubEnv("API_BASE_URL", "http://backend.test");
    vi.stubEnv("API_COOKIE", "session=abc");
    const savedRow = {
      id: 7,
      title: "Track",
      track_number: 1,
      disc_number: 1,
      album_id: 10,
      album_title: "Album",
      album_cover_path: "",
      producer_id: 2,
      producer_name: "Producer",
      composer: "ryo",
      lyricist: "",
      arranger: "",
      remix: "",
      vocal: "",
      voice_manipulator: "",
      illustrator: "",
      movie: "",
      source: "manual",
      composer_source: "manual",
      lyricist_source: "empty"
    };
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify(savedRow), {
        status: 200,
        headers: { "content-type": "application/json" }
      })
    );
    const body = JSON.stringify({ composer: "ryo" });
    const request = new Request("http://localhost/api/tracks/7/metadata", {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body
    });

    const response = await patchTrackMetadata(request, {
      params: Promise.resolve({ trackId: "7" })
    });

    expect(fetchMock).toHaveBeenCalledWith(
      "http://backend.test/api/tracks/7/metadata",
      expect.objectContaining({ method: "PATCH", body, cache: "no-store" })
    );
    const init = fetchMock.mock.calls[0]?.[1];
    const headers = init?.headers as Headers;
    expect(headers.get("content-type")).toBe("application/json");
    expect(headers.get("cookie")).toBe("session=abc");
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual(savedRow);
  });

  it("forwards album cover responses with image content type", async () => {
    vi.stubEnv("API_BASE_URL", "http://backend.test");
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response("image-bytes", {
        status: 200,
        headers: { "content-type": "image/jpeg" }
      })
    );

    const response = await getAlbumCover(new Request("http://localhost/api/albums/42/cover"), {
      params: Promise.resolve({ albumId: "42" })
    });

    expect(fetchMock).toHaveBeenCalledWith(
      "http://backend.test/api/albums/42/cover",
      expect.objectContaining({ method: "GET", cache: "no-store" })
    );
    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toBe("image/jpeg");
    expect(await response.text()).toBe("image-bytes");
  });

  it("passes through backend error status and body", async () => {
    vi.stubEnv("API_BASE_URL", "http://backend.test");
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response("save failed", {
        status: 502,
        headers: { "content-type": "text/plain" }
      })
    );
    const request = new Request("http://localhost/api/tracks/7/metadata", {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ composer: "ryo" })
    });

    const response = await patchTrackMetadata(request, {
      params: Promise.resolve({ trackId: "7" })
    });

    expect(response.status).toBe(502);
    expect(response.headers.get("content-type")).toContain("text/plain");
    expect(await response.text()).toBe("save failed");
  });

  it("returns 500 when API_BASE_URL is missing", async () => {
    vi.stubEnv("API_BASE_URL", "");
    const fetchMock = vi.spyOn(globalThis, "fetch");

    const response = await getTrackMetadata();

    expect(fetchMock).not.toHaveBeenCalled();
    expect(response.status).toBe(500);
    expect(await response.json()).toEqual({ error: "API_BASE_URL is not configured." });
  });
});
