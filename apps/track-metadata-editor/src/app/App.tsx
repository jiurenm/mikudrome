import { useEffect, useMemo } from "react";
import { createApiClient } from "../api/client";
import { AlbumExplorer } from "../components/AlbumExplorer";
import { TrackEditorPanel } from "../components/TrackEditorPanel";
import { VocaDbAlbumMatcherPanel } from "../components/VocaDbAlbumMatcherPanel";
import { useTrackMetadataEditor } from "../features/tracks/useTrackMetadataEditor";
import { useVocaDbAlbumMatcher } from "../features/vocadb/useVocaDbAlbumMatcher";

export default function App() {
  const client = useMemo(() => createApiClient(), []);
  const editor = useTrackMetadataEditor(client);
  const matcher = useVocaDbAlbumMatcher(client, editor.allRows, editor.replaceRows);
  const isMatcherDirty =
    matcher.successMessage == null && matcher.suggestions.some((suggestion) => suggestion.selected);

  useEffect(() => {
    if (!editor.isDirty && !matcher.isSaving && !isMatcherDirty) {
      return;
    }

    const handleBeforeUnload = (event: BeforeUnloadEvent) => {
      event.preventDefault();
      event.returnValue = "";
    };

    window.addEventListener("beforeunload", handleBeforeUnload);
    return () => {
      window.removeEventListener("beforeunload", handleBeforeUnload);
    };
  }, [editor.isDirty, matcher.isSaving, isMatcherDirty]);

  const handleSelectTrack = (trackId: number) => {
    if (matcher.isSaving) {
      return;
    }

    if (trackId === editor.selectedTrackId) {
      return;
    }

    if (editor.isDirty && !window.confirm("Discard unsaved changes?")) {
      return;
    }
    editor.selectTrack(trackId, true);
  };

  const handleMatchAlbum = (albumId: number) => {
    if (matcher.isSaving) {
      return;
    }

    if (editor.isDirty || isMatcherDirty) {
      if (!window.confirm("Discard unsaved changes?")) {
        return;
      }
    }

    if (editor.isDirty) {
      editor.resetDraft();
    }

    void matcher.start(albumId);
  };

  const handleCloseMatcher = () => {
    if (matcher.isSaving) {
      return;
    }

    if (isMatcherDirty && !window.confirm("Discard unsaved changes?")) {
      return;
    }

    matcher.cancel();
  };

  const canDiscardMatcherChanges = () => {
    return !isMatcherDirty || window.confirm("Discard unsaved changes?");
  };

  const handleLoadMatcherAlbum = (albumId: number) => {
    if (matcher.isSaving || !canDiscardMatcherChanges()) {
      return;
    }

    void matcher.loadAlbum(albumId);
  };

  const handleLoadMatcherAlbumFromInput = () => {
    if (matcher.isSaving || !canDiscardMatcherChanges()) {
      return;
    }

    void matcher.loadAlbumFromInput();
  };

  if (editor.isLoading) {
    return (
      <main className="app-shell">
        <section className="app-empty">Loading…</section>
      </main>
    );
  }

  if (editor.loadError != null) {
    return (
      <main className="app-shell">
        <section className="app-empty">
          <p>{editor.loadError}</p>
          <button
            type="button"
            onClick={() => {
              void editor.reload();
            }}
          >
            Retry
          </button>
        </section>
      </main>
    );
  }

  const dirtyTrackId = editor.isDirty ? editor.selectedTrackId : null;

  return (
    <main className="app-shell app-shell--workbench">
      <AlbumExplorer
        groups={editor.albumGroups}
        selectedTrackId={editor.selectedTrackId}
        dirtyTrackId={dirtyTrackId}
        onSelectTrack={handleSelectTrack}
        onMatchAlbum={handleMatchAlbum}
        isMatchDisabled={matcher.isSaving}
        isTrackSelectionDisabled={matcher.isSaving}
        search={editor.search}
        onSearchChange={editor.setSearch}
      />
      {matcher.activeAlbumId == null ? (
        <TrackEditorPanel
          row={editor.selectedRow}
          draft={editor.draft}
          getAlbumCoverUrl={client.albumCoverUrl}
          isDirty={editor.isDirty}
          isSaving={editor.isSaving}
          saveError={editor.saveError}
          successMessage={editor.successMessage}
          onChange={editor.updateDraft}
          onReset={editor.resetDraft}
          onSave={() => {
            void editor.save();
          }}
        />
      ) : (
        <VocaDbAlbumMatcherPanel
          matcher={matcher}
          onClose={handleCloseMatcher}
          onLoadAlbum={handleLoadMatcherAlbum}
          onLoadAlbumFromInput={handleLoadMatcherAlbumFromInput}
        />
      )}
    </main>
  );
}
