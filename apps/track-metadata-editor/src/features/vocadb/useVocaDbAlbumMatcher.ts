import { useCallback, useMemo, useRef, useState } from "react";
import type { ApiClient } from "../../api/client";
import type { TrackMetadataRow, VocaDbAlbumCandidate, VocaDbAlbumDetail } from "../../api/types";
import {
  buildBatchPatchFromTrackReviews,
  buildVocaDbTrackReviews,
  isVocaDbFieldChanged,
  parseVocaDbAlbumId,
  type VocaDbFieldReview,
  type VocaDbFieldSuggestion,
  type VocaDbTrackReview
} from "./model";

export interface VocaDbAlbumMatcherState {
  activeAlbumId: number | null;
  activeRows: TrackMetadataRow[];
  candidates: VocaDbAlbumCandidate[];
  selectedAlbum: VocaDbAlbumDetail | null;
  trackReviews: VocaDbTrackReview[];
  activeReviewTrackId: number | null;
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
  selectReviewTrack: (trackId: number) => void;
  editSuggestion: (id: string, value: string) => void;
  selectActiveTrackFields: () => void;
  clearActiveTrackFields: () => void;
  goToPreviousReviewTrack: () => void;
  goToNextReviewTrack: () => void;
  goToNextChangedReviewTrack: () => void;
  save: () => Promise<void>;
}

function errorMessage(error: unknown, fallback: string): string {
  return error instanceof Error && error.message.trim() !== "" ? error.message : fallback;
}

function isChangedSuggestion(field: VocaDbFieldReview): boolean {
  return field.available && isVocaDbFieldChanged(field.field, field.currentValue, field.suggestedValue);
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
  const trackReviewsRef = useRef<VocaDbTrackReview[]>([]);
  const [candidates, setCandidates] = useState<VocaDbAlbumCandidate[]>([]);
  const [selectedAlbum, setSelectedAlbum] = useState<VocaDbAlbumDetail | null>(null);
  const [suggestions, setSuggestions] = useState<VocaDbFieldSuggestion[]>([]);
  const [trackReviews, setTrackReviews] = useState<VocaDbTrackReview[]>([]);
  const [activeReviewTrackId, setActiveReviewTrackId] = useState<number | null>(null);
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

  const setReviewState = useCallback((nextReviews: VocaDbTrackReview[]) => {
    trackReviewsRef.current = nextReviews;
    suggestionsRef.current = nextReviews.flatMap((review) =>
      review.fields.filter(isChangedSuggestion)
    );
    setTrackReviews(nextReviews);
    setSuggestions(suggestionsRef.current);
  }, []);

  const clearReviewState = useCallback(() => {
    trackReviewsRef.current = [];
    suggestionsRef.current = [];
    setTrackReviews([]);
    setSuggestions([]);
    setActiveReviewTrackId(null);
  }, []);

  const runSearch = useCallback(
    async (query: string, workflowToken: number) => {
      const requestId = ++searchRequestIdRef.current;
      const loadRequestId = ++loadAlbumRequestIdRef.current;
      setSelectedAlbum(null);
      clearReviewState();
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
          clearReviewState();
        }
      } catch (error) {
        if (workflowTokenRef.current !== workflowToken || searchRequestIdRef.current !== requestId) {
          return;
        }
        if (loadAlbumRequestIdRef.current !== loadRequestId) {
          return;
        }
        setLookupError(errorMessage(error, "Failed to search VocaDB albums."));
        setCandidates([]);
      } finally {
        if (workflowTokenRef.current === workflowToken && searchRequestIdRef.current === requestId) {
          setIsSearching(false);
        }
      }
    },
    [apiClient, clearReviewState]
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
      clearReviewState();
      setAlbumIdInput("");
      await runSearch(albumRows[0]?.album_title ?? "", workflowToken);
    },
    [rows, runSearch, clearReviewState]
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
    clearReviewState();
    setAlbumIdInput("");
    setIsSearching(false);
    setIsLoadingAlbum(false);
    setIsSaving(false);
    setLookupError(null);
    setSaveError(null);
    setSuccessMessage(null);
  }, [clearReviewState]);

  const loadAlbum = useCallback(
    async (albumId: number) => {
      const workflowToken = workflowTokenRef.current;
      const requestId = ++loadAlbumRequestIdRef.current;
      const activeAlbumIdSnapshot = activeAlbumIdRef.current;
      setSelectedAlbum(null);
      clearReviewState();
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
        const nextReviews = buildVocaDbTrackReviews(albumRows, album);
        setSelectedAlbum(album);
        setReviewState(nextReviews);
        setActiveReviewTrackId(nextReviews[0]?.localTrack.id ?? null);
        setAlbumIdInput(String(album.id));
      } catch (error) {
        if (workflowTokenRef.current !== workflowToken || loadAlbumRequestIdRef.current !== requestId) {
          return;
        }
        setLookupError(errorMessage(error, "Failed to load VocaDB album."));
      } finally {
        if (workflowTokenRef.current === workflowToken && loadAlbumRequestIdRef.current === requestId) {
          setIsLoadingAlbum(false);
        }
      }
    },
    [apiClient, rows, clearReviewState, setReviewState]
  );

  const loadAlbumFromInput = useCallback(async () => {
    const albumId = parseVocaDbAlbumId(albumIdInput);
    if (albumId == null) {
      loadAlbumRequestIdRef.current += 1;
      setSelectedAlbum(null);
      clearReviewState();
      setIsLoadingAlbum(false);
      setSaveError(null);
      setSuccessMessage(null);
      setLookupError("Enter a valid VocaDB album URL or ID.");
      return;
    }

    await loadAlbum(albumId);
  }, [albumIdInput, loadAlbum, clearReviewState]);

  const updateTrackReviews = useCallback(
    (updater: (reviews: VocaDbTrackReview[]) => VocaDbTrackReview[]) => {
      setSaveError(null);
      setSuccessMessage(null);
      setReviewState(updater(trackReviewsRef.current));
    },
    [setReviewState]
  );

  const toggleSuggestion = useCallback(
    (id: string) => {
      updateTrackReviews((current) =>
        current.map((review) => ({
          ...review,
          fields: review.fields.map((field) =>
            field.id === id && field.available ? { ...field, selected: !field.selected } : field
          )
        }))
      );
    },
    [updateTrackReviews]
  );

  const editSuggestion = useCallback(
    (id: string, value: string) => {
      updateTrackReviews((current) =>
        current.map((review) => ({
          ...review,
          fields: review.fields.map((field) => {
            if (field.id !== id) {
              return field;
            }
            const available = value.trim() !== "";
            return {
              ...field,
              suggestedValue: value,
              available,
              selected: available ? field.selected : false
            };
          })
        }))
      );
    },
    [updateTrackReviews]
  );

  const selectReviewTrack = useCallback((trackId: number) => {
    setActiveReviewTrackId(trackId);
  }, []);

  const selectActiveTrackFields = useCallback(() => {
    updateTrackReviews((current) =>
      current.map((review) =>
        review.localTrack.id === activeReviewTrackId
          ? {
              ...review,
              fields: review.fields.map((field) =>
                field.available ? { ...field, selected: true } : field
              )
            }
          : review
      )
    );
  }, [activeReviewTrackId, updateTrackReviews]);

  const clearActiveTrackFields = useCallback(() => {
    updateTrackReviews((current) =>
      current.map((review) =>
        review.localTrack.id === activeReviewTrackId
          ? { ...review, fields: review.fields.map((field) => ({ ...field, selected: false })) }
          : review
      )
    );
  }, [activeReviewTrackId, updateTrackReviews]);

  const moveActiveReviewTrack = useCallback((direction: 1 | -1) => {
    const reviews = trackReviewsRef.current;
    if (reviews.length === 0) {
      setActiveReviewTrackId(null);
      return;
    }
    const currentIndex = Math.max(
      0,
      reviews.findIndex((review) => review.localTrack.id === activeReviewTrackId)
    );
    const nextIndex = Math.min(Math.max(currentIndex + direction, 0), reviews.length - 1);
    setActiveReviewTrackId(reviews[nextIndex].localTrack.id);
  }, [activeReviewTrackId]);

  const goToPreviousReviewTrack = useCallback(() => moveActiveReviewTrack(-1), [moveActiveReviewTrack]);
  const goToNextReviewTrack = useCallback(() => moveActiveReviewTrack(1), [moveActiveReviewTrack]);

  const goToNextChangedReviewTrack = useCallback(() => {
    const reviews = trackReviewsRef.current;
    const currentIndex = reviews.findIndex((review) => review.localTrack.id === activeReviewTrackId);
    const ordered = [...reviews.slice(currentIndex + 1), ...reviews.slice(0, currentIndex + 1)];
    const next = ordered.find((review) => review.fields.some((field) => field.available && field.selected));
    if (next != null) {
      setActiveReviewTrackId(next.localTrack.id);
    }
  }, [activeReviewTrackId]);

  const save = useCallback(async () => {
    const batchPatch = buildBatchPatchFromTrackReviews(trackReviewsRef.current);
    if (batchPatch.updates.length === 0) {
      if (successMessage != null) {
        return;
      }
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
      clearReviewState();
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
  }, [apiClient, clearReviewState, onRowsSaved, successMessage]);

  return {
    activeAlbumId,
    activeRows,
    candidates,
    selectedAlbum,
    trackReviews,
    activeReviewTrackId,
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
    selectReviewTrack,
    editSuggestion,
    selectActiveTrackFields,
    clearActiveTrackFields,
    goToPreviousReviewTrack,
    goToNextReviewTrack,
    goToNextChangedReviewTrack,
    save
  };
}
