import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { createApiClient } from "./client";
import { buildApiUrl, resolveApiBaseUrl, resolveApiCookie, selectApiBaseUrl } from "./config";

declare global {
  interface Window {
    __APP_CONFIG__?: {
      apiBaseUrl?: string;
      cookie?: string;
    };
  }
}

describe("api client", () => {
  beforeEach(() => {
    window.__APP_CONFIG__ = undefined;
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("listTrackMetadata loads from configured base URL and sends GET", async () => {
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(new Response(JSON.stringify({ tracks: [] }), { status: 200 }));

    const client = createApiClient("http://127.0.0.1:8080");
    await client.listTrackMetadata();

    expect(fetchMock).toHaveBeenCalledWith(
      "http://127.0.0.1:8080/api/tracks/metadata",
      expect.objectContaining({ method: "GET" })
    );
  });

  it("listTrackMetadata sends the configured cookie when present", async () => {
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(new Response(JSON.stringify({ tracks: [] }), { status: 200 }));

    const client = createApiClient("http://127.0.0.1:8080", "session=abc; theme=dark");
    await client.listTrackMetadata();

    expect(fetchMock).toHaveBeenCalledWith(
      "http://127.0.0.1:8080/api/tracks/metadata",
      expect.objectContaining({
        method: "GET",
        headers: {
          Cookie: "session=abc; theme=dark"
        }
      })
    );
  });

  it("patchTrackMetadata sends only provided fields in PATCH body", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify({
          id: 7,
          title: "Track",
          track_number: 1,
          disc_number: 1,
          album_id: 10,
          album_title: "Album",
          album_cover_path: "",
          producer_id: 2,
          producer_name: "Producer",
          composer: "kz",
          lyricist: "",
          arranger: "",
          remix: "",
          vocal: "",
          voice_manipulator: "",
          illustrator: "",
          movie: "",
          source: "YouTube",
          composer_source: "manual",
          lyricist_source: "empty"
        }),
        { status: 200 }
      )
    );

    const client = createApiClient("http://127.0.0.1:8080");
    await client.patchTrackMetadata(7, { composer: "kz" });

    expect(fetchMock).toHaveBeenCalledWith(
      "http://127.0.0.1:8080/api/tracks/7/metadata",
      expect.objectContaining({
        method: "PATCH",
        body: JSON.stringify({ composer: "kz" })
      })
    );
  });

  it("patchTrackMetadata sends the configured cookie with the JSON headers", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify({
          id: 7,
          title: "Track",
          track_number: 1,
          disc_number: 1,
          album_id: 10,
          album_title: "Album",
          album_cover_path: "",
          producer_id: 2,
          producer_name: "Producer",
          composer: "kz",
          lyricist: "",
          arranger: "",
          remix: "",
          vocal: "",
          voice_manipulator: "",
          illustrator: "",
          movie: "",
          source: "YouTube",
          composer_source: "manual",
          lyricist_source: "empty"
        }),
        { status: 200 }
      )
    );

    const client = createApiClient("http://127.0.0.1:8080", "session=abc");
    await client.patchTrackMetadata(7, { composer: "kz" });

    expect(fetchMock).toHaveBeenCalledWith(
      "http://127.0.0.1:8080/api/tracks/7/metadata",
      expect.objectContaining({
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Cookie: "session=abc"
        },
        body: JSON.stringify({ composer: "kz" })
      })
    );
  });

  it("albumCoverUrl resolves against the configured base URL", () => {
    const client = createApiClient("http://127.0.0.1:8080/");

    expect(client.albumCoverUrl(42)).toBe("http://127.0.0.1:8080/api/albums/42/cover");
  });
});

describe("runtime config", () => {
  beforeEach(() => {
    window.__APP_CONFIG__ = undefined;
  });

  it("builds relative api urls when no base url exists", () => {
    expect(buildApiUrl("/api/tracks/metadata", "")).toBe("/api/tracks/metadata");
  });

  it("prefers a runtime base url over build-time fallback", () => {
    expect(selectApiBaseUrl("http://127.0.0.1:8080/", "http://build.example:8080")).toBe(
      "http://127.0.0.1:8080/"
    );
  });

  it("falls back to build-time base url when runtime value is empty", () => {
    expect(selectApiBaseUrl("  ", "http://build.example:8080/")).toBe(
      "http://build.example:8080/"
    );
  });

  it("reads the runtime base url from window config", () => {
    window.__APP_CONFIG__ = { apiBaseUrl: "http://127.0.0.1:8080/" };

    expect(resolveApiBaseUrl()).toBe("http://127.0.0.1:8080/");
  });

  it("reads and trims the runtime cookie from window config", () => {
    window.__APP_CONFIG__ = { cookie: " session=abc " };

    expect(resolveApiCookie()).toBe("session=abc");
  });
});
