import { act, renderHook, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import type { ApiClient } from "../../api/client";
import type { TrackMetadataRow } from "../../api/types";
import { createDraftFromRow } from "./model";
import { useTrackMetadataEditor } from "./useTrackMetadataEditor";

function createRow(overrides: Partial<TrackMetadataRow> = {}): TrackMetadataRow {
  return {
    id: 101,
    title: "Tell Your World",
    track_number: 9,
    disc_number: 2,
    album_id: 11,
    album_title: "Miku Collection",
    album_cover_path: "/covers/miku.jpg",
    producer_id: 77,
    producer_name: "livetune",
    composer: "kz",
    lyricist: "kz",
    arranger: "kz",
    remix: "",
    vocal: "Hatsune Miku",
    voice_manipulator: "kz",
    illustrator: "redjuice",
    movie: "wakamuraP",
    source: "YouTube",
    composer_source: "manual",
    lyricist_source: "scanned",
    ...overrides
  };
}

function createApiClientMock(rows: TrackMetadataRow[]) {
  const listTrackMetadata = vi.fn().mockResolvedValue(rows);
  const patchTrackMetadata = vi.fn().mockImplementation(async (trackId: number) => {
    const row = rows.find((item) => item.id === trackId);
    if (row == null) {
      throw new Error("missing row");
    }
    return row;
  });
  const apiClient: ApiClient = {
    listTrackMetadata,
    patchTrackMetadata,
    patchTrackMetadataBatch: vi.fn(),
    searchVocaDbAlbums: vi.fn(),
    getVocaDbAlbum: vi.fn(),
    albumCoverUrl: (albumId: number) => `/api/albums/${albumId}/cover`
  };

  return { apiClient, listTrackMetadata, patchTrackMetadata };
}

describe("useTrackMetadataEditor", () => {
  it("loads rows and keeps no selection by default", async () => {
    const row = createRow();
    const { apiClient, listTrackMetadata } = createApiClientMock([row]);

    const { result } = renderHook(() => useTrackMetadataEditor(apiClient));

    expect(result.current.selectedTrackId).toBeNull();
    expect(result.current.selectedRow).toBeNull();
    expect(result.current.draft).toBeNull();
    expect(result.current.isDirty).toBe(false);
    expect(result.current.isLoading).toBe(true);

    await waitFor(() => expect(result.current.isLoading).toBe(false));

    expect(listTrackMetadata).toHaveBeenCalledTimes(1);
    expect(result.current.allRows).toEqual([row]);
    expect(result.current.rows).toEqual([row]);
    expect(result.current.selectedTrackId).toBeNull();
  });

  it("creates a draft on track select and marks dirty after edits", async () => {
    const row = createRow();
    const { apiClient } = createApiClientMock([row]);

    const { result } = renderHook(() => useTrackMetadataEditor(apiClient));
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    act(() => {
      expect(result.current.selectTrack(row.id)).toBe(true);
    });

    expect(result.current.selectedTrackId).toBe(row.id);
    expect(result.current.selectedRow).toEqual(row);
    expect(result.current.draft).toEqual(createDraftFromRow(row));
    expect(result.current.isDirty).toBe(false);

    act(() => {
      result.current.updateDraft("composer", "ryo");
    });

    expect(result.current.draft?.composer).toBe("ryo");
    expect(result.current.isDirty).toBe(true);
  });

  it("saves only changed fields and replaces the stored row with the response", async () => {
    const originalRow = createRow();
    const savedRow = createRow({ composer: "ryo", source: "Niconico" });
    const { apiClient, patchTrackMetadata } = createApiClientMock([originalRow]);
    patchTrackMetadata.mockResolvedValue(savedRow);

    const { result } = renderHook(() => useTrackMetadataEditor(apiClient));
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    act(() => {
      expect(result.current.selectTrack(originalRow.id)).toBe(true);
      result.current.updateDraft("composer", "ryo");
    });

    await act(async () => {
      await result.current.save();
    });

    expect(patchTrackMetadata).toHaveBeenCalledTimes(1);
    expect(patchTrackMetadata).toHaveBeenCalledWith(originalRow.id, { composer: "ryo" });
    expect(result.current.rows).toEqual([savedRow]);
    expect(result.current.selectedRow).toEqual(savedRow);
    expect(result.current.draft).toEqual(createDraftFromRow(savedRow));
    expect(result.current.isDirty).toBe(false);
    expect(result.current.successMessage).toBe("Saved.");
  });

  it("replaces rows in memory and refreshes the selected draft", async () => {
    const selectedRow = createRow();
    const otherRow = createRow({ id: 102, title: "Packaged", track_number: 10 });
    const savedSelectedRow = createRow({ composer: "ryo", lyricist: "ryo" });
    const savedOtherRow = createRow({ id: 102, title: "Packaged", track_number: 10, composer: "kz" });
    const { apiClient } = createApiClientMock([selectedRow, otherRow]);

    const { result } = renderHook(() => useTrackMetadataEditor(apiClient));
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    act(() => {
      expect(result.current.selectTrack(selectedRow.id)).toBe(true);
      result.current.updateDraft("composer", "draft change");
    });
    expect(result.current.isDirty).toBe(true);

    act(() => {
      result.current.replaceRows([savedSelectedRow, savedOtherRow]);
    });

    expect(result.current.allRows).toEqual([savedSelectedRow, savedOtherRow]);
    expect(result.current.rows).toEqual([savedSelectedRow, savedOtherRow]);
    expect(result.current.selectedRow).toEqual(savedSelectedRow);
    expect(result.current.draft).toEqual(createDraftFromRow(savedSelectedRow));
    expect(result.current.isDirty).toBe(false);
  });

  it("reload refreshes selected draft from latest server row and keeps clean state", async () => {
    const originalRow = createRow();
    const refreshedRow = createRow({ composer: "livetune", lyricist: "kz-livetune", source: "Niconico" });
    const { apiClient, listTrackMetadata } = createApiClientMock([originalRow]);
    listTrackMetadata.mockResolvedValueOnce([originalRow]).mockResolvedValueOnce([refreshedRow]);

    const { result } = renderHook(() => useTrackMetadataEditor(apiClient));
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    act(() => {
      expect(result.current.selectTrack(originalRow.id)).toBe(true);
    });

    await act(async () => {
      await result.current.reload();
    });

    expect(result.current.selectedTrackId).toBe(originalRow.id);
    expect(result.current.selectedRow).toEqual(refreshedRow);
    expect(result.current.draft).toEqual(createDraftFromRow(refreshedRow));
    expect(result.current.isDirty).toBe(false);
  });

  it("reload clears selection and draft when selected track disappears", async () => {
    const originalRow = createRow();
    const { apiClient, listTrackMetadata } = createApiClientMock([originalRow]);
    listTrackMetadata.mockResolvedValueOnce([originalRow]).mockResolvedValueOnce([]);

    const { result } = renderHook(() => useTrackMetadataEditor(apiClient));
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    act(() => {
      expect(result.current.selectTrack(originalRow.id)).toBe(true);
    });

    await act(async () => {
      await result.current.reload();
    });

    expect(result.current.selectedTrackId).toBeNull();
    expect(result.current.selectedRow).toBeNull();
    expect(result.current.draft).toBeNull();
    expect(result.current.isDirty).toBe(false);
  });
});
