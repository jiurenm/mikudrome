import { useState } from "react";
import type { AlbumGroup } from "../features/tracks/model";

interface AlbumExplorerProps {
  groups: AlbumGroup[];
  selectedTrackId: number | null;
  dirtyTrackId: number | null;
  onSelectTrack: (trackId: number) => void;
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
  onSelectTrack,
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

  return (
    <aside className="explorer-card">
      <header className="explorer-header">
        <h1>Track Metadata Editor</h1>
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
              <button
                type="button"
                className="album-row"
                aria-expanded={!isCollapsed}
                onClick={() => toggleAlbum(group.album.id)}
              >
                <span>{isCollapsed ? "▸" : "▾"}</span>
                <span>{group.album.title}</span>
              </button>
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
