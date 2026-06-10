import { act, renderHook } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import type { ApiClient } from "../../api/client";
import type { TrackMetadataRow, VocaDbAlbumDetail } from "../../api/types";
import { useVocaDbAlbumMatcher } from "./useVocaDbAlbumMatcher";

const row: TrackMetadataRow = {
  id: 1,
  title: "World",
  track_number: 1,
  disc_number: 1,
  album_id: 10,
  album_title: "Album",
  album_cover_path: "",
  producer_id: 1,
  producer_name: "ryo",
  composer: "",
  lyricist: "",
  arranger: "",
  remix: "",
  vocal: "",
  voice_manipulator: "",
  illustrator: "",
  movie: "",
  source: "",
  composer_source: "empty",
  lyricist_source: "empty"
};

const vocaAlbum: VocaDbAlbumDetail = {
  id: 42,
  name: "Album",
  artistString: "ryo",
  url: "https://vocadb.net/Al/42",
  tracks: [
    {
      discNumber: 1,
      trackNumber: 1,
      title: "World",
      songId: 100,
      url: "https://vocadb.net/S/100",
      producers: ["ryo"],
      vocalists: ["Hatsune Miku V6"],
      artists: []
    }
  ]
};

const otherRow: TrackMetadataRow = {
  ...row,
  id: 2,
  title: "Future",
  album_id: 11,
  album_title: "Other Album"
};

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return { promise, resolve, reject };
}

function createClient(): ApiClient {
  return {
    listTrackMetadata: vi.fn(),
    patchTrackMetadata: vi.fn(),
    patchTrackMetadataBatch: vi.fn().mockResolvedValue([{ ...row, composer: "ryo", lyricist: "ryo" }]),
    albumCoverUrl: (albumId) => `/api/albums/${albumId}/cover`,
    searchVocaDbAlbums: vi.fn().mockResolvedValue([
      { id: 42, name: "Album", artistString: "ryo", url: "https://vocadb.net/Al/42", releaseDate: "" }
    ]),
    getVocaDbAlbum: vi.fn().mockResolvedValue(vocaAlbum)
  };
}

describe("useVocaDbAlbumMatcher", () => {
  it("starts a match by searching with the local album title", async () => {
    const client = createClient();
    const { result } = renderHook(() => useVocaDbAlbumMatcher(client, [row], vi.fn()));

    await act(async () => {
      await result.current.start(row.album_id);
    });

    expect(client.searchVocaDbAlbums).toHaveBeenCalledWith("Album");
    expect(result.current.activeAlbumId).toBe(row.album_id);
    expect(result.current.candidates).toHaveLength(1);
  });

  it("loads an album candidate and builds selected suggestions", async () => {
    const client = createClient();
    const { result } = renderHook(() => useVocaDbAlbumMatcher(client, [row], vi.fn()));

    await act(async () => {
      await result.current.start(row.album_id);
      await result.current.loadAlbum(42);
    });

    expect(client.getVocaDbAlbum).toHaveBeenCalledWith(42);
    expect(result.current.selectedAlbum?.id).toBe(42);
    expect(result.current.suggestions).toContainEqual(
      expect.objectContaining({ field: "composer", selected: true })
    );
  });

  it("toggles suggestions and saves selected batch updates", async () => {
    const onRowsSaved = vi.fn();
    const client = createClient();
    const { result } = renderHook(() => useVocaDbAlbumMatcher(client, [row], onRowsSaved));

    await act(async () => {
      await result.current.start(row.album_id);
      await result.current.loadAlbum(42);
    });
    const sourceSuggestion = result.current.suggestions.find((item) => item.field === "source");
    expect(sourceSuggestion).toBeDefined();

    act(() => {
      result.current.toggleSuggestion(sourceSuggestion!.id);
    });
    await act(async () => {
      await result.current.save();
    });

    expect(client.patchTrackMetadataBatch).toHaveBeenCalledWith({
      updates: [
        {
          track_id: 1,
          patch: expect.objectContaining({
            composer: "ryo",
            lyricist: "ryo",
            vocal: "Hatsune Miku"
          })
        }
      ]
    });
    expect(onRowsSaved).toHaveBeenCalledWith([{ ...row, composer: "ryo", lyricist: "ryo" }]);
    expect(result.current.successMessage).toBe("Saved VocaDB metadata.");
    expect(result.current.suggestions).toEqual([]);

    await act(async () => {
      await result.current.save();
    });

    expect(client.patchTrackMetadataBatch).toHaveBeenCalledTimes(1);
    expect(result.current.saveError).toBeNull();
    expect(result.current.successMessage).toBe("Saved VocaDB metadata.");
  });

  it("keeps preview state when save fails", async () => {
    const client = createClient();
    vi.mocked(client.patchTrackMetadataBatch).mockRejectedValue(new Error("save failed"));
    const { result } = renderHook(() => useVocaDbAlbumMatcher(client, [row], vi.fn()));

    await act(async () => {
      await result.current.start(row.album_id);
      await result.current.loadAlbum(42);
      await result.current.save();
    });

    expect(result.current.saveError).toBe("Failed to save VocaDB metadata.");
    expect(result.current.suggestions.length).toBeGreaterThan(0);
  });

  it("ignores stale search results after a newer album workflow starts", async () => {
    const firstSearch = deferred<Awaited<ReturnType<ApiClient["searchVocaDbAlbums"]>>>();
    const secondSearch = deferred<Awaited<ReturnType<ApiClient["searchVocaDbAlbums"]>>>();
    const client = createClient();
    vi.mocked(client.searchVocaDbAlbums)
      .mockReturnValueOnce(firstSearch.promise)
      .mockReturnValueOnce(secondSearch.promise);
    const { result } = renderHook(() =>
      useVocaDbAlbumMatcher(client, [row, otherRow], vi.fn())
    );

    await act(async () => {
      void result.current.start(row.album_id);
    });
    await act(async () => {
      void result.current.start(otherRow.album_id);
    });

    await act(async () => {
      secondSearch.resolve([
        { id: 99, name: "Other Album", artistString: "ryo", url: "https://vocadb.net/Al/99", releaseDate: "" }
      ]);
      await secondSearch.promise;
    });
    expect(result.current.activeAlbumId).toBe(otherRow.album_id);
    expect(result.current.candidates).toEqual([
      { id: 99, name: "Other Album", artistString: "ryo", url: "https://vocadb.net/Al/99", releaseDate: "" }
    ]);

    await act(async () => {
      firstSearch.resolve([
        { id: 42, name: "Album", artistString: "ryo", url: "https://vocadb.net/Al/42", releaseDate: "" }
      ]);
      await firstSearch.promise;
    });

    expect(result.current.activeAlbumId).toBe(otherRow.album_id);
    expect(result.current.candidates).toEqual([
      { id: 99, name: "Other Album", artistString: "ryo", url: "https://vocadb.net/Al/99", releaseDate: "" }
    ]);
  });

  it("ignores pending loaded album details after cancel", async () => {
    const albumLoad = deferred<VocaDbAlbumDetail>();
    const client = createClient();
    vi.mocked(client.getVocaDbAlbum).mockReturnValue(albumLoad.promise);
    const { result } = renderHook(() => useVocaDbAlbumMatcher(client, [row], vi.fn()));

    await act(async () => {
      await result.current.start(row.album_id);
    });
    await act(async () => {
      void result.current.loadAlbum(42);
    });
    act(() => {
      result.current.cancel();
    });

    await act(async () => {
      albumLoad.resolve(vocaAlbum);
      await albumLoad.promise;
    });

    expect(result.current.activeAlbumId).toBeNull();
    expect(result.current.selectedAlbum).toBeNull();
    expect(result.current.suggestions).toEqual([]);
    expect(result.current.isLoadingAlbum).toBe(false);
  });

  it("keeps a loaded preview when the initial search resolves afterward", async () => {
    const searchResult = deferred<Awaited<ReturnType<ApiClient["searchVocaDbAlbums"]>>>();
    const albumLoad = deferred<VocaDbAlbumDetail>();
    const client = createClient();
    vi.mocked(client.searchVocaDbAlbums).mockReturnValue(searchResult.promise);
    vi.mocked(client.getVocaDbAlbum).mockReturnValue(albumLoad.promise);
    const { result } = renderHook(() => useVocaDbAlbumMatcher(client, [row], vi.fn()));

    await act(async () => {
      void result.current.start(row.album_id);
      void result.current.loadAlbum(42);
    });

    await act(async () => {
      albumLoad.resolve(vocaAlbum);
      await albumLoad.promise;
    });
    expect(result.current.selectedAlbum?.id).toBe(42);
    expect(result.current.suggestions.length).toBeGreaterThan(0);

    await act(async () => {
      searchResult.resolve([
        { id: 42, name: "Album", artistString: "ryo", url: "https://vocadb.net/Al/42", releaseDate: "" }
      ]);
      await searchResult.promise;
    });

    expect(result.current.selectedAlbum?.id).toBe(42);
    expect(result.current.suggestions.length).toBeGreaterThan(0);
  });

  it("ignores older pending album loads after an explicit search starts", async () => {
    const albumLoad = deferred<VocaDbAlbumDetail>();
    const client = createClient();
    vi.mocked(client.searchVocaDbAlbums)
      .mockResolvedValueOnce([
        { id: 42, name: "Album", artistString: "ryo", url: "https://vocadb.net/Al/42", releaseDate: "" }
      ])
      .mockResolvedValueOnce([
        { id: 99, name: "Other Album", artistString: "ryo", url: "https://vocadb.net/Al/99", releaseDate: "" }
      ]);
    vi.mocked(client.getVocaDbAlbum).mockReturnValue(albumLoad.promise);
    const { result } = renderHook(() => useVocaDbAlbumMatcher(client, [row], vi.fn()));

    await act(async () => {
      await result.current.start(row.album_id);
    });
    await act(async () => {
      void result.current.loadAlbum(42);
    });
    await act(async () => {
      await result.current.search("Other Album");
    });

    expect(result.current.candidates).toEqual([
      { id: 99, name: "Other Album", artistString: "ryo", url: "https://vocadb.net/Al/99", releaseDate: "" }
    ]);

    await act(async () => {
      albumLoad.resolve(vocaAlbum);
      await albumLoad.promise;
    });

    expect(result.current.selectedAlbum).toBeNull();
    expect(result.current.suggestions).toEqual([]);
    expect(result.current.candidates).toEqual([
      { id: 99, name: "Other Album", artistString: "ryo", url: "https://vocadb.net/Al/99", releaseDate: "" }
    ]);
  });

  it("clears loaded suggestions when an explicit search fails and blocks stale saves", async () => {
    const client = createClient();
    vi.mocked(client.searchVocaDbAlbums)
      .mockResolvedValueOnce([
        { id: 42, name: "Album", artistString: "ryo", url: "https://vocadb.net/Al/42", releaseDate: "" }
      ])
      .mockRejectedValueOnce(new Error("search failed"));
    const { result } = renderHook(() => useVocaDbAlbumMatcher(client, [row], vi.fn()));

    await act(async () => {
      await result.current.start(row.album_id);
      await result.current.loadAlbum(42);
    });
    expect(result.current.suggestions.length).toBeGreaterThan(0);
    vi.mocked(client.patchTrackMetadataBatch).mockClear();

    await act(async () => {
      await result.current.search("Other Album");
    });
    await act(async () => {
      await result.current.save();
    });

    expect(result.current.lookupError).toBe("Failed to search VocaDB albums.");
    expect(result.current.selectedAlbum).toBeNull();
    expect(result.current.suggestions).toEqual([]);
    expect(client.patchTrackMetadataBatch).not.toHaveBeenCalled();
    expect(result.current.saveError).toBe("Select at least one VocaDB metadata field.");
  });

  it("clears loaded suggestions when loading a new album fails and blocks stale saves", async () => {
    const client = createClient();
    vi.mocked(client.getVocaDbAlbum)
      .mockResolvedValueOnce(vocaAlbum)
      .mockRejectedValueOnce(new Error("load failed"));
    const { result } = renderHook(() => useVocaDbAlbumMatcher(client, [row], vi.fn()));

    await act(async () => {
      await result.current.start(row.album_id);
      await result.current.loadAlbum(42);
    });
    expect(result.current.suggestions.length).toBeGreaterThan(0);
    vi.mocked(client.patchTrackMetadataBatch).mockClear();

    await act(async () => {
      await result.current.loadAlbum(99);
    });
    await act(async () => {
      await result.current.save();
    });

    expect(result.current.lookupError).toBe("Failed to load VocaDB album.");
    expect(result.current.selectedAlbum).toBeNull();
    expect(result.current.suggestions).toEqual([]);
    expect(client.patchTrackMetadataBatch).not.toHaveBeenCalled();
    expect(result.current.saveError).toBe("Select at least one VocaDB metadata field.");
  });

  it("does not save stale suggestions while a new explicit search is pending", async () => {
    const searchResult = deferred<Awaited<ReturnType<ApiClient["searchVocaDbAlbums"]>>>();
    const client = createClient();
    vi.mocked(client.searchVocaDbAlbums)
      .mockResolvedValueOnce([
        { id: 42, name: "Album", artistString: "ryo", url: "https://vocadb.net/Al/42", releaseDate: "" }
      ])
      .mockReturnValueOnce(searchResult.promise);
    const { result } = renderHook(() => useVocaDbAlbumMatcher(client, [row], vi.fn()));

    await act(async () => {
      await result.current.start(row.album_id);
      await result.current.loadAlbum(42);
    });
    expect(result.current.suggestions.length).toBeGreaterThan(0);
    vi.mocked(client.patchTrackMetadataBatch).mockClear();

    await act(async () => {
      void result.current.search("Other Album");
    });
    await act(async () => {
      await result.current.save();
    });

    expect(result.current.selectedAlbum).toBeNull();
    expect(result.current.suggestions).toEqual([]);
    expect(client.patchTrackMetadataBatch).not.toHaveBeenCalled();
    expect(result.current.saveError).toBe("Select at least one VocaDB metadata field.");

    await act(async () => {
      searchResult.resolve([
        { id: 99, name: "Other Album", artistString: "ryo", url: "https://vocadb.net/Al/99", releaseDate: "" }
      ]);
      await searchResult.promise;
    });
  });

  it("does not save stale suggestions while a new album load is pending", async () => {
    const albumLoad = deferred<VocaDbAlbumDetail>();
    const client = createClient();
    vi.mocked(client.getVocaDbAlbum)
      .mockResolvedValueOnce(vocaAlbum)
      .mockReturnValueOnce(albumLoad.promise);
    const { result } = renderHook(() => useVocaDbAlbumMatcher(client, [row], vi.fn()));

    await act(async () => {
      await result.current.start(row.album_id);
      await result.current.loadAlbum(42);
    });
    expect(result.current.suggestions.length).toBeGreaterThan(0);
    vi.mocked(client.patchTrackMetadataBatch).mockClear();

    await act(async () => {
      void result.current.loadAlbum(99);
    });
    await act(async () => {
      await result.current.save();
    });

    expect(result.current.selectedAlbum).toBeNull();
    expect(result.current.suggestions).toEqual([]);
    expect(client.patchTrackMetadataBatch).not.toHaveBeenCalled();
    expect(result.current.saveError).toBe("Select at least one VocaDB metadata field.");

    await act(async () => {
      albumLoad.resolve(vocaAlbum);
      await albumLoad.promise;
    });
  });

  it("clears loaded suggestions for invalid manual album input and blocks stale saves", async () => {
    const client = createClient();
    const { result } = renderHook(() => useVocaDbAlbumMatcher(client, [row], vi.fn()));

    await act(async () => {
      await result.current.start(row.album_id);
      await result.current.loadAlbum(42);
    });
    expect(result.current.selectedAlbum?.id).toBe(42);
    expect(result.current.suggestions.length).toBeGreaterThan(0);
    vi.mocked(client.patchTrackMetadataBatch).mockClear();

    act(() => {
      result.current.setAlbumIdInput("not an album");
    });
    await act(async () => {
      await result.current.loadAlbumFromInput();
    });
    await act(async () => {
      await result.current.save();
    });

    expect(result.current.lookupError).toBe("Enter a valid VocaDB album URL or ID.");
    expect(result.current.selectedAlbum).toBeNull();
    expect(result.current.suggestions).toEqual([]);
    expect(client.patchTrackMetadataBatch).not.toHaveBeenCalled();
    expect(result.current.saveError).toBe("Select at least one VocaDB metadata field.");
  });

  it("invalid manual album input invalidates pending album loads", async () => {
    const albumLoad = deferred<VocaDbAlbumDetail>();
    const client = createClient();
    vi.mocked(client.getVocaDbAlbum).mockReturnValue(albumLoad.promise);
    const { result } = renderHook(() => useVocaDbAlbumMatcher(client, [row], vi.fn()));

    await act(async () => {
      await result.current.start(row.album_id);
    });
    await act(async () => {
      void result.current.loadAlbum(42);
    });
    expect(result.current.isLoadingAlbum).toBe(true);

    act(() => {
      result.current.setAlbumIdInput("not an album");
    });
    await act(async () => {
      await result.current.loadAlbumFromInput();
    });
    expect(result.current.isLoadingAlbum).toBe(false);

    await act(async () => {
      albumLoad.resolve(vocaAlbum);
      await albumLoad.promise;
    });
    await act(async () => {
      await result.current.save();
    });

    expect(result.current.lookupError).toBe("Enter a valid VocaDB album URL or ID.");
    expect(result.current.selectedAlbum).toBeNull();
    expect(result.current.suggestions).toEqual([]);
    expect(client.patchTrackMetadataBatch).not.toHaveBeenCalled();
    expect(result.current.saveError).toBe("Select at least one VocaDB metadata field.");
    expect(result.current.isLoadingAlbum).toBe(false);
  });

  it("suppresses stale save feedback and row callbacks after cancel", async () => {
    const savedRows = [{ ...row, composer: "ryo", lyricist: "ryo" }];
    const saveResult = deferred<TrackMetadataRow[]>();
    const onRowsSaved = vi.fn();
    const client = createClient();
    vi.mocked(client.patchTrackMetadataBatch).mockReturnValue(saveResult.promise);
    const { result } = renderHook(() => useVocaDbAlbumMatcher(client, [row], onRowsSaved));

    await act(async () => {
      await result.current.start(row.album_id);
      await result.current.loadAlbum(42);
    });
    await act(async () => {
      void result.current.save();
    });
    act(() => {
      result.current.cancel();
    });

    await act(async () => {
      saveResult.resolve(savedRows);
      await saveResult.promise;
    });

    expect(onRowsSaved).not.toHaveBeenCalled();
    expect(result.current.activeAlbumId).toBeNull();
    expect(result.current.isSaving).toBe(false);
    expect(result.current.saveError).toBeNull();
    expect(result.current.successMessage).toBeNull();
  });

  it("clears stale save messages before reporting invalid manual album input", async () => {
    const client = createClient();
    const { result } = renderHook(() => useVocaDbAlbumMatcher(client, [row], vi.fn()));

    await act(async () => {
      await result.current.save();
    });
    expect(result.current.saveError).toBe("Select at least one VocaDB metadata field.");

    act(() => {
      result.current.setAlbumIdInput("not an album");
    });
    await act(async () => {
      await result.current.loadAlbumFromInput();
    });

    expect(result.current.lookupError).toBe("Enter a valid VocaDB album URL or ID.");
    expect(result.current.saveError).toBeNull();

    await act(async () => {
      await result.current.start(row.album_id);
      await result.current.loadAlbum(42);
      await result.current.save();
    });
    expect(result.current.successMessage).toBe("Saved VocaDB metadata.");

    act(() => {
      result.current.setAlbumIdInput("not an album");
    });
    await act(async () => {
      await result.current.loadAlbumFromInput();
    });

    expect(result.current.lookupError).toBe("Enter a valid VocaDB album URL or ID.");
    expect(result.current.successMessage).toBeNull();
  });
});
