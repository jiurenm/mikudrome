import type { TrackMetadataRow } from "../api/types";
import { editableKeys, type TrackMetadataDraft } from "../features/tracks/model";
import { StatusBanner } from "./StatusBanner";

interface TrackEditorPanelProps {
  row: TrackMetadataRow | null;
  draft: TrackMetadataDraft | null;
  getAlbumCoverUrl: (albumId: number) => string;
  isDirty: boolean;
  isSaving: boolean;
  saveError: string | null;
  successMessage: string | null;
  onChange: (field: keyof TrackMetadataDraft, value: string) => void;
  onReset: () => void;
  onSave: () => void;
}

function padTrackNumber(trackNumber: number): string {
  return String(trackNumber).padStart(2, "0");
}

export function TrackEditorPanel({
  row,
  draft,
  getAlbumCoverUrl,
  isDirty,
  isSaving,
  saveError,
  successMessage,
  onChange,
  onReset,
  onSave
}: TrackEditorPanelProps) {
  if (row == null || draft == null) {
    return (
      <section className="editor-card editor-card--empty">
        <p className="editor-empty">Select a track to edit its metadata.</p>
      </section>
    );
  }

  const isActionDisabled = !isDirty || isSaving;

  return (
    <section className="editor-card">
      <header className="editor-header">
        <img
          className="album-cover"
          src={getAlbumCoverUrl(row.album_id)}
          alt={`${row.album_title} cover`}
        />
        <div>
          <p className="editor-album-title">{row.album_title}</p>
          <h2 className="editor-track-title">
            {padTrackNumber(row.track_number)} {row.title}
          </h2>
          <p className="editor-meta">
            {row.producer_name} • Disc {row.disc_number}
          </p>
          <div className="source-pills">
            <span className="source-pill">composer_source: {row.composer_source}</span>
            <span className="source-pill">lyricist_source: {row.lyricist_source}</span>
          </div>
        </div>
      </header>

      {saveError != null && <StatusBanner tone="error" message={saveError} />}
      {successMessage != null && <StatusBanner tone="success" message={successMessage} />}

      <form
        className="editor-form"
        onSubmit={(event) => {
          event.preventDefault();
          onSave();
        }}
      >
        {editableKeys.map((field) => (
          <label className="editor-field" key={field}>
            <span>{field}</span>
            <input
              aria-label={field}
              type="text"
              disabled={isSaving}
              value={draft[field]}
              onChange={(event) => onChange(field, event.target.value)}
            />
          </label>
        ))}

        <div className="editor-actions">
          <button type="button" disabled={isActionDisabled} onClick={onReset}>
            Reset
          </button>
          <button type="submit" disabled={isActionDisabled}>
            Save
          </button>
        </div>
      </form>
    </section>
  );
}
