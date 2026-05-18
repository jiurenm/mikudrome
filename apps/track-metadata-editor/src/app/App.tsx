import { useEffect, useMemo } from "react";
import { createApiClient } from "../api/client";
import { AlbumExplorer } from "../components/AlbumExplorer";
import { TrackEditorPanel } from "../components/TrackEditorPanel";
import { useTrackMetadataEditor } from "../features/tracks/useTrackMetadataEditor";

export default function App() {
  const client = useMemo(() => createApiClient(), []);
  const editor = useTrackMetadataEditor(client);

  useEffect(() => {
    if (!editor.isDirty) {
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
  }, [editor.isDirty]);

  const handleSelectTrack = (trackId: number) => {
    if (trackId === editor.selectedTrackId) {
      return;
    }

    if (editor.isDirty && !window.confirm("Discard unsaved changes?")) {
      return;
    }
    editor.selectTrack(trackId, true);
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
        search={editor.search}
        onSearchChange={editor.setSearch}
      />
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
    </main>
  );
}
