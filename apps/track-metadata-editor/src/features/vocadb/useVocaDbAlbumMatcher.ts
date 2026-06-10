import { useCallback, useMemo, useRef, useState } from "react";
import type { ApiClient } from "../../api/client";
import type { TrackMetadataRow, VocaDbAlbumCandidate, VocaDbAlbumDetail } from "../../api/types";
import {
  buildBatchPatchFromSelections,
  buildVocaDbSuggestions,
  parseVocaDbAlbumId,
  type VocaDbFieldSuggestion
} from "./model";

export interface VocaDbAlbumMatcherState {
  activeAlbumId: number | null;
  activeRows: TrackMetadataRow[];
  candidates: VocaDbAlbumCandidate[];
  selectedAlbum: VocaDbAlbumDetail | null;
  suggestions: VocaDbFieldSuggestion[];
  albumIdInput: string;
  setAlbumIdInput: (value: string) => void;
  isSearching: boolean;
  isLoadingAlbum: boolean;
  isSaving: boolean;
  lookupError: string | null;
  saveError: string | null;
  successMessage: string | null;
  start: (albumId: number) => Promise<void>;
  cancel: () => void;
  search: (query: string) => Promise<void>;
  loadAlbum: (albumId: number) => Promise<void>;
  loadAlbumFromInput: () => Promise<void>;
  toggleSuggestion: (id: string) => void;
  save: () => Promise<void>;
}

export function useVocaDbAlbumMatcher(
  apiClient: ApiClient,
  rows: TrackMetadataRow[],
  onRowsSaved: (rows: TrackMetadataRow[]) => void
): VocaDbAlbumMatcherState {
  const [activeAlbumId, setActiveAlbumId] = useState<number | null>(null);
  const activeAlbumIdRef = useRef<number | null>(null);
  const workflowTokenRef = useRef(0);
  const searchRequestIdRef = useRef(0);
  const loadAlbumRequestIdRef = useRef(0);
  const saveRequestIdRef = useRef(0);
  const suggestionsRef = useRef<VocaDbFieldSuggestion[]>([]);
  const [candidates, setCandidates] = useState<VocaDbAlbumCandidate[]>([]);
  const [selectedAlbum, setSelectedAlbum] = useState<VocaDbAlbumDetail | null>(null);
  const [suggestions, setSuggestions] = useState<VocaDbFieldSuggestion[]>([]);
  const [albumIdInput, setAlbumIdInput] = useState("");
  const [isSearching, setIsSearching] = useState(false);
  const [isLoadingAlbum, setIsLoadingAlbum] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [lookupError, setLookupError] = useState<string | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  const activeRows = useMemo(
    () => (activeAlbumId == null ? [] : rows.filter((row) => row.album_id === activeAlbumId)),
    [activeAlbumId, rows]
  );

  const runSearch = useCallback(
    async (query: string, workflowToken: number) => {
      const requestId = ++searchRequestIdRef.current;
      const loadRequestId = ++loadAlbumRequestIdRef.current;
      setSelectedAlbum(null);
      suggestionsRef.current = [];
      setSuggestions([]);
      setIsSearching(true);
      setLookupError(null);
      setSaveError(null);
      setSuccessMessage(null);
      try {
        const nextCandidates = await apiClient.searchVocaDbAlbums(query);
        if (workflowTokenRef.current !== workflowToken || searchRequestIdRef.current !== requestId) {
          return;
        }
        setCandidates(nextCandidates);
        if (loadAlbumRequestIdRef.current === loadRequestId) {
          setSelectedAlbum(null);
          suggestionsRef.current = [];
          setSuggestions([]);
        }
      } catch {
        if (workflowTokenRef.current !== workflowToken || searchRequestIdRef.current !== requestId) {
          return;
        }
        setLookupError("Failed to search VocaDB albums.");
        setCandidates([]);
      } finally {
        if (workflowTokenRef.current === workflowToken && searchRequestIdRef.current === requestId) {
          setIsSearching(false);
        }
      }
    },
    [apiClient]
  );

  const search = useCallback(
    async (query: string) => {
      await runSearch(query, workflowTokenRef.current);
    },
    [runSearch]
  );

  const start = useCallback(
    async (albumId: number) => {
      const albumRows = rows.filter((row) => row.album_id === albumId);
      const workflowToken = workflowTokenRef.current + 1;
      workflowTokenRef.current = workflowToken;
      saveRequestIdRef.current += 1;
      activeAlbumIdRef.current = albumId;
      setActiveAlbumId(albumId);
      setSelectedAlbum(null);
      suggestionsRef.current = [];
      setSuggestions([]);
      setAlbumIdInput("");
      await runSearch(albumRows[0]?.album_title ?? "", workflowToken);
    },
    [rows, runSearch]
  );

  const cancel = useCallback(() => {
    workflowTokenRef.current += 1;
    searchRequestIdRef.current += 1;
    loadAlbumRequestIdRef.current += 1;
    saveRequestIdRef.current += 1;
    activeAlbumIdRef.current = null;
    setActiveAlbumId(null);
    setCandidates([]);
    setSelectedAlbum(null);
    suggestionsRef.current = [];
    setSuggestions([]);
    setAlbumIdInput("");
    setIsSearching(false);
    setIsLoadingAlbum(false);
    setIsSaving(false);
    setLookupError(null);
    setSaveError(null);
    setSuccessMessage(null);
  }, []);

  const loadAlbum = useCallback(
    async (albumId: number) => {
      const workflowToken = workflowTokenRef.current;
      const requestId = ++loadAlbumRequestIdRef.current;
      const activeAlbumIdSnapshot = activeAlbumIdRef.current;
      setSelectedAlbum(null);
      suggestionsRef.current = [];
      setSuggestions([]);
      setIsLoadingAlbum(true);
      setLookupError(null);
      setSaveError(null);
      setSuccessMessage(null);
      try {
        const album = await apiClient.getVocaDbAlbum(albumId);
        if (workflowTokenRef.current !== workflowToken || loadAlbumRequestIdRef.current !== requestId) {
          return;
        }
        const albumRows =
          activeAlbumIdSnapshot == null
            ? []
            : rows.filter((row) => row.album_id === activeAlbumIdSnapshot);
        const nextSuggestions = buildVocaDbSuggestions(albumRows, album);
        setSelectedAlbum(album);
        suggestionsRef.current = nextSuggestions;
        setSuggestions(nextSuggestions);
        setAlbumIdInput(String(album.id));
      } catch {
        if (workflowTokenRef.current !== workflowToken || loadAlbumRequestIdRef.current !== requestId) {
          return;
        }
        setLookupError("Failed to load VocaDB album.");
      } finally {
        if (workflowTokenRef.current === workflowToken && loadAlbumRequestIdRef.current === requestId) {
          setIsLoadingAlbum(false);
        }
      }
    },
    [apiClient, rows]
  );

  const loadAlbumFromInput = useCallback(async () => {
    const albumId = parseVocaDbAlbumId(albumIdInput);
    if (albumId == null) {
      loadAlbumRequestIdRef.current += 1;
      setSelectedAlbum(null);
      suggestionsRef.current = [];
      setSuggestions([]);
      setIsLoadingAlbum(false);
      setSaveError(null);
      setSuccessMessage(null);
      setLookupError("Enter a valid VocaDB album URL or ID.");
      return;
    }

    await loadAlbum(albumId);
  }, [albumIdInput, loadAlbum]);

  const toggleSuggestion = useCallback((id: string) => {
    setSaveError(null);
    setSuccessMessage(null);
    setSuggestions((current) => {
      const nextSuggestions = current.map((suggestion) =>
        suggestion.id === id ? { ...suggestion, selected: !suggestion.selected } : suggestion
      );
      suggestionsRef.current = nextSuggestions;
      return nextSuggestions;
    });
  }, []);

  const save = useCallback(async () => {
    const batchPatch = buildBatchPatchFromSelections(suggestionsRef.current);
    if (batchPatch.updates.length === 0) {
      setSaveError("Select at least one VocaDB metadata field.");
      setSuccessMessage(null);
      return;
    }

    const workflowToken = workflowTokenRef.current;
    const requestId = ++saveRequestIdRef.current;
    setIsSaving(true);
    setSaveError(null);
    setSuccessMessage(null);
    try {
      const savedRows = await apiClient.patchTrackMetadataBatch(batchPatch);
      if (workflowTokenRef.current !== workflowToken || saveRequestIdRef.current !== requestId) {
        return;
      }
      onRowsSaved(savedRows);
      setSuccessMessage("Saved VocaDB metadata.");
    } catch {
      if (workflowTokenRef.current !== workflowToken || saveRequestIdRef.current !== requestId) {
        return;
      }
      setSaveError("Failed to save VocaDB metadata.");
    } finally {
      if (workflowTokenRef.current === workflowToken && saveRequestIdRef.current === requestId) {
        setIsSaving(false);
      }
    }
  }, [apiClient, onRowsSaved]);

  return {
    activeAlbumId,
    activeRows,
    candidates,
    selectedAlbum,
    suggestions,
    albumIdInput,
    setAlbumIdInput,
    isSearching,
    isLoadingAlbum,
    isSaving,
    lookupError,
    saveError,
    successMessage,
    start,
    cancel,
    search,
    loadAlbum,
    loadAlbumFromInput,
    toggleSuggestion,
    save
  };
}
