export type TrackMetadataSource = "manual" | "scanned" | "empty";

export type VocaDbEditableFieldName =
  | "composer"
  | "lyricist"
  | "arranger"
  | "remix"
  | "vocal"
  | "voice_manipulator"
  | "illustrator"
  | "movie"
  | "source";

export interface TrackMetadataRow {
  id: number;
  title: string;
  track_number: number;
  disc_number: number;
  album_id: number;
  album_title: string;
  album_cover_path: string;
  producer_id: number;
  producer_name: string;
  composer: string;
  lyricist: string;
  arranger: string;
  remix: string;
  vocal: string;
  voice_manipulator: string;
  illustrator: string;
  movie: string;
  source: string;
  composer_source: TrackMetadataSource;
  lyricist_source: TrackMetadataSource;
}

export interface TrackMetadataPatch {
  composer?: string;
  lyricist?: string;
  arranger?: string;
  remix?: string;
  vocal?: string;
  voice_manipulator?: string;
  illustrator?: string;
  movie?: string;
  source?: string;
}

export interface TrackMetadataBatchUpdate {
  track_id: number;
  patch: TrackMetadataPatch;
}

export interface TrackMetadataBatchPatch {
  updates: TrackMetadataBatchUpdate[];
}

export interface TrackMetadataBatchResponse {
  tracks: TrackMetadataRow[];
}

export interface VocaDbAlbumCandidate {
  id: number;
  name: string;
  artistString: string;
  url: string;
  releaseDate: string;
}

export interface VocaDbArtistRoleCredit {
  name: string;
  roles: string[];
}

export interface VocaDbAlbumTrack {
  discNumber: number;
  trackNumber: number;
  title: string;
  songId: number | null;
  url: string;
  producers: string[];
  vocalists: string[];
  artists: VocaDbArtistRoleCredit[];
}

export interface VocaDbAlbumDetail {
  id: number;
  name: string;
  artistString: string;
  url: string;
  tracks: VocaDbAlbumTrack[];
}

export interface VocaDbAlbumSearchResponse {
  albums: VocaDbAlbumCandidate[];
}

export interface VocaDbAlbumDetailResponse {
  album: VocaDbAlbumDetail;
}
