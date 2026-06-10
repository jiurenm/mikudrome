import { useCallback, useEffect, useMemo, useState } from "react";
import type { ApiClient } from "../../api/client";
import type { TrackMetadataRow } from "../../api/types";
import {
  buildAlbumGroups,
  buildPatchPayload,
  createDraftFromRow,
  hasDraftChanges,
  matchesSearch,
  type AlbumGroup,
  type TrackMetadataDraft
} from "./model";

interface TrackMetadataEditorState {
  allRows: TrackMetadataRow[];
  rows: TrackMetadataRow[];
  albumGroups: AlbumGroup[];
  search: string;
  setSearch: (value: string) => void;
  selectedTrackId: number | null;
  selectedRow: TrackMetadataRow | null;
  draft: TrackMetadataDraft | null;
  isDirty: boolean;
  isSaving: boolean;
  isLoading: boolean;
  loadError: string | null;
  saveError: string | null;
  successMessage: string | null;
  reload: () => Promise<void>;
  replaceRows: (rows: TrackMetadataRow[]) => void;
  selectTrack: (trackId: number, force?: boolean) => boolean;
  updateDraft: (field: keyof TrackMetadataDraft, value: string) => void;
  save: () => Promise<void>;
  resetDraft: () => void;
}

export function useTrackMetadataEditor(apiClient: ApiClient): TrackMetadataEditorState {
  const [allRows, setAllRows] = useState<TrackMetadataRow[]>([]);
  const [search, setSearch] = useState("");
  const [selectedTrackId, setSelectedTrackId] = useState<number | null>(null);
  const [draft, setDraft] = useState<TrackMetadataDraft | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  const rows = useMemo(() => allRows.filter((row) => matchesSearch(row, search)), [allRows, search]);
  const albumGroups = useMemo(() => buildAlbumGroups(rows), [rows]);
  const selectedRow = useMemo(() => {
    if (selectedTrackId == null) {
      return null;
    }
    return allRows.find((row) => row.id === selectedTrackId) ?? null;
  }, [allRows, selectedTrackId]);
  const isDirty = useMemo(() => {
    if (selectedRow == null || draft == null) {
      return false;
    }
    return hasDraftChanges(selectedRow, draft);
  }, [selectedRow, draft]);

  const loadRows = useCallback(async () => {
    setIsLoading(true);
    setLoadError(null);
    try {
      const loadedRows = await apiClient.listTrackMetadata();
      setAllRows(loadedRows);
      setSelectedTrackId((currentSelectedTrackId) => {
        if (currentSelectedTrackId == null) {
          return currentSelectedTrackId;
        }

        const refreshedSelectedRow = loadedRows.find((row) => row.id === currentSelectedTrackId);
        if (refreshedSelectedRow == null) {
          setDraft(null);
          return null;
        }

        setDraft(createDraftFromRow(refreshedSelectedRow));
        return currentSelectedTrackId;
      });
    } catch {
      setLoadError("Failed to load track metadata.");
    } finally {
      setIsLoading(false);
    }
  }, [apiClient]);

  useEffect(() => {
    void loadRows();
  }, [loadRows]);

  const reload = useCallback(async () => {
    await loadRows();
  }, [loadRows]);

  const replaceRows = useCallback((rowsToReplace: TrackMetadataRow[]) => {
    const replacementById = new Map(rowsToReplace.map((row) => [row.id, row]));
    setAllRows((currentRows) =>
      currentRows.map((row) => replacementById.get(row.id) ?? row)
    );
    setDraft((currentDraft) => {
      if (currentDraft == null || selectedTrackId == null) {
        return currentDraft;
      }

      const replacement = replacementById.get(selectedTrackId);
      return replacement == null ? currentDraft : createDraftFromRow(replacement);
    });
    setSaveError(null);
  }, [selectedTrackId]);

  const selectTrack = useCallback(
    (trackId: number, force = false) => {
      if (!force && isDirty) {
        return false;
      }

      const row = allRows.find((item) => item.id === trackId);
      if (row == null) {
        return false;
      }

      setSelectedTrackId(trackId);
      setDraft(createDraftFromRow(row));
      setSaveError(null);
      setSuccessMessage(null);
      return true;
    },
    [allRows, isDirty]
  );

  const updateDraft = useCallback((field: keyof TrackMetadataDraft, value: string) => {
    setDraft((currentDraft) => {
      if (currentDraft == null) {
        return currentDraft;
      }
      return {
        ...currentDraft,
        [field]: value
      };
    });
  }, []);

  const save = useCallback(async () => {
    if (selectedRow == null || draft == null || !hasDraftChanges(selectedRow, draft)) {
      return;
    }

    const patch = buildPatchPayload(selectedRow, draft);
    setIsSaving(true);
    setSaveError(null);
    setSuccessMessage(null);
    try {
      const savedRow = await apiClient.patchTrackMetadata(selectedRow.id, patch);
      setAllRows((currentRows) =>
        currentRows.map((row) => {
          if (row.id === savedRow.id) {
            return savedRow;
          }
          return row;
        })
      );
      setDraft(createDraftFromRow(savedRow));
      setSaveError(null);
      setSuccessMessage("Saved.");
    } catch {
      setSaveError("Failed to save track metadata.");
      setSuccessMessage(null);
    } finally {
      setIsSaving(false);
    }
  }, [apiClient, selectedRow, draft]);

  const resetDraft = useCallback(() => {
    if (selectedRow == null) {
      return;
    }

    setDraft(createDraftFromRow(selectedRow));
    setSaveError(null);
    setSuccessMessage(null);
  }, [selectedRow]);

  return {
    allRows,
    rows,
    albumGroups,
    search,
    setSearch,
    selectedTrackId,
    selectedRow,
    draft,
    isDirty,
    isSaving,
    isLoading,
    loadError,
    saveError,
    successMessage,
    reload,
    replaceRows,
    selectTrack,
    updateDraft,
    save,
    resetDraft
  };
}
