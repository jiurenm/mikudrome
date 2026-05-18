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
  const albumButton = await screen.findByRole("button", { name: new RegExp(albumTitle, "i") });
  if (albumButton.getAttribute("aria-expanded") === "false") {
    await user.click(albumButton);
  }
  return albumButton;
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

    await screen.findByRole("button", { name: /miku works/i });
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

    const albumButton = await screen.findByRole("button", { name: /miku works/i });
    expect(albumButton).toHaveAttribute("aria-expanded", "false");
    expect(screen.queryByRole("button", { name: /01 glow/i })).not.toBeInTheDocument();

    await user.click(albumButton);

    expect(albumButton).toHaveAttribute("aria-expanded", "true");
    expect(screen.getByRole("button", { name: /01 glow/i })).toBeInTheDocument();
  });

  it("loads a track into the editor and saves changes", async () => {
    const row = createRow();
    const savedRow = createRow({ movie: "Mah" });
    vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
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
});
