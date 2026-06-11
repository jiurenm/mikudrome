import { cleanup, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { TrackMetadataRow } from "../api/types";
import App from "./App";

function createRow(overrides: Partial<TrackMetadataRow> = {}): TrackMetadataRow {
  return {
    id: 1,
    title: "Glow",
    track_number: 1,
    disc_number: 1,
    album_id: 10,
    album_title: "Miku Works",
    album_cover_path: "/covers/miku-works.jpg",
    producer_id: 101,
    producer_name: "keeno",
    composer: "keeno",
    lyricist: "keeno",
    arranger: "keeno",
    remix: "",
    vocal: "Hatsune Miku",
    voice_manipulator: "keeno",
    illustrator: "No.734",
    movie: "Not-116",
    source: "manual",
    composer_source: "manual",
    lyricist_source: "empty",
    ...overrides
  };
}

async function expandAlbum(user: ReturnType<typeof userEvent.setup>, albumTitle: string) {
  const albumButton = await screen.findByRole("button", { name: albumToggleName(albumTitle) });
  if (albumButton.getAttribute("aria-expanded") === "false") {
    await user.click(albumButton);
  }
  return albumButton;
}

function albumToggleName(albumTitle: string): RegExp {
  return new RegExp(`^[▸▾]\\s*${albumTitle}$`, "i");
}

interface VocaDbCandidateFixture {
  id: number;
  name: string;
  artistString: string;
  releaseDate?: string;
}

interface VocaDbTrackFixture {
  discNumber: number;
  trackNumber: number;
  title: string;
  songId: number;
  url: string;
  producers: string[];
  vocalists: string[];
}

function isVocaDbSearchUrl(url: string): boolean {
  return url.startsWith("https://vocadb.net/api/albums?");
}

function isVocaDbAlbumUrl(url: string, albumId: number): boolean {
  return url.startsWith(`https://vocadb.net/api/albums/${albumId}?`);
}

function isVocaDbTrackFieldsUrl(url: string, albumId: number): boolean {
  return url.startsWith(`https://vocadb.net/api/albums/${albumId}/tracks/fields?`);
}

function isVocaDbSongDetailsUrl(url: string, songId: number, albumId: number): boolean {
  return url === `https://vocadb.net/api/songs/${songId}/details?albumId=${albumId}`;
}

function createVocaDbSearchResponse(candidates: VocaDbCandidateFixture[]): Response {
  return new Response(
    JSON.stringify({
      items: candidates.map((candidate) => ({
        id: candidate.id,
        name: candidate.name,
        artistString: candidate.artistString,
        releaseDate: candidate.releaseDate ?? ""
      }))
    }),
    { status: 200 }
  );
}

function createVocaDbAlbumResponse(
  album: { id: number; name: string; artistString: string },
  tracks: VocaDbTrackFixture[]
): Response {
  return new Response(
    JSON.stringify({
      id: album.id,
      name: album.name,
      artistString: album.artistString,
      songs: tracks.map((track) => ({
        discNumber: track.discNumber,
        trackNumber: track.trackNumber,
        song: {
          id: track.songId,
          name: track.title,
          artists: []
        }
      }))
    }),
    { status: 200 }
  );
}

function createVocaDbTrackFieldsResponse(tracks: VocaDbTrackFixture[]): Response {
  return new Response(
    JSON.stringify(
      tracks.map((track) => ({
        discNumber: track.discNumber,
        trackNumber: track.trackNumber,
        title: track.title,
        producers: track.producers.join(", "),
        vocalists: track.vocalists.join(", "),
        url: track.url
      }))
    ),
    { status: 200 }
  );
}

function createVocaDbSongDetailsResponse(track: VocaDbTrackFixture): Response {
  return new Response(
    JSON.stringify({
      artists: [
        ...track.producers.map((producer) => ({
          name: producer,
          categories: "Producer",
          effectiveRoles: "Composer, Lyricist",
          roles: "Composer, Lyricist"
        })),
        ...track.vocalists.map((vocalist) => ({
          name: vocalist,
          categories: "Vocalist",
          effectiveRoles: "Vocalist",
          roles: "Vocalist"
        }))
      ]
    }),
    { status: 200 }
  );
}

describe("App", () => {
  afterEach(() => {
    cleanup();
    vi.restoreAllMocks();
  });

  it("renders an empty detail state until a track is selected", async () => {
    const row = createRow();
    vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
      const method = init?.method ?? "GET";
      const url = String(input);
      if (method === "GET" && url.endsWith("/api/tracks/metadata")) {
        return new Response(JSON.stringify({ tracks: [row] }), { status: 200 });
      }
      throw new Error(`Unexpected request: ${method} ${url}`);
    });

    render(<App />);

    await screen.findByRole("button", { name: albumToggleName("Miku Works") });
    expect(screen.getByText("Select a track to edit its metadata.")).toBeInTheDocument();
  });

  it("starts with album groups collapsed until an album is expanded", async () => {
    const row = createRow();
    vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
      const method = init?.method ?? "GET";
      const url = String(input);
      if (method === "GET" && url.endsWith("/api/tracks/metadata")) {
        return new Response(JSON.stringify({ tracks: [row] }), { status: 200 });
      }
      throw new Error(`Unexpected request: ${method} ${url}`);
    });

    const user = userEvent.setup();
    render(<App />);

    const albumButton = await screen.findByRole("button", { name: albumToggleName("Miku Works") });
    expect(albumButton).toHaveAttribute("aria-expanded", "false");
    expect(screen.queryByRole("button", { name: /01 glow/i })).not.toBeInTheDocument();

    await user.click(albumButton);

    expect(albumButton).toHaveAttribute("aria-expanded", "true");
    expect(screen.getByRole("button", { name: /01 glow/i })).toBeInTheDocument();
  });

  it("gives album match buttons unique accessible names", async () => {
    const firstRow = createRow();
    const secondRow = createRow({
      id: 2,
      title: "Spark",
      album_id: 11,
      album_title: "Miku Works",
      album_cover_path: "/covers/future-sound.jpg"
    });
    vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
      const method = init?.method ?? "GET";
      const url = String(input);
      if (method === "GET" && url.endsWith("/api/tracks/metadata")) {
        return new Response(JSON.stringify({ tracks: [firstRow, secondRow] }), { status: 200 });
      }
      throw new Error(`Unexpected request: ${method} ${url}`);
    });

    render(<App />);

    expect(await screen.findByRole("button", { name: "Match VocaDB for Miku Works album 10" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Match VocaDB for Miku Works album 11" })).toBeInTheDocument();
  });

  it("loads a track into the editor and saves changes", async () => {
    const row = createRow();
    const savedRow = createRow({ movie: "Mah" });
    const fetchMock = vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
      const method = init?.method ?? "GET";
      const url = String(input);
      if (method === "GET" && url.endsWith("/api/tracks/metadata")) {
        return new Response(JSON.stringify({ tracks: [row] }), { status: 200 });
      }
      if (method === "PATCH" && url.endsWith(`/api/tracks/${row.id}/metadata`)) {
        return new Response(JSON.stringify(savedRow), { status: 200 });
      }
      throw new Error(`Unexpected request: ${method} ${url}`);
    });

    const user = userEvent.setup();
    render(<App />);

    await expandAlbum(user, "Miku Works");
    const trackButton = await screen.findByRole("button", { name: /01 glow/i });
    await user.click(trackButton);

    const movieInput = screen.getByLabelText("movie");
    await user.clear(movieInput);
    await user.type(movieInput, "Mah");
    await user.click(screen.getByRole("button", { name: "Save" }));

    await waitFor(() => expect(screen.getByText("Saved.")).toBeInTheDocument());
    expect(screen.getByLabelText("movie")).toHaveValue("Mah");
    const patchCall = fetchMock.mock.calls.find(([input, init]) => {
      return String(input).endsWith(`/api/tracks/${row.id}/metadata`) && init?.method === "PATCH";
    });
    expect(patchCall?.[1]).toEqual(
      expect.objectContaining({
        headers: {
          "Content-Type": "application/json"
        }
      })
    );
  });

  it("renders album cover using album cover API endpoint", async () => {
    const row = createRow({
      album_id: 42,
      album_cover_path: "/covers/legacy.jpg"
    });
    vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
      const method = init?.method ?? "GET";
      const url = String(input);
      if (method === "GET" && url.endsWith("/api/tracks/metadata")) {
        return new Response(JSON.stringify({ tracks: [row] }), { status: 200 });
      }
      throw new Error(`Unexpected request: ${method} ${url}`);
    });

    const user = userEvent.setup();
    render(<App />);

    await expandAlbum(user, "Miku Works");
    const trackButton = await screen.findByRole("button", { name: /01 glow/i });
    await user.click(trackButton);

    const coverImage = screen.getByRole("img", { name: /miku works cover/i });
    expect(coverImage).toHaveAttribute("src", expect.stringMatching(/\/api\/albums\/42\/cover$/));
  });

  it("clicking the already-selected dirty track does not confirm and preserves draft", async () => {
    const row = createRow();
    vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
      const method = init?.method ?? "GET";
      const url = String(input);
      if (method === "GET" && url.endsWith("/api/tracks/metadata")) {
        return new Response(JSON.stringify({ tracks: [row] }), { status: 200 });
      }
      throw new Error(`Unexpected request: ${method} ${url}`);
    });

    const confirmSpy = vi.spyOn(window, "confirm").mockReturnValue(true);
    const user = userEvent.setup();
    render(<App />);

    await expandAlbum(user, "Miku Works");
    const trackButton = await screen.findByRole("button", { name: /01 glow/i });
    await user.click(trackButton);

    const movieInput = screen.getByLabelText("movie");
    await user.clear(movieInput);
    await user.type(movieInput, "Edited Movie");

    await user.click(trackButton);

    expect(confirmSpy).not.toHaveBeenCalled();
    expect(screen.getByLabelText("movie")).toHaveValue("Edited Movie");
  });

  it("asks for confirmation before switching tracks with unsaved changes", async () => {
    const firstRow = createRow();
    const secondRow = createRow({
      id: 2,
      title: "Spark",
      track_number: 2,
      producer_id: 102,
      producer_name: "ryo",
      composer: "ryo",
      lyricist: "ryo",
      arranger: "ryo",
      movie: "Second Movie"
    });
    vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
      const method = init?.method ?? "GET";
      const url = String(input);
      if (method === "GET" && url.endsWith("/api/tracks/metadata")) {
        return new Response(JSON.stringify({ tracks: [firstRow, secondRow] }), { status: 200 });
      }
      throw new Error(`Unexpected request: ${method} ${url}`);
    });

    const confirmSpy = vi.spyOn(window, "confirm").mockReturnValue(false);
    const user = userEvent.setup();
    render(<App />);

    await expandAlbum(user, "Miku Works");
    const firstTrackButton = await screen.findByRole("button", { name: /01 glow/i });
    const secondTrackButton = screen.getByRole("button", { name: /02 spark/i });
    await user.click(firstTrackButton);

    const movieInput = screen.getByLabelText("movie");
    await user.clear(movieInput);
    await user.type(movieInput, "Edited Movie");

    await user.click(secondTrackButton);

    expect(confirmSpy).toHaveBeenCalledWith("Discard unsaved changes?");
    expect(screen.getByLabelText("movie")).toHaveValue("Edited Movie");
  });

  it("shows retry on initial load failure and preserves draft on save failure", async () => {
    const row = createRow();
    let loadAttempts = 0;
    vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
      const method = init?.method ?? "GET";
      const url = String(input);
      if (method === "GET" && url.endsWith("/api/tracks/metadata")) {
        loadAttempts += 1;
        if (loadAttempts === 1) {
          return new Response("load failed", { status: 500 });
        }
        return new Response(JSON.stringify({ tracks: [row] }), { status: 200 });
      }
      if (method === "PATCH" && url.endsWith(`/api/tracks/${row.id}/metadata`)) {
        return new Response("save failed", { status: 500 });
      }
      throw new Error(`Unexpected request: ${method} ${url}`);
    });

    const user = userEvent.setup();
    render(<App />);

    await screen.findByText("Failed to load track metadata.");
    const retryButton = screen.getByRole("button", { name: "Retry" });
    await user.click(retryButton);

    await expandAlbum(user, "Miku Works");
    const trackButton = await screen.findByRole("button", { name: /01 glow/i });
    await user.click(trackButton);

    const movieInput = screen.getByLabelText("movie");
    await user.clear(movieInput);
    await user.type(movieInput, "Retry Draft");
    await user.click(screen.getByRole("button", { name: "Save" }));

    await waitFor(() =>
      expect(screen.getByText("Failed to save track metadata.")).toBeInTheDocument()
    );
    expect(screen.getByLabelText("movie")).toHaveValue("Retry Draft");
  });

  it("disables editable inputs while save is in flight", async () => {
    const row = createRow();
    const savedRow = createRow({ movie: "Mah" });
    let resolvePatch: ((response: Response) => void) | null = null;

    vi.spyOn(globalThis, "fetch").mockImplementation((input, init) => {
      const method = init?.method ?? "GET";
      const url = String(input);
      if (method === "GET" && url.endsWith("/api/tracks/metadata")) {
        return Promise.resolve(new Response(JSON.stringify({ tracks: [row] }), { status: 200 }));
      }
      if (method === "PATCH" && url.endsWith(`/api/tracks/${row.id}/metadata`)) {
        return new Promise<Response>((resolve) => {
          resolvePatch = resolve;
        });
      }
      return Promise.reject(new Error(`Unexpected request: ${method} ${url}`));
    });

    const user = userEvent.setup();
    render(<App />);

    await expandAlbum(user, "Miku Works");
    const trackButton = await screen.findByRole("button", { name: /01 glow/i });
    await user.click(trackButton);

    const movieInput = screen.getByLabelText("movie");
    await user.clear(movieInput);
    await user.type(movieInput, "Mah");
    await user.click(screen.getByRole("button", { name: "Save" }));

    await waitFor(() => expect(screen.getByLabelText("movie")).toBeDisabled());

    resolvePatch?.(new Response(JSON.stringify(savedRow), { status: 200 }));
    await waitFor(() => expect(screen.getByText("Saved.")).toBeInTheDocument());
  });

  it("matches an album with VocaDB and saves selected batch metadata", async () => {
    const row = createRow({
      title: "World",
      composer: "",
      lyricist: "",
      vocal: "",
      source: ""
    });
    const savedRow = createRow({
      title: "World",
      composer: "edited ryo",
      lyricist: "ryo",
      vocal: "Hatsune Miku",
      source: "https://vocadb.net/S/100"
    });
    const fetchMock = vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
      const method = init?.method ?? "GET";
      const url = String(input);
      if (method === "GET" && url.endsWith("/api/tracks/metadata")) {
        return new Response(JSON.stringify({ tracks: [row] }), { status: 200 });
      }
      if (method === "GET" && isVocaDbSearchUrl(url)) {
        return createVocaDbSearchResponse([{ id: 42, name: "Miku Works", artistString: "ryo" }]);
      }
      if (method === "GET" && isVocaDbAlbumUrl(url, 42)) {
        return createVocaDbAlbumResponse(
          { id: 42, name: "Miku Works", artistString: "ryo" },
          [
            {
              discNumber: 1,
              trackNumber: 1,
              title: "Glow",
              songId: 100,
              url: "https://vocadb.net/S/100",
              producers: ["ryo"],
              vocalists: ["Hatsune Miku V6"]
            }
          ]
        );
      }
      if (method === "GET" && isVocaDbTrackFieldsUrl(url, 42)) {
        return createVocaDbTrackFieldsResponse([
          {
            discNumber: 1,
            trackNumber: 1,
            title: "Glow",
            songId: 100,
            url: "https://vocadb.net/S/100",
            producers: ["ryo"],
            vocalists: ["Hatsune Miku V6"]
          }
        ]);
      }
      if (method === "GET" && isVocaDbSongDetailsUrl(url, 100, 42)) {
        return createVocaDbSongDetailsResponse({
          discNumber: 1,
          trackNumber: 1,
          title: "Glow",
          songId: 100,
          url: "https://vocadb.net/S/100",
          producers: ["ryo"],
          vocalists: ["Hatsune Miku V6"]
        });
      }
      if (method === "PATCH" && url.endsWith("/api/tracks/metadata")) {
        return new Response(JSON.stringify({ tracks: [savedRow] }), { status: 200 });
      }
      throw new Error(`Unexpected request: ${method} ${url}`);
    });

    const user = userEvent.setup();
    render(<App />);

    await screen.findByRole("button", { name: albumToggleName("Miku Works") });
    await user.click(screen.getByRole("button", { name: /match vocadb/i }));
    await user.click(await screen.findByRole("button", { name: /miku works.*ryo/i }));
    expect(await screen.findByRole("button", { name: /01 World/i })).toBeInTheDocument();
    expect(screen.getByRole("textbox", { name: "composer suggestion" })).toHaveValue("ryo");

    await user.clear(screen.getByRole("textbox", { name: "composer suggestion" }));
    await user.type(screen.getByRole("textbox", { name: "composer suggestion" }), "edited ryo");
    await user.click(screen.getByRole("button", { name: "Save VocaDB metadata" }));

    await waitFor(() => expect(screen.getByText("Saved VocaDB metadata.")).toBeInTheDocument());
    const patchCall = fetchMock.mock.calls.find(([input, init]) => {
      return String(input).endsWith("/api/tracks/metadata") && init?.method === "PATCH";
    });
    expect(JSON.parse(String(patchCall?.[1]?.body))).toEqual({
      updates: [
        {
          track_id: row.id,
          patch: {
            composer: "edited ryo",
            lyricist: "ryo",
            vocal: "Hatsune Miku",
            source: "https://vocadb.net/S/100"
          }
        }
      ]
    });
  });

  it("shows local track context for VocaDB suggestions", async () => {
    const firstRow = createRow({
      composer: "",
      lyricist: "",
      vocal: "",
      source: ""
    });
    const secondRow = createRow({
      id: 2,
      title: "Spark",
      track_number: 2,
      composer: "",
      lyricist: "",
      vocal: "",
      source: ""
    });
    vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
      const method = init?.method ?? "GET";
      const url = String(input);
      if (method === "GET" && url.endsWith("/api/tracks/metadata")) {
        return new Response(JSON.stringify({ tracks: [firstRow, secondRow] }), { status: 200 });
      }
      if (method === "GET" && isVocaDbSearchUrl(url)) {
        return createVocaDbSearchResponse([{ id: 42, name: "Miku Works", artistString: "ryo" }]);
      }
      if (method === "GET" && isVocaDbAlbumUrl(url, 42)) {
        return createVocaDbAlbumResponse(
          { id: 42, name: "Miku Works", artistString: "ryo" },
          [
            {
              discNumber: 1,
              trackNumber: 1,
              title: "Glow",
              songId: 100,
              url: "https://vocadb.net/S/100",
              producers: ["ryo"],
              vocalists: ["Hatsune Miku V6"]
            },
            {
              discNumber: 1,
              trackNumber: 2,
              title: "Spark",
              songId: 101,
              url: "https://vocadb.net/S/101",
              producers: ["ryo"],
              vocalists: ["Hatsune Miku V6"]
            }
          ]
        );
      }
      if (method === "GET" && isVocaDbTrackFieldsUrl(url, 42)) {
        return createVocaDbTrackFieldsResponse([
          {
            discNumber: 1,
            trackNumber: 1,
            title: "Glow",
            songId: 100,
            url: "https://vocadb.net/S/100",
            producers: ["ryo"],
            vocalists: ["Hatsune Miku V6"]
          },
          {
            discNumber: 1,
            trackNumber: 2,
            title: "Spark",
            songId: 101,
            url: "https://vocadb.net/S/101",
            producers: ["ryo"],
            vocalists: ["Hatsune Miku V6"]
          }
        ]);
      }
      if (method === "GET" && isVocaDbSongDetailsUrl(url, 100, 42)) {
        return createVocaDbSongDetailsResponse({
          discNumber: 1,
          trackNumber: 1,
          title: "Glow",
          songId: 100,
          url: "https://vocadb.net/S/100",
          producers: ["ryo"],
          vocalists: ["Hatsune Miku V6"]
        });
      }
      if (method === "GET" && isVocaDbSongDetailsUrl(url, 101, 42)) {
        return createVocaDbSongDetailsResponse({
          discNumber: 1,
          trackNumber: 2,
          title: "Spark",
          songId: 101,
          url: "https://vocadb.net/S/101",
          producers: ["ryo"],
          vocalists: ["Hatsune Miku V6"]
        });
      }
      throw new Error(`Unexpected request: ${method} ${url}`);
    });

    const user = userEvent.setup();
    render(<App />);

    await screen.findByRole("button", { name: albumToggleName("Miku Works") });
    await user.click(screen.getByRole("button", { name: /match vocadb/i }));
    await user.click(await screen.findByRole("button", { name: /miku works.*ryo/i }));

    expect(await screen.findAllByText("01 Glow")).not.toHaveLength(0);
    expect(screen.getAllByText("02 Spark")).not.toHaveLength(0);
  });

  it("confirms before discarding selected VocaDB suggestions", async () => {
    const firstRow = createRow({
      composer: "",
      lyricist: "",
      vocal: "",
      source: ""
    });
    const secondRow = createRow({
      id: 2,
      title: "Spark",
      album_id: 11,
      album_title: "Future Sound",
      album_cover_path: "/covers/future-sound.jpg"
    });
    const fetchMock = vi.spyOn(globalThis, "fetch").mockImplementation((input, init) => {
      const method = init?.method ?? "GET";
      const url = String(input);
      if (method === "GET" && url.endsWith("/api/tracks/metadata")) {
        return Promise.resolve(new Response(JSON.stringify({ tracks: [firstRow, secondRow] }), { status: 200 }));
      }
      if (method === "GET" && isVocaDbSearchUrl(url)) {
        return Promise.resolve(
          createVocaDbSearchResponse([
            { id: 42, name: "Miku Works", artistString: "ryo" },
            { id: 99, name: "Other Works", artistString: "kz" }
          ])
        );
      }
      if (method === "GET" && isVocaDbAlbumUrl(url, 42)) {
        return Promise.resolve(
          createVocaDbAlbumResponse(
            { id: 42, name: "Miku Works", artistString: "ryo" },
            [
              {
                discNumber: 1,
                trackNumber: 1,
                title: "Glow",
                songId: 100,
                url: "https://vocadb.net/S/100",
                producers: ["ryo"],
                vocalists: ["Hatsune Miku V6"]
              }
            ]
          )
        );
      }
      if (method === "GET" && isVocaDbTrackFieldsUrl(url, 42)) {
        return Promise.resolve(
          createVocaDbTrackFieldsResponse([
            {
              discNumber: 1,
              trackNumber: 1,
              title: "Glow",
              songId: 100,
              url: "https://vocadb.net/S/100",
              producers: ["ryo"],
              vocalists: ["Hatsune Miku V6"]
            }
          ])
        );
      }
      if (method === "GET" && isVocaDbSongDetailsUrl(url, 100, 42)) {
        return Promise.resolve(
          createVocaDbSongDetailsResponse({
            discNumber: 1,
            trackNumber: 1,
            title: "Glow",
            songId: 100,
            url: "https://vocadb.net/S/100",
            producers: ["ryo"],
            vocalists: ["Hatsune Miku V6"]
          })
        );
      }
      if (method === "GET" && isVocaDbAlbumUrl(url, 99)) {
        return Promise.resolve(
          createVocaDbAlbumResponse({ id: 99, name: "Other Works", artistString: "kz" }, [])
        );
      }
      if (method === "GET" && isVocaDbTrackFieldsUrl(url, 99)) {
        return Promise.resolve(createVocaDbTrackFieldsResponse([]));
      }
      return Promise.reject(new Error(`Unexpected request: ${method} ${url}`));
    });
    const confirmSpy = vi.spyOn(window, "confirm").mockReturnValue(false);

    const user = userEvent.setup();
    render(<App />);

    await user.click(await screen.findByRole("button", { name: "Match VocaDB for Miku Works album 10" }));
    await user.click(await screen.findByRole("button", { name: /miku works.*ryo/i }));
    expect(await screen.findByRole("textbox", { name: "vocal suggestion" })).toHaveValue("Hatsune Miku");

    const beforeUnloadEvent = new Event("beforeunload", { cancelable: true });
    window.dispatchEvent(beforeUnloadEvent);
    expect(beforeUnloadEvent.defaultPrevented).toBe(true);

    await user.click(screen.getByRole("button", { name: /other works.*kz/i }));
    expect(confirmSpy).toHaveBeenCalledWith("Discard unsaved changes?");
    expect(screen.getByRole("textbox", { name: "vocal suggestion" })).toHaveValue("Hatsune Miku");
    expect(fetchMock.mock.calls.some(([input]) => isVocaDbAlbumUrl(String(input), 99))).toBe(false);

    const albumInput = screen.getByLabelText("VocaDB album URL or ID");
    await user.clear(albumInput);
    await user.type(albumInput, "99");
    await user.click(screen.getByRole("button", { name: "Load" }));
    expect(confirmSpy).toHaveBeenCalledTimes(2);
    expect(screen.getByRole("textbox", { name: "vocal suggestion" })).toHaveValue("Hatsune Miku");
    expect(fetchMock.mock.calls.some(([input]) => isVocaDbAlbumUrl(String(input), 99))).toBe(false);

    await user.click(screen.getByRole("button", { name: "Close" }));
    expect(confirmSpy).toHaveBeenCalledTimes(3);
    expect(screen.getByRole("button", { name: "Save VocaDB metadata" })).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Match VocaDB for Future Sound album 11" }));
    expect(confirmSpy).toHaveBeenCalledTimes(4);
    expect(screen.getByRole("heading", { name: "Miku Works", level: 2 })).toBeInTheDocument();
  });

  it("locks VocaDB workflow controls while batch save is in flight", async () => {
    const firstRow = createRow({
      composer: "",
      lyricist: "",
      vocal: "",
      source: ""
    });
    const secondRow = createRow({
      id: 2,
      title: "Spark",
      album_id: 11,
      album_title: "Future Sound",
      album_cover_path: "/covers/future-sound.jpg",
      composer: "",
      lyricist: "",
      vocal: "",
      source: ""
    });
    const savedRow = createRow({
      composer: "ryo",
      lyricist: "ryo",
      vocal: "Hatsune Miku",
      source: "https://vocadb.net/S/100"
    });
    let resolvePatch: ((response: Response) => void) | null = null;

    vi.spyOn(globalThis, "fetch").mockImplementation((input, init) => {
      const method = init?.method ?? "GET";
      const url = String(input);
      if (method === "GET" && url.endsWith("/api/tracks/metadata")) {
        return Promise.resolve(new Response(JSON.stringify({ tracks: [firstRow, secondRow] }), { status: 200 }));
      }
      if (method === "GET" && isVocaDbSearchUrl(url)) {
        return Promise.resolve(
          createVocaDbSearchResponse([{ id: 42, name: "Miku Works", artistString: "ryo" }])
        );
      }
      if (method === "GET" && isVocaDbAlbumUrl(url, 42)) {
        return Promise.resolve(
          createVocaDbAlbumResponse(
            { id: 42, name: "Miku Works", artistString: "ryo" },
            [
              {
                discNumber: 1,
                trackNumber: 1,
                title: "Glow",
                songId: 100,
                url: "https://vocadb.net/S/100",
                producers: ["ryo"],
                vocalists: ["Hatsune Miku V6"]
              }
            ]
          )
        );
      }
      if (method === "GET" && isVocaDbTrackFieldsUrl(url, 42)) {
        return Promise.resolve(
          createVocaDbTrackFieldsResponse([
            {
              discNumber: 1,
              trackNumber: 1,
              title: "Glow",
              songId: 100,
              url: "https://vocadb.net/S/100",
              producers: ["ryo"],
              vocalists: ["Hatsune Miku V6"]
            }
          ])
        );
      }
      if (method === "GET" && isVocaDbSongDetailsUrl(url, 100, 42)) {
        return Promise.resolve(
          createVocaDbSongDetailsResponse({
            discNumber: 1,
            trackNumber: 1,
            title: "Glow",
            songId: 100,
            url: "https://vocadb.net/S/100",
            producers: ["ryo"],
            vocalists: ["Hatsune Miku V6"]
          })
        );
      }
      if (method === "PATCH" && url.endsWith("/api/tracks/metadata")) {
        return new Promise<Response>((resolve) => {
          resolvePatch = resolve;
        });
      }
      return Promise.reject(new Error(`Unexpected request: ${method} ${url}`));
    });

    const user = userEvent.setup();
    render(<App />);

    await expandAlbum(user, "Future Sound");
    await user.click(await screen.findByRole("button", { name: "Match VocaDB for Miku Works album 10" }));
    const candidateButton = await screen.findByRole("button", { name: /miku works.*ryo/i });
    await user.click(candidateButton);
    expect(await screen.findByRole("textbox", { name: "vocal suggestion" })).toHaveValue("Hatsune Miku");
    await user.click(screen.getByRole("button", { name: "Save VocaDB metadata" }));

    await waitFor(() => expect(screen.getByRole("button", { name: "Close" })).toBeDisabled());
    expect(screen.getByLabelText("VocaDB album URL or ID")).toBeDisabled();
    expect(screen.getByRole("button", { name: "Load" })).toBeDisabled();
    expect(candidateButton).toBeDisabled();
    expect(screen.getByRole("button", { name: "Match VocaDB for Future Sound album 11" })).toBeDisabled();
    expect(screen.getByRole("button", { name: /01 spark/i })).toBeDisabled();

    const beforeUnloadEvent = new Event("beforeunload", { cancelable: true });
    window.dispatchEvent(beforeUnloadEvent);
    expect(beforeUnloadEvent.defaultPrevented).toBe(true);

    resolvePatch?.(new Response(JSON.stringify({ tracks: [savedRow] }), { status: 200 }));
    await waitFor(() => expect(screen.getByText("Saved VocaDB metadata.")).toBeInTheDocument());
  });
});
