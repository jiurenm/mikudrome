import type {
  TrackMetadataBatchPatch,
  TrackMetadataRow,
  VocaDbAlbumDetail,
  VocaDbEditableFieldName,
  VocaDbAlbumTrack
} from "../../api/types";
import type { TrackMetadataDraft } from "../tracks/model";

type EditableField = VocaDbEditableFieldName;

export type MatchStatus = "matched" | "unmatched" | "ambiguous";
export type SuggestionConfidence = "explicit" | "fallback";

export interface AlbumTrackMatch {
  localTrack: TrackMetadataRow;
  vocaTrack: VocaDbAlbumTrack | null;
  status: MatchStatus;
}

export interface VocaDbFieldSuggestion {
  id: string;
  trackId: number;
  field: EditableField;
  currentValue: string;
  originalValue: string;
  suggestedValue: string;
  confidence: SuggestionConfidence;
  selected: boolean;
}

export interface VocaDbFieldReview {
  id: string;
  trackId: number;
  field: EditableField;
  currentValue: string;
  originalValue: string;
  suggestedValue: string;
  confidence: SuggestionConfidence;
  selected: boolean;
  available: boolean;
}

export interface VocaDbTrackReview {
  localTrack: TrackMetadataRow;
  vocaTrack: VocaDbAlbumTrack | null;
  status: MatchStatus;
  fields: VocaDbFieldReview[];
}

const roleToField = new Map<string, EditableField>([
  ["composer", "composer"],
  ["music", "composer"],
  ["lyricist", "lyricist"],
  ["lyrics", "lyricist"],
  ["arranger", "arranger"],
  ["remixer", "remix"],
  ["vocalist", "vocal"],
  ["singer", "vocal"],
  ["voicebank", "vocal"],
  ["illustrator", "illustrator"],
  ["animator", "movie"],
  ["movie", "movie"],
  ["pv", "movie"],
  ["voice manipulation", "voice_manipulator"],
  ["tuning", "voice_manipulator"],
  ["tuner", "voice_manipulator"]
]);

const suggestionFields: EditableField[] = [
  "composer",
  "lyricist",
  "arranger",
  "remix",
  "vocal",
  "voice_manipulator",
  "illustrator",
  "movie",
  "source"
];

export function parseVocaDbAlbumId(input: string): number | null {
  const trimmed = input.trim();
  if (trimmed === "") {
    return null;
  }

  if (/^[1-9]\d*$/.test(trimmed)) {
    return Number(trimmed);
  }

  const match = /^https?:\/\/(?:www\.)?vocadb\.net\/Al\/([1-9]\d*)(?:[/?#].*)?$/i.exec(trimmed);
  return match == null ? null : Number(match[1]);
}

export function normalizeVocalName(name: string, existingLocalVocal = ""): string {
  const normalized = normalizeKnownVocalVersion(name);
  const local = existingLocalVocal.trim();
  if (local !== "" && canonicalVocalKey(normalizeKnownVocalVersion(local)) === canonicalVocalKey(normalized)) {
    return local;
  }
  return normalized;
}

export function alignAlbumTracks(
  localRows: TrackMetadataRow[],
  album: VocaDbAlbumDetail
): AlbumTrackMatch[] {
  return localRows.map((localTrack) => {
    const numberedMatches = album.tracks.filter(
      (track) =>
        track.discNumber === localTrack.disc_number && track.trackNumber === localTrack.track_number
    );
    if (numberedMatches.length === 1) {
      return { localTrack, vocaTrack: numberedMatches[0], status: "matched" };
    }
    if (numberedMatches.length > 1) {
      return { localTrack, vocaTrack: null, status: "ambiguous" };
    }

    const normalizedLocalTitle = normalizeTitle(localTrack.title);
    const titleMatches = album.tracks.filter((track) => normalizeTitle(track.title) === normalizedLocalTitle);
    if (titleMatches.length === 1) {
      return { localTrack, vocaTrack: titleMatches[0], status: "matched" };
    }
    if (titleMatches.length > 1) {
      return { localTrack, vocaTrack: null, status: "ambiguous" };
    }

    return { localTrack, vocaTrack: null, status: "unmatched" };
  });
}

export function buildVocaDbSuggestions(
  localRows: TrackMetadataRow[],
  album: VocaDbAlbumDetail
): VocaDbFieldSuggestion[] {
  return buildVocaDbTrackReviews(localRows, album)
    .flatMap((review) => review.fields)
    .filter((field) => field.available && !valuesMatch(field.field, field.currentValue, field.suggestedValue));
}

export function buildVocaDbTrackReviews(
  localRows: TrackMetadataRow[],
  album: VocaDbAlbumDetail
): VocaDbTrackReview[] {
  return alignAlbumTracks(localRows, album).map((match) => {
    if (match.status !== "matched" || match.vocaTrack == null) {
      return {
        ...match,
        fields: suggestionFields.map((field) => emptyFieldReview(match.localTrack, field))
      };
    }

    const explicit = collectExplicitCredits(match.vocaTrack);
    addFallbackCredit(explicit, "composer", match.vocaTrack.producers);
    addFallbackCredit(explicit, "lyricist", match.vocaTrack.producers);
    addFallbackCredit(explicit, "vocal", match.vocaTrack.vocalists);

    explicit.set("source", {
      originalValue: match.vocaTrack.url,
      confidence: "explicit"
    });

    return {
      ...match,
      fields: suggestionFields.map((field) => {
        const credit = explicit.get(field);
        if (credit == null || credit.originalValue.trim() === "") {
          return emptyFieldReview(match.localTrack, field);
        }

        const currentValue = match.localTrack[field];
        const suggestedValue =
          field === "vocal"
            ? normalizeJoinedVocalCredit(credit.originalValue, currentValue)
            : credit.originalValue;
        const hasChange = suggestedValue.trim() !== "" && !valuesMatch(field, currentValue, suggestedValue);

        return {
          id: `${match.localTrack.id}-${field}`,
          trackId: match.localTrack.id,
          field,
          currentValue,
          originalValue: credit.originalValue,
          suggestedValue,
          confidence: credit.confidence,
          available: suggestedValue.trim() !== "",
          selected: hasChange && currentValue.trim() === ""
        };
      })
    };
  });
}

function emptyFieldReview(localTrack: TrackMetadataRow, field: EditableField): VocaDbFieldReview {
  return {
    id: `${localTrack.id}-${field}`,
    trackId: localTrack.id,
    field,
    currentValue: localTrack[field],
    originalValue: "",
    suggestedValue: "",
    confidence: "fallback",
    available: false,
    selected: false
  };
}

export function buildBatchPatchFromSelections(
  suggestions: VocaDbFieldSuggestion[]
): TrackMetadataBatchPatch {
  const updatesByTrack = new Map<number, Partial<TrackMetadataDraft>>();

  for (const suggestion of suggestions) {
    if (!suggestion.selected || valuesMatch(suggestion.field, suggestion.currentValue, suggestion.suggestedValue)) {
      continue;
    }

    let patch = updatesByTrack.get(suggestion.trackId);
    if (patch == null) {
      patch = {};
      updatesByTrack.set(suggestion.trackId, patch);
    }
    patch[suggestion.field] = suggestion.suggestedValue;
  }

  return {
    updates: Array.from(updatesByTrack.entries()).map(([trackId, patch]) => ({
      track_id: trackId,
      patch
    }))
  };
}

export function buildBatchPatchFromTrackReviews(
  reviews: VocaDbTrackReview[]
): TrackMetadataBatchPatch {
  return buildBatchPatchFromSelections(reviews.flatMap((review) => review.fields));
}

function collectExplicitCredits(
  vocaTrack: VocaDbAlbumTrack
): Map<EditableField, { originalValue: string; confidence: SuggestionConfidence }> {
  const values = new Map<EditableField, string[]>();

  for (const artist of vocaTrack.artists) {
    for (const role of artist.roles.flatMap(splitRole)) {
      const field = roleToField.get(role);
      if (field == null) {
        continue;
      }

      const fieldValues = values.get(field) ?? [];
      fieldValues.push(artist.name);
      values.set(field, fieldValues);
    }
  }

  const credits = new Map<EditableField, { originalValue: string; confidence: SuggestionConfidence }>();
  for (const [field, fieldValues] of values) {
    credits.set(field, {
      originalValue: uniqueJoined(fieldValues),
      confidence: "explicit"
    });
  }
  return credits;
}

function addFallbackCredit(
  credits: Map<EditableField, { originalValue: string; confidence: SuggestionConfidence }>,
  field: EditableField,
  values: string[]
) {
  if (credits.has(field) || values.length === 0) {
    return;
  }

  const originalValue = uniqueJoined(values);
  if (originalValue !== "") {
    credits.set(field, { originalValue, confidence: "fallback" });
  }
}

function splitRole(role: string): string[] {
  return role
    .toLowerCase()
    .split(/[\/,]/)
    .map((part) => part.trim())
    .filter(Boolean);
}

function uniqueJoined(values: string[]): string {
  return Array.from(new Set(values.map((value) => value.trim()).filter(Boolean))).join(", ");
}

function normalizeJoinedVocalCredit(originalValue: string, existingLocalVocal: string): string {
  return originalValue
    .split(",")
    .map((name) => normalizeVocalName(name, existingLocalVocal))
    .filter(Boolean)
    .join(", ");
}

function normalizeKnownVocalVersion(name: string): string {
  const trimmed = name.trim().replace(/\s+/g, " ");
  const separatedSuffix = /^(.+?)[\s-]+(?:v2|v3|v4|v4x|v6|append|nt|ai|sv)$/i.exec(trimmed);
  if (separatedSuffix != null) {
    return separatedSuffix[1].trim();
  }

  const japaneseSuffix =
    /^([\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Han}ー々〆〤]+)(?:v2|v3|v4|v4x|v6|append|nt|ai|sv)$/iu.exec(
      trimmed
    );
  return japaneseSuffix == null ? trimmed : japaneseSuffix[1].trim();
}

function canonicalVocalKey(name: string): string {
  if (/^hatsune miku$/i.test(name) || name === "初音ミク") {
    return "hatsune-miku";
  }
  return name.toLowerCase();
}

function valuesMatch(field: EditableField, currentValue: string, suggestedValue: string): boolean {
  if (field === "vocal") {
    return canonicalVocalKey(normalizeVocalName(currentValue)) === canonicalVocalKey(normalizeVocalName(suggestedValue));
  }
  return currentValue.trim() === suggestedValue.trim();
}

function normalizeTitle(title: string): string {
  return title
    .trim()
    .replace(/[\[(][^\])]*(?:ver\.?|version|mix|remaster|remix|edit|instrumental)[^\])]*[\])]/gi, "")
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase();
}
