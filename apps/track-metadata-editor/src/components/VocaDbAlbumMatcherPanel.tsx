import type { VocaDbAlbumMatcherState } from "../features/vocadb/useVocaDbAlbumMatcher";

interface VocaDbAlbumMatcherPanelProps {
  matcher: VocaDbAlbumMatcherState;
  onClose: () => void;
  onLoadAlbum: (albumId: number) => void;
  onLoadAlbumFromInput: () => void;
}

function emptyLabel(value: string): string {
  return value.trim() === "" ? "(empty)" : value;
}

export function VocaDbAlbumMatcherPanel({
  matcher,
  onClose,
  onLoadAlbum,
  onLoadAlbumFromInput
}: VocaDbAlbumMatcherPanelProps) {
  if (matcher.activeAlbumId == null) {
    return null;
  }

  const albumTitle = matcher.activeRows[0]?.album_title ?? "Album";
  const selectedSuggestionCount = matcher.suggestions.filter((suggestion) => suggestion.selected).length;
  const isWorkflowLocked = matcher.isSearching || matcher.isLoadingAlbum || matcher.isSaving;

  return (
    <section className="editor-card vocadb-panel">
      <header className="vocadb-panel__header">
        <div>
          <p className="editor-album-title">VocaDB album match</p>
          <h2 className="editor-track-title">{albumTitle}</h2>
        </div>
        <button type="button" onClick={onClose} disabled={matcher.isSaving}>
          Close
        </button>
      </header>

      <div className="vocadb-direct-load">
        <label className="editor-field">
          <span>VocaDB album URL or ID</span>
          <input
            type="text"
            aria-label="VocaDB album URL or ID"
            value={matcher.albumIdInput}
            onChange={(event) => matcher.setAlbumIdInput(event.target.value)}
            disabled={isWorkflowLocked}
          />
        </label>
        <button
          type="button"
          onClick={onLoadAlbumFromInput}
          disabled={isWorkflowLocked}
        >
          Load
        </button>
      </div>

      {matcher.isSearching && <p className="status-banner">Searching VocaDB albums...</p>}
      {matcher.isLoadingAlbum && <p className="status-banner">Loading VocaDB album...</p>}
      {matcher.lookupError != null && (
        <p className="status-banner status-banner--error">{matcher.lookupError}</p>
      )}
      {matcher.saveError != null && (
        <p className="status-banner status-banner--error">{matcher.saveError}</p>
      )}
      {matcher.successMessage != null && (
        <p className="status-banner status-banner--success">{matcher.successMessage}</p>
      )}

      {matcher.candidates.length > 0 && (
        <div className="vocadb-candidates" aria-label="VocaDB album candidates">
          {matcher.candidates.map((candidate) => (
            <button
              type="button"
              key={candidate.id}
              onClick={() => onLoadAlbum(candidate.id)}
              disabled={isWorkflowLocked}
            >
              <span>{candidate.name}</span>
              <span>{candidate.artistString}</span>
              {candidate.releaseDate.trim() !== "" && <span>{candidate.releaseDate}</span>}
            </button>
          ))}
        </div>
      )}

      {matcher.selectedAlbum != null && (
        <section className="vocadb-preview">
          <div>
            <h3>{matcher.selectedAlbum.name}</h3>
            <p>{matcher.selectedAlbum.artistString}</p>
          </div>
          <a href={matcher.selectedAlbum.url} target="_blank" rel="noreferrer">
            Open VocaDB
          </a>
        </section>
      )}

      {matcher.suggestions.length > 0 && (
        <div className="vocadb-suggestion-list">
          {matcher.suggestions.map((suggestion) => (
            <label className="vocadb-suggestion" key={suggestion.id}>
              <input
                type="checkbox"
                checked={suggestion.selected}
                onChange={() => matcher.toggleSuggestion(suggestion.id)}
                disabled={matcher.isSaving}
              />
              <span className="vocadb-suggestion__field">{suggestion.field}</span>
              <span className="vocadb-suggestion__value">
                {`${emptyLabel(suggestion.currentValue)} -> ${suggestion.suggestedValue}`}
              </span>
              {suggestion.originalValue !== suggestion.suggestedValue && (
                <span className="vocadb-suggestion__normalization">
                  {`${suggestion.originalValue} -> ${suggestion.suggestedValue}`}
                </span>
              )}
            </label>
          ))}
        </div>
      )}

      <div className="editor-actions">
        <button
          type="button"
          onClick={() => {
            void matcher.save();
          }}
          disabled={matcher.isSaving || selectedSuggestionCount === 0}
        >
          Save VocaDB metadata
        </button>
      </div>
    </section>
  );
}
