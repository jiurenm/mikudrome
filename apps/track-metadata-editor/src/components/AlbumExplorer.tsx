import { useState } from "react";
import type { AlbumGroup } from "../features/tracks/model";

interface AlbumExplorerProps {
  groups: AlbumGroup[];
  selectedTrackId: number | null;
  dirtyTrackId: number | null;
  isCollapsed: boolean;
  onToggleCollapsed: () => void;
  onSelectTrack: (trackId: number) => void;
  onMatchAlbum: (albumId: number) => void;
  isMatchDisabled: boolean;
  isTrackSelectionDisabled: boolean;
  search: string;
  onSearchChange: (value: string) => void;
}

function padTrackNumber(trackNumber: number): string {
  return String(trackNumber).padStart(2, "0");
}

function summarizePerson(value: string): string {
  const trimmed = value.trim();
  if (trimmed === "") {
    return "-";
  }
  return trimmed;
}

export function AlbumExplorer({
  groups,
  selectedTrackId,
  dirtyTrackId,
  isCollapsed,
  onToggleCollapsed,
  onSelectTrack,
  onMatchAlbum,
  isMatchDisabled,
  isTrackSelectionDisabled,
  search,
  onSearchChange
}: AlbumExplorerProps) {
  const [collapsedAlbumIds, setCollapsedAlbumIds] = useState<Set<number>>(
    () => new Set(groups.map((group) => group.album.id))
  );

  const toggleAlbum = (albumId: number) => {
    setCollapsedAlbumIds((current) => {
      const next = new Set(current);
      if (next.has(albumId)) {
        next.delete(albumId);
      } else {
        next.add(albumId);
      }
      return next;
    });
  };

  if (isCollapsed) {
    return (
      <aside className="explorer-card explorer-card--collapsed" aria-label="Track explorer">
        <button
          type="button"
          className="explorer-collapse-button"
          aria-label="Expand explorer"
          onClick={onToggleCollapsed}
        >
          Expand
        </button>
      </aside>
    );
  }

  return (
    <aside className="explorer-card" aria-label="Track explorer">
      <header className="explorer-header">
        <div className="explorer-title-row">
          <h1>Track Metadata Editor</h1>
          <button
            type="button"
            className="explorer-collapse-button"
            aria-label="Collapse explorer"
            onClick={onToggleCollapsed}
          >
            Collapse
          </button>
        </div>
        <input
          aria-label="Search"
          className="search-input"
          type="search"
          value={search}
          onChange={(event) => onSearchChange(event.target.value)}
        />
      </header>

      <div className="album-list">
        {groups.map((group) => {
          const isCollapsed = collapsedAlbumIds.has(group.album.id);
          return (
            <section className="album-card" key={group.album.id}>
              <div className="album-row">
                <button
                  type="button"
                  className="album-row__toggle"
                  aria-expanded={!isCollapsed}
                  onClick={() => toggleAlbum(group.album.id)}
                >
                  <span>{isCollapsed ? "▸" : "▾"}</span>
                  <span>{group.album.title}</span>
                </button>
                <button
                  type="button"
                  className="album-row__match"
                  aria-label={`Match VocaDB for ${group.album.title} album ${group.album.id}`}
                  onClick={() => onMatchAlbum(group.album.id)}
                  disabled={isMatchDisabled}
                >
                  Match VocaDB
                </button>
              </div>
              {!isCollapsed && (
                <div className="track-list">
                  {group.tracks.map((track) => {
                    const isSelected = track.id === selectedTrackId;
                    const isDirty = track.id === dirtyTrackId;
                    return (
                      <button
                        type="button"
                        className={`track-row${isSelected ? " track-row--selected" : ""}`}
                        key={track.id}
                        onClick={() => onSelectTrack(track.id)}
                        disabled={isTrackSelectionDisabled}
                      >
                        <span className="track-row__title">
                          {padTrackNumber(track.track_number)} {track.title}
                        </span>
                        <span className="track-row__summary">
                          C: {summarizePerson(track.composer)} / L: {summarizePerson(track.lyricist)}
                        </span>
                        {isDirty && <span className="track-row__unsaved">Unsaved</span>}
                      </button>
                    );
                  })}
                </div>
              )}
            </section>
          );
        })}
      </div>
    </aside>
  );
}
