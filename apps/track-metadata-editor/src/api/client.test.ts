import { afterEach, describe, expect, it, vi } from "vitest";
import { createApiClient } from "./client";

describe("api client", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("listTrackMetadata loads from the same-origin metadata endpoint", async () => {
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(new Response(JSON.stringify({ tracks: [] }), { status: 200 }));

    const client = createApiClient();
    await client.listTrackMetadata();

    expect(fetchMock).toHaveBeenCalledWith(
      "/api/tracks/metadata",
      expect.objectContaining({ method: "GET" })
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

    const client = createApiClient();
    await client.patchTrackMetadata(7, { composer: "kz" });

    expect(fetchMock).toHaveBeenCalledWith(
      "/api/tracks/7/metadata",
      expect.objectContaining({
        method: "PATCH",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ composer: "kz" })
      })
    );
  });

  it("albumCoverUrl returns the same-origin cover proxy endpoint", () => {
    const client = createApiClient();

    expect(client.albumCoverUrl(42)).toBe("/api/albums/42/cover");
  });
});
