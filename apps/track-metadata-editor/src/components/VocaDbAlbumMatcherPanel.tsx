import type { VocaDbAlbumMatcherState } from "../features/vocadb/useVocaDbAlbumMatcher";
import type { VocaDbTrackReview } from "../features/vocadb/model";

interface VocaDbAlbumMatcherPanelProps {
  matcher: VocaDbAlbumMatcherState;
  onClose: () => void;
  onLoadAlbum: (albumId: number) => void;
  onLoadAlbumFromInput: () => void;
}

function emptyLabel(value: string): string {
  return value.trim() === "" ? "(empty)" : value;
}

function trackLabel(trackNumber: number, title: string): string {
  return `${String(trackNumber).padStart(2, "0")} ${title}`;
}

const fieldLabels = new Map([
  ["composer", "Composer"],
  ["lyricist", "Lyricist"],
  ["arranger", "Arranger"],
  ["remix", "Remix"],
  ["vocal", "Vocal"],
  ["voice_manipulator", "Voice manipulation"],
  ["illustrator", "Illustrator"],
  ["movie", "Movie"],
  ["source", "Source"]
]);

function selectedFieldCount(review: VocaDbTrackReview): number {
  return review.fields.filter((field) => field.selected).length;
}

function availableFieldCount(review: VocaDbTrackReview): number {
  return review.fields.filter((field) => field.available).length;
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
  const activeReview =
    matcher.trackReviews.find((review) => review.localTrack.id === matcher.activeReviewTrackId) ??
    matcher.trackReviews[0] ??
    null;

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

      {matcher.trackReviews.length > 0 && (
        <div className="vocadb-workspace">
          <aside className="vocadb-sidebar">
            <div className="vocadb-track-queue" aria-label="VocaDB track queue">
              {matcher.trackReviews.map((review) => (
                <button
                  type="button"
                  key={review.localTrack.id}
                  className={`vocadb-track-queue__item${
                    review.localTrack.id === activeReview?.localTrack.id
                      ? " vocadb-track-queue__item--active"
                      : ""
                  }`}
                  onClick={() => matcher.selectReviewTrack(review.localTrack.id)}
                  disabled={matcher.isSaving}
                >
                  <span>{trackLabel(review.localTrack.track_number, review.localTrack.title)}</span>
                  <span>{review.status}</span>
                  <span>
                    {selectedFieldCount(review)} / {availableFieldCount(review)}
                  </span>
                </button>
              ))}
            </div>
          </aside>

          {activeReview != null && (
            <section className="vocadb-track-review">
              <header className="vocadb-track-review__header">
                <div>
                  <p className="editor-album-title">Track review</p>
                  <h3>{trackLabel(activeReview.localTrack.track_number, activeReview.localTrack.title)}</h3>
                  {activeReview.vocaTrack != null && <p>{activeReview.vocaTrack.title}</p>}
                </div>
                {activeReview.vocaTrack != null && activeReview.vocaTrack.url.trim() !== "" && (
                  <a href={activeReview.vocaTrack.url} target="_blank" rel="noreferrer">
                    Open song
                  </a>
                )}
              </header>

              <div className="vocadb-track-review__toolbar">
                <button
                  type="button"
                  onClick={matcher.selectActiveTrackFields}
                  disabled={matcher.isSaving}
                >
                  Select track fields
                </button>
                <button
                  type="button"
                  onClick={matcher.clearActiveTrackFields}
                  disabled={matcher.isSaving}
                >
                  Clear track fields
                </button>
              </div>

              <div className="vocadb-field-grid">
                {activeReview.fields.map((field) => (
                  <div
                    className={`vocadb-field-row${field.available ? "" : " vocadb-field-row--empty"}`}
                    key={field.id}
                  >
                    <input
                      type="checkbox"
                      aria-label={`${field.field} selected`}
                      checked={field.selected}
                      disabled={matcher.isSaving || !field.available}
                      onChange={() => matcher.toggleSuggestion(field.id)}
                    />
                    <span className="vocadb-field-row__name">
                      {fieldLabels.get(field.field) ?? field.field}
                    </span>
                    <span className="vocadb-field-row__current">{emptyLabel(field.currentValue)}</span>
                    <input
                      type="text"
                      aria-label={`${field.field} suggestion`}
                      value={field.suggestedValue}
                      disabled={matcher.isSaving}
                      onChange={(event) => {
                        const nextValue = event.target.value;
                        matcher.editSuggestion(field.id, nextValue);
                        if (nextValue.trim() !== "" && !field.available) {
                          matcher.toggleSuggestion(field.id);
                        }
                      }}
                    />
                    <span
                      className={`vocadb-field-row__confidence vocadb-field-row__confidence--${field.confidence}`}
                    >
                      {field.available ? field.confidence : "missing"}
                    </span>
                  </div>
                ))}
              </div>

              <footer className="vocadb-track-review__nav">
                <button
                  type="button"
                  onClick={matcher.goToPreviousReviewTrack}
                  disabled={matcher.isSaving}
                >
                  Previous
                </button>
                <button
                  type="button"
                  onClick={matcher.goToNextChangedReviewTrack}
                  disabled={matcher.isSaving}
                >
                  Next selected
                </button>
                <button
                  type="button"
                  onClick={matcher.goToNextReviewTrack}
                  disabled={matcher.isSaving}
                >
                  Next
                </button>
              </footer>
            </section>
          )}
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
