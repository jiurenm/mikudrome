// @vitest-environment node

import { afterEach, describe, expect, it, vi } from "vitest";
import { GET as getVocaDbAlbum } from "./albums/[albumId]/route";
import { GET as searchVocaDbAlbums } from "./albums/search/route";

describe("VocaDB API proxy routes", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("maps VocaDB album search results to normalized album candidates", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify({
          items: [
            {
              id: 42,
              name: "Miku Expo",
              artistString: "Hatsune Miku",
              releaseDate: "2016-05-01"
            }
          ]
        }),
        { status: 200, headers: { "content-type": "application/json" } }
      )
    );

    const response = await searchVocaDbAlbums(
      new Request("http://localhost/api/vocadb/albums/search?query=Miku%20Expo")
    );

    expect(fetchMock).toHaveBeenCalledWith(
      "https://vocadb.net/api/albums?query=Miku+Expo&maxResults=10&getTotalCount=false&fields=MainPicture&lang=Default",
      expect.objectContaining({
        method: "GET",
        headers: expect.any(Headers),
        cache: "no-store",
        signal: expect.any(AbortSignal)
      })
    );
    const headers = fetchMock.mock.calls[0]?.[1]?.headers as Headers;
    expect(headers.get("accept")).toBe("application/json");
    expect(headers.get("user-agent")).toBe("mikudrome-track-metadata-editor/0.1");
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      albums: [
        {
          id: 42,
          name: "Miku Expo",
          artistString: "Hatsune Miku",
          url: "https://vocadb.net/Al/42",
          releaseDate: "2016-05-01"
        }
      ]
    });
  });

  it("combines album tracks and track fields into normalized VocaDB album detail", async () => {
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            id: 42,
            name: "Miku Expo",
            artistString: "Hatsune Miku",
            songs: [
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
              },
              {
                discNumber: 1,
                trackNumber: 2,
                song: null
              }
            ]
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        )
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify([
            {
              discNumber: 1,
              trackNumber: 1,
              title: "Sharing The World",
              producers: "BIGHEAD, kz; livetune feat. Mitchie M",
              vocalists: "Hatsune Miku、Megurine Luka / Kagamine Rin",
              url: "https://vocadb.net/S/100"
            },
            {
              discNumber: 1,
              trackNumber: 2,
              title: "Interlude",
              producers: "",
              vocalists: null,
              url: ""
            }
          ]),
          { status: 200, headers: { "content-type": "application/json" } }
        )
      );

    const response = await getVocaDbAlbum(
      new Request("http://localhost/api/vocadb/albums/42"),
      { params: Promise.resolve({ albumId: "42" }) }
    );

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      "https://vocadb.net/api/albums/42?fields=Artists%2CTracks&lang=Default",
      expect.objectContaining({
        method: "GET",
        headers: expect.any(Headers),
        cache: "no-store"
      })
    );
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      "https://vocadb.net/api/albums/42/tracks/fields?fields=title%2Cproducers%2Cvocalists%2Curl&lang=Default",
      expect.objectContaining({
        method: "GET",
        headers: expect.any(Headers),
        cache: "no-store"
      })
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      album: {
        id: 42,
        name: "Miku Expo",
        artistString: "Hatsune Miku",
        url: "https://vocadb.net/Al/42",
        tracks: [
          {
            discNumber: 1,
            trackNumber: 1,
            title: "Sharing The World",
            songId: 100,
            url: "https://vocadb.net/S/100",
            producers: ["BIGHEAD", "kz", "livetune", "Mitchie M"],
            vocalists: ["Hatsune Miku", "Megurine Luka", "Kagamine Rin"],
            artists: [
              { name: "BIGHEAD", roles: ["Producer"] },
              { name: "Hatsune Miku", roles: ["Vocalist"] }
            ]
          },
          {
            discNumber: 1,
            trackNumber: 2,
            title: "Interlude",
            songId: null,
            url: "",
            producers: [],
            vocalists: [],
            artists: []
          }
        ]
      }
    });
  });

  it("returns 400 for invalid VocaDB album IDs without fetching", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch");

    const response = await getVocaDbAlbum(
      new Request("http://localhost/api/vocadb/albums/nope"),
      { params: Promise.resolve({ albumId: "nope" }) }
    );

    expect(fetchMock).not.toHaveBeenCalled();
    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "Invalid VocaDB album id." });
  });

  it("returns 502 when VocaDB cannot be reached", async () => {
    vi.spyOn(globalThis, "fetch").mockRejectedValue(new Error("getaddrinfo ENOTFOUND vocadb.net"));

    const response = await searchVocaDbAlbums(
      new Request("http://localhost/api/vocadb/albums/search?query=Miku")
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({ error: "Failed to reach VocaDB." });
  });

  it("returns 502 when VocaDB returns invalid JSON", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response("{not-json", {
        status: 200,
        headers: { "content-type": "application/json" }
      })
    );

    const response = await searchVocaDbAlbums(
      new Request("http://localhost/api/vocadb/albums/search?query=Miku")
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({ error: "Malformed VocaDB response." });
  });

  it("returns 502 when VocaDB search items is not an array", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ items: { id: 42 } }), {
        status: 200,
        headers: { "content-type": "application/json" }
      })
    );

    const response = await searchVocaDbAlbums(
      new Request("http://localhost/api/vocadb/albums/search?query=Miku")
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({ error: "Malformed VocaDB response." });
  });

  it("returns 502 when VocaDB search item elements are malformed", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ items: [null] }), {
        status: 200,
        headers: { "content-type": "application/json" }
      })
    );

    const response = await searchVocaDbAlbums(
      new Request("http://localhost/api/vocadb/albums/search?query=Miku")
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({ error: "Malformed VocaDB response." });
  });

  it("returns 502 when VocaDB search response omits items", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({}), {
        status: 200,
        headers: { "content-type": "application/json" }
      })
    );

    const response = await searchVocaDbAlbums(
      new Request("http://localhost/api/vocadb/albums/search?query=Miku")
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({ error: "Malformed VocaDB response." });
  });

  it("returns 502 when VocaDB search item id is missing", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ items: [{ name: "Miku Expo", artistString: "Hatsune Miku" }] }), {
        status: 200,
        headers: { "content-type": "application/json" }
      })
    );

    const response = await searchVocaDbAlbums(
      new Request("http://localhost/api/vocadb/albums/search?query=Miku")
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({ error: "Malformed VocaDB response." });
  });

  it("returns 502 when VocaDB album track fields is not an array", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            id: 42,
            name: "Miku Expo",
            artistString: "Hatsune Miku",
            songs: []
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        )
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ tracks: [] }), {
          status: 200,
          headers: { "content-type": "application/json" }
        })
      );

    const response = await getVocaDbAlbum(
      new Request("http://localhost/api/vocadb/albums/42"),
      { params: Promise.resolve({ albumId: "42" }) }
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({ error: "Malformed VocaDB response." });
  });

  it("returns 502 when VocaDB album id is missing", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            name: "Miku Expo",
            artistString: "Hatsune Miku",
            songs: []
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        )
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify([]), {
          status: 200,
          headers: { "content-type": "application/json" }
        })
      );

    const response = await getVocaDbAlbum(
      new Request("http://localhost/api/vocadb/albums/42"),
      { params: Promise.resolve({ albumId: "42" }) }
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({ error: "Malformed VocaDB response." });
  });

  it("returns 502 when VocaDB album songs is missing", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            id: 42,
            name: "Miku Expo",
            artistString: "Hatsune Miku"
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        )
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify([]), {
          status: 200,
          headers: { "content-type": "application/json" }
        })
      );

    const response = await getVocaDbAlbum(
      new Request("http://localhost/api/vocadb/albums/42"),
      { params: Promise.resolve({ albumId: "42" }) }
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({ error: "Malformed VocaDB response." });
  });

  it("returns 502 when VocaDB album song elements are malformed", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            id: 42,
            name: "Miku Expo",
            artistString: "Hatsune Miku",
            songs: [null]
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        )
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify([]), {
          status: 200,
          headers: { "content-type": "application/json" }
        })
      );

    const response = await getVocaDbAlbum(
      new Request("http://localhost/api/vocadb/albums/42"),
      { params: Promise.resolve({ albumId: "42" }) }
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({ error: "Malformed VocaDB response." });
  });

  it("returns 502 when VocaDB album song track numbers are missing", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            id: 42,
            name: "Miku Expo",
            artistString: "Hatsune Miku",
            songs: [{ song: null }]
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        )
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify([]), {
          status: 200,
          headers: { "content-type": "application/json" }
        })
      );

    const response = await getVocaDbAlbum(
      new Request("http://localhost/api/vocadb/albums/42"),
      { params: Promise.resolve({ albumId: "42" }) }
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({ error: "Malformed VocaDB response." });
  });

  it("returns 502 when VocaDB album track field elements are malformed", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            id: 42,
            name: "Miku Expo",
            artistString: "Hatsune Miku",
            songs: []
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        )
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify([null]), {
          status: 200,
          headers: { "content-type": "application/json" }
        })
      );

    const response = await getVocaDbAlbum(
      new Request("http://localhost/api/vocadb/albums/42"),
      { params: Promise.resolve({ albumId: "42" }) }
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({ error: "Malformed VocaDB response." });
  });

  it("returns 502 when VocaDB album track field numbers are missing", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            id: 42,
            name: "Miku Expo",
            artistString: "Hatsune Miku",
            songs: []
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        )
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify([{ title: "Sharing The World" }]), {
          status: 200,
          headers: { "content-type": "application/json" }
        })
      );

    const response = await getVocaDbAlbum(
      new Request("http://localhost/api/vocadb/albums/42"),
      { params: Promise.resolve({ albumId: "42" }) }
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({ error: "Malformed VocaDB response." });
  });

  it("returns 502 when VocaDB song artists is not an array", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            id: 42,
            name: "Miku Expo",
            artistString: "Hatsune Miku",
            songs: [
              {
                discNumber: 1,
                trackNumber: 1,
                song: {
                  id: 100,
                  name: "Sharing The World",
                  artists: { name: "BIGHEAD" }
                }
              }
            ]
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        )
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify([
            {
              discNumber: 1,
              trackNumber: 1,
              title: "Sharing The World",
              producers: "",
              vocalists: "",
              url: "https://vocadb.net/S/100"
            }
          ]),
          { status: 200, headers: { "content-type": "application/json" } }
        )
      );

    const response = await getVocaDbAlbum(
      new Request("http://localhost/api/vocadb/albums/42"),
      { params: Promise.resolve({ albumId: "42" }) }
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({ error: "Malformed VocaDB response." });
  });

  it("returns 502 when VocaDB track field producers is not a string", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            id: 42,
            name: "Miku Expo",
            artistString: "Hatsune Miku",
            songs: [
              {
                discNumber: 1,
                trackNumber: 1,
                song: null
              }
            ]
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        )
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify([
            {
              discNumber: 1,
              trackNumber: 1,
              title: "Sharing The World",
              producers: ["BIGHEAD"],
              vocalists: "",
              url: "https://vocadb.net/S/100"
            }
          ]),
          { status: 200, headers: { "content-type": "application/json" } }
        )
      );

    const response = await getVocaDbAlbum(
      new Request("http://localhost/api/vocadb/albums/42"),
      { params: Promise.resolve({ albumId: "42" }) }
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({ error: "Malformed VocaDB response." });
  });

  it("preserves VocaDB non-ok response status", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response("temporarily unavailable", {
        status: 503,
        statusText: "Service Unavailable"
      })
    );

    const response = await searchVocaDbAlbums(
      new Request("http://localhost/api/vocadb/albums/search?query=Miku")
    );

    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ error: "VocaDB returned an error." });
  });
});
