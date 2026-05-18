export type TrackMetadataSource = "manual" | "scanned" | "empty";

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
