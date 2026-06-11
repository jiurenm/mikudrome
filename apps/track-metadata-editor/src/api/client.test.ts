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

  it("patchTrackMetadataBatch sends selected updates to the same-origin collection endpoint", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ tracks: [] }), { status: 200 })
    );

    const client = createApiClient();
    await client.patchTrackMetadataBatch({
      updates: [
        {
          track_id: 7,
          patch: { composer: "ryo", lyricist: "ryo" }
        }
      ]
    });

    expect(fetchMock).toHaveBeenCalledWith(
      "/api/tracks/metadata",
      expect.objectContaining({
        method: "PATCH",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          updates: [
            {
              track_id: 7,
              patch: { composer: "ryo", lyricist: "ryo" }
            }
          ]
        })
      })
    );
  });

  it("albumCoverUrl returns the same-origin cover proxy endpoint", () => {
    const client = createApiClient();

    expect(client.albumCoverUrl(42)).toBe("/api/albums/42/cover");
  });

  it("searchVocaDbAlbums calls the public VocaDB API directly", async () => {
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(
        new Response(
          JSON.stringify({
            items: [
              {
                id: 42,
                name: "Miku Expo",
                artistString: "Hatsune Miku",
                releaseDate: {
                  day: 11,
                  isEmpty: false,
                  month: 2,
                  year: 2026
                }
              }
            ]
          }),
          { status: 200 }
        )
      );

    const client = createApiClient();
    const albums = await client.searchVocaDbAlbums("Miku Expo");

    expect(fetchMock).toHaveBeenCalledWith(
      "https://vocadb.net/api/albums?query=Miku+Expo&maxResults=10&getTotalCount=false&fields=MainPicture&lang=Default",
      expect.objectContaining({ method: "GET" })
    );
    expect(albums).toEqual([
      {
        id: 42,
        name: "Miku Expo",
        artistString: "Hatsune Miku",
        url: "https://vocadb.net/Al/42",
        releaseDate: "2026-02-11"
      }
    ]);
  });

  it("getVocaDbAlbum calls the public VocaDB album APIs directly", async () => {
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            id: 42,
            name: "Album",
            artistString: "Artist",
            tracks: [
              {
                discNumber: 1,
                trackNumber: 1,
                song: {
                  id: 100,
                  name: "Sharing The World",
                  artists: [
                    { name: "BIGHEAD", roles: "Producer" },
                    { name: "Hatsune Miku", roles: ["Vocalist"] }
                  ]
                }
              }
            ]
          }),
          { status: 200 }
        )
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify([
            {
              discNumber: 1,
              trackNumber: 1,
              title: "Sharing The World",
              producers: "BIGHEAD, kz",
              vocalists: "Hatsune Miku",
              url: "https://vocadb.net/S/100"
            }
          ]),
          { status: 200 }
        )
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ artists: [] }), { status: 200 })
      );

    const client = createApiClient();
    const album = await client.getVocaDbAlbum(42);

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      "https://vocadb.net/api/albums/42?fields=Artists%2CTracks&lang=Default",
      expect.objectContaining({ method: "GET" })
    );
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      "https://vocadb.net/api/albums/42/tracks/fields?fields=title%2Cproducers%2Cvocalists%2Curl&lang=Default",
      expect.objectContaining({ method: "GET" })
    );
    expect(fetchMock).toHaveBeenNthCalledWith(
      3,
      "https://vocadb.net/api/songs/100/details?albumId=42",
      expect.objectContaining({ method: "GET" })
    );
    expect(album).toEqual({
      id: 42,
      name: "Album",
      artistString: "Artist",
      url: "https://vocadb.net/Al/42",
      tracks: [
        {
          discNumber: 1,
          trackNumber: 1,
          title: "Sharing The World",
          songId: 100,
          url: "https://vocadb.net/S/100",
          producers: ["BIGHEAD", "kz"],
          vocalists: ["Hatsune Miku"],
          artists: [
            { name: "BIGHEAD", roles: ["Producer"] },
            { name: "Hatsune Miku", roles: ["Vocalist"] }
          ]
        }
      ]
    });
  });

  it("getVocaDbAlbum accepts track fields keyed only by song id", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            id: 42,
            name: "Album",
            artistString: "Artist",
            songs: [
              {
                discNumber: 1,
                trackNumber: 1,
                song: {
                  id: 100,
                  name: "Original Title",
                  artistString: "ryo feat. Hatsune Miku V6",
                  artists: []
                }
              }
            ]
          }),
          { status: 200 }
        )
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify([
            {
              id: "100",
              title: "Sharing The World"
            }
          ]),
          { status: 200 }
        )
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ artists: [] }), { status: 200 })
      );

    const client = createApiClient();
    const album = await client.getVocaDbAlbum(42);

    expect(album.tracks).toEqual([
      {
        discNumber: 1,
        trackNumber: 1,
        title: "Sharing The World",
        songId: 100,
        url: "https://vocadb.net/S/100",
        producers: ["ryo"],
        vocalists: ["Hatsune Miku V6"],
        artists: []
      }
    ]);
  });

  it("getVocaDbAlbum loads song detail artists and merges roles with categories", async () => {
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            id: 51194,
            name: "0401 - The Best Days of 重音テト 2026",
            artistString: "Various artists",
            tracks: [
              {
                discNumber: 1,
                trackNumber: 1,
                name: "オーバーライド",
                song: {
                  id: 557307,
                  name: "オーバーライド",
                  artistString: "吉田夜世 feat. 重音テトSV"
                }
              }
            ]
          }),
          { status: 200 }
        )
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify([{ id: "557307", title: "オーバーライド" }]), { status: 200 })
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            artists: [
              {
                name: "シシア",
                categories: "Illustrator",
                effectiveRoles: "Illustrator",
                roles: "Illustrator"
              },
              {
                name: "吉田夜世",
                categories: "Producer, Animator",
                effectiveRoles: "Animator, Composer, Lyricist, Mastering, Mixer",
                roles: "Animator, Composer, Lyricist, Mastering, Mixer"
              },
              {
                name: "重音テトSV",
                categories: "Vocalist",
                effectiveRoles: "Default",
                roles: "Default"
              }
            ]
          }),
          { status: 200 }
        )
      );

    const album = await createApiClient().getVocaDbAlbum(51194);

    expect(fetchMock).toHaveBeenNthCalledWith(
      3,
      "https://vocadb.net/api/songs/557307/details?albumId=51194",
      expect.objectContaining({ method: "GET" })
    );
    expect(album.tracks[0].artists).toEqual([
      { name: "シシア", roles: ["Illustrator"] },
      {
        name: "吉田夜世",
        roles: ["Animator", "Composer", "Lyricist", "Mastering", "Mixer", "Producer"]
      },
      { name: "重音テトSV", roles: ["Vocalist"] }
    ]);
  });

  it("getVocaDbAlbum preserves track artists when song detail loading fails", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            id: 42,
            name: "Album",
            artistString: "Artist",
            tracks: [
              {
                discNumber: 1,
                trackNumber: 1,
                song: {
                  id: 100,
                  name: "Sharing The World",
                  artists: [{ name: "Album Artist", roles: "Producer" }]
                }
              }
            ]
          }),
          { status: 200 }
        )
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify([
            {
              discNumber: 1,
              trackNumber: 1,
              title: "Sharing The World",
              producers: "Album Artist",
              vocalists: "",
              url: "https://vocadb.net/S/100"
            }
          ]),
          { status: 200 }
        )
      )
      .mockResolvedValueOnce(new Response("failed", { status: 500 }));

    const album = await createApiClient().getVocaDbAlbum(42);

    expect(album.tracks[0].artists).toEqual([{ name: "Album Artist", roles: ["Producer"] }]);
  });

  it("getVocaDbAlbum fetches duplicate song details once and applies them to matching tracks", async () => {
    const detailCalls: string[] = [];
    const fetchMock = vi.spyOn(globalThis, "fetch").mockImplementation(async (input) => {
      const url = String(input);
      if (url === "https://vocadb.net/api/albums/42?fields=Artists%2CTracks&lang=Default") {
        return new Response(
          JSON.stringify({
            id: 42,
            name: "Album",
            artistString: "Artist",
            tracks: [
              {
                discNumber: 1,
                trackNumber: 1,
                song: { id: 100, name: "Sharing The World", artists: [] }
              },
              {
                discNumber: 1,
                trackNumber: 2,
                song: { id: 100, name: "Sharing The World (Repeat)", artists: [] }
              }
            ]
          }),
          { status: 200 }
        );
      }
      if (
        url ===
        "https://vocadb.net/api/albums/42/tracks/fields?fields=title%2Cproducers%2Cvocalists%2Curl&lang=Default"
      ) {
        return new Response(
          JSON.stringify([
            {
              discNumber: 1,
              trackNumber: 1,
              title: "Sharing The World",
              producers: "",
              vocalists: "",
              url: "https://vocadb.net/S/100"
            },
            {
              discNumber: 1,
              trackNumber: 2,
              title: "Sharing The World (Repeat)",
              producers: "",
              vocalists: "",
              url: "https://vocadb.net/S/100"
            }
          ]),
          { status: 200 }
        );
      }
      if (url === "https://vocadb.net/api/songs/100/details?albumId=42") {
        detailCalls.push(url);
        return new Response(
          JSON.stringify({
            artists: [{ name: "Detail Artist", effectiveRoles: "Composer", roles: "Composer" }]
          }),
          { status: 200 }
        );
      }
      throw new Error(`Unexpected request: ${url}`);
    });

    const album = await createApiClient().getVocaDbAlbum(42);

    expect(detailCalls).toHaveLength(1);
    expect(fetchMock).toHaveBeenCalledTimes(3);
    expect(album.tracks.map((track) => track.artists)).toEqual([
      [{ name: "Detail Artist", roles: ["Composer"] }],
      [{ name: "Detail Artist", roles: ["Composer"] }]
    ]);
  });

  it("getVocaDbAlbum limits concurrent song detail requests", async () => {
    let activeDetailRequests = 0;
    let maxActiveDetailRequests = 0;
    const songIds = [100, 101, 102, 103, 104, 105];
    vi.spyOn(globalThis, "fetch").mockImplementation(async (input) => {
      const url = String(input);
      if (url === "https://vocadb.net/api/albums/42?fields=Artists%2CTracks&lang=Default") {
        return new Response(
          JSON.stringify({
            id: 42,
            name: "Album",
            artistString: "Artist",
            tracks: songIds.map((songId, index) => ({
              discNumber: 1,
              trackNumber: index + 1,
              song: { id: songId, name: `Track ${index + 1}`, artists: [] }
            }))
          }),
          { status: 200 }
        );
      }
      if (
        url ===
        "https://vocadb.net/api/albums/42/tracks/fields?fields=title%2Cproducers%2Cvocalists%2Curl&lang=Default"
      ) {
        return new Response(
          JSON.stringify(
            songIds.map((songId, index) => ({
              discNumber: 1,
              trackNumber: index + 1,
              title: `Track ${index + 1}`,
              producers: "",
              vocalists: "",
              url: `https://vocadb.net/S/${songId}`
            }))
          ),
          { status: 200 }
        );
      }

      const songId = songIds.find(
        (candidate) => url === `https://vocadb.net/api/songs/${candidate}/details?albumId=42`
      );
      if (songId != null) {
        activeDetailRequests += 1;
        maxActiveDetailRequests = Math.max(maxActiveDetailRequests, activeDetailRequests);
        return new Promise<Response>((resolve) => {
          setTimeout(() => {
            activeDetailRequests -= 1;
            resolve(
              new Response(
                JSON.stringify({
                  artists: [
                    {
                      name: `Detail Artist ${songId}`,
                      effectiveRoles: "Composer",
                      roles: "Composer"
                    }
                  ]
                }),
                { status: 200 }
              )
            );
          }, 0);
        });
      }

      throw new Error(`Unexpected request: ${url}`);
    });

    await createApiClient().getVocaDbAlbum(42);

    expect(maxActiveDetailRequests).toBeLessThanOrEqual(4);
  });
});
