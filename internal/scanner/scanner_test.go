package scanner

import (
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"strings"
	"sync"
	"testing"

	"github.com/dhowden/tag"
	"github.com/mikudrome/mikudrome/internal/store"
)

func TestRunFFprobeRequestsTask1Aliases(t *testing.T) {
	tmpDir := t.TempDir()
	audioPath := filepath.Join(tmpDir, "sample.wav")
	if err := os.WriteFile(audioPath, []byte("not a real wav"), 0o644); err != nil {
		t.Fatalf("write audio file: %v", err)
	}

	ffprobePath := filepath.Join(tmpDir, "ffprobe")
	script := `#!/bin/sh
format_tags=""
while [ "$#" -gt 0 ]; do
	if [ "$1" = "-show_entries" ]; then
		shift
		case "$1" in
			format_tags=*)
				format_tags=${1#format_tags=}
				;;
		esac
	fi
	shift
done
if [ -z "$format_tags" ]; then
	echo "missing format_tags entry" >&2
	exit 9
fi
OLD_IFS=$IFS
IFS=,
set -- $format_tags
IFS=$OLD_IFS
for required in title INAM inam artist IART iart album IPRD iprd album_artist albumartist TPE2 tpe2 track ITRK itrk disc TPOS tpos IPRT iprt date year ICRD icrd lyrics LYRICS comment; do
	found=0
	for token in "$@"; do
		if [ "$token" = "$required" ]; then
			found=1
			break
		fi
	done
	if [ "$found" -ne 1 ]; then
		echo "missing tag $required" >&2
		exit 9
	fi
done
printf '%s\n' '{"streams":[{"codec_name":"pcm_s16le","bits_per_sample":16}],"format":{"duration":"1.0","tags":{"INAM":"alias title","TPOS":"3/4","year":"2014"}}}'
`
	if err := os.WriteFile(ffprobePath, []byte(script), 0o755); err != nil {
		t.Fatalf("write fake ffprobe: %v", err)
	}

	origPath := os.Getenv("PATH")
	t.Setenv("PATH", tmpDir+string(os.PathListSeparator)+origPath)

	duration, format, tags := runFFprobe(audioPath)

	if duration != 1 {
		t.Fatalf("duration = %d, want %d", duration, 1)
	}
	if format != "16bit PCM_S16LE" {
		t.Fatalf("format = %q, want %q", format, "16bit PCM_S16LE")
	}
	if got := tags["INAM"]; got != "alias title" {
		t.Fatalf("INAM = %q, want %q", got, "alias title")
	}
	if got := tags["TPOS"]; got != "3/4" {
		t.Fatalf("TPOS = %q, want %q", got, "3/4")
	}
	if got := tags["year"]; got != "2014" {
		t.Fatalf("year = %q, want %q", got, "2014")
	}
}

func TestLookupTagPrefersRequestedAliasOrderDuringCaseInsensitiveFallback(t *testing.T) {
	keys := []string{"album_artist", "albumartist", "TPE2"}
	preferredValue := "preferred alias"
	lowerPriorityValue := "lower priority alias"

	seen := map[string]bool{}
	for range 512 {
		tags := map[string]string{
			"AlbumArtist": preferredValue,
			"tpe2":        lowerPriorityValue,
		}
		seen[lookupTag(tags, keys...)] = true
	}

	if seen[lowerPriorityValue] {
		t.Fatalf("lookupTag returned lower-priority alias during case-insensitive fallback: %v", mapsKeys(seen))
	}
	if !seen[preferredValue] {
		t.Fatalf("lookupTag never returned preferred alias: %v", mapsKeys(seen))
	}
}

func TestLookupTagPrefersHigherPriorityAliasBeforeLowerPriorityExactMatch(t *testing.T) {
	tags := map[string]string{
		"Title": "preferred",
		"INAM":  "fallback",
	}

	got := lookupTag(tags, "title", "INAM")

	if got != "preferred" {
		t.Fatalf("lookupTag returned %q, want %q", got, "preferred")
	}
}

func TestProcessFileUsesWAVTagAliases(t *testing.T) {
	tests := []struct {
		name string
		tags map[string]string
	}{
		{
			name: "uppercase wav aliases",
			tags: map[string]string{
				"INAM":   "World Is Mine",
				"IART":   "ryo",
				"IPRD":   "supercell",
				"TPE2":   "supercell",
				"ITRK":   "7/12",
				"IPRT":   "2/2",
				"ICRD":   "2009",
				"LYRICS": "君は王女",
			},
		},
		{
			name: "lowercase wav aliases",
			tags: map[string]string{
				"inam":   "World Is Mine",
				"iart":   "ryo",
				"iprd":   "supercell",
				"tpe2":   "supercell",
				"itrk":   "7/12",
				"tpos":   "2/2",
				"icrd":   "2009",
				"lyrics": "君は王女",
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			tmpDir := t.TempDir()
			restoreSeams := stubScannerSeams()
			defer restoreSeams()

			audioDir := filepath.Join(tmpDir, "artist-folder", "random-album-dir")
			if err := os.MkdirAll(audioDir, 0o755); err != nil {
				t.Fatalf("mkdir audio dir: %v", err)
			}
			audioPath := filepath.Join(audioDir, "world-is-mine.wav")
			if err := os.WriteFile(audioPath, []byte("not a real wav"), 0o644); err != nil {
				t.Fatalf("write audio file: %v", err)
			}
			videoPath := filepath.Join(audioDir, "world-is-mine.mp4")
			if err := os.WriteFile(videoPath, []byte("not a real mp4"), 0o644); err != nil {
				t.Fatalf("write video file: %v", err)
			}

			ffprobeRunner = func(path string) (int, string, map[string]string) {
				if path != audioPath {
					t.Fatalf("ffprobe path = %q, want %q", path, audioPath)
				}
				return 215, "24bit PCM_S24LE", tc.tags
			}
			metadataReader = func(path string) (tag.Metadata, error) {
				if path != audioPath {
					t.Fatalf("metadataReader path = %q, want %q", path, audioPath)
				}
				return fakeMetadata{}, nil
			}
			embeddedPictureReader = func(path string) (*tag.Picture, error) {
				if path != audioPath {
					t.Fatalf("embeddedPictureReader path = %q, want %q", path, audioPath)
				}
				return nil, nil
			}
			wavCoverExtractor = func(gotAudioPath, gotAlbumDir string) string {
				if gotAudioPath != audioPath {
					t.Fatalf("wavCoverExtractor audioPath = %q, want %q", gotAudioPath, audioPath)
				}
				if gotAlbumDir != audioDir {
					t.Fatalf("wavCoverExtractor albumDir = %q, want %q", gotAlbumDir, audioDir)
				}
				return ""
			}
			videoThumbFinder = func(path string) string {
				if path != videoPath {
					t.Fatalf("video thumb path = %q, want %q", path, videoPath)
				}
				return filepath.Join(audioDir, "world-is-mine.jpg")
			}

			result := processFile(scanJob{audioPath: audioPath}, tmpDir)

			if result.track.Title != "World Is Mine" {
				t.Fatalf("title = %q, want %q", result.track.Title, "World Is Mine")
			}
			if result.track.Artists != "ryo" {
				t.Fatalf("artists = %q, want %q", result.track.Artists, "ryo")
			}
			if result.album.Title != "supercell" {
				t.Fatalf("album title = %q, want %q", result.album.Title, "supercell")
			}
			if result.album.AlbumArtist != "supercell" {
				t.Fatalf("album artist = %q, want %q", result.album.AlbumArtist, "supercell")
			}
			if result.track.TrackNumber != 7 {
				t.Fatalf("track number = %d, want %d", result.track.TrackNumber, 7)
			}
			if result.track.DiscNumber != 2 {
				t.Fatalf("disc number = %d, want %d", result.track.DiscNumber, 2)
			}
			if result.track.Year != 2009 {
				t.Fatalf("year = %d, want %d", result.track.Year, 2009)
			}
			if result.track.DurationSeconds != 215 {
				t.Fatalf("duration = %d, want %d", result.track.DurationSeconds, 215)
			}
			if result.track.Format != "24bit PCM_S24LE" {
				t.Fatalf("format = %q, want %q", result.track.Format, "24bit PCM_S24LE")
			}
			if result.track.Lyrics != "君は王女" {
				t.Fatalf("lyrics = %q, want %q", result.track.Lyrics, "君は王女")
			}
			if result.track.VideoThumbPath != filepath.Join(audioDir, "world-is-mine.jpg") {
				t.Fatalf("video thumb path = %q, want %q", result.track.VideoThumbPath, filepath.Join(audioDir, "world-is-mine.jpg"))
			}
		})
	}
}

func TestProcessFileUsesPlannedAliasAlternates(t *testing.T) {
	tests := []struct {
		name            string
		tags            map[string]string
		wantTitle       string
		wantArtists     string
		wantAlbum       string
		wantTrack       int
		wantAlbumArtist string
		wantYear        int
		wantDisc        int
	}{
		{
			name: "album_artist and date",
			tags: map[string]string{
				"title":        "Tell Your World",
				"artist":       "livetune",
				"album":        "Re:Dial",
				"album_artist": "kz",
				"track":        "1/12",
				"date":         "2012-03-14",
				"TPOS":         "2/3",
			},
			wantTitle:       "Tell Your World",
			wantArtists:     "livetune",
			wantAlbum:       "Re:Dial",
			wantTrack:       1,
			wantAlbumArtist: "kz",
			wantYear:        2012,
			wantDisc:        2,
		},
		{
			name: "albumartist and year",
			tags: map[string]string{
				"title":       "Unhappy Refrain",
				"artist":      "wowaka",
				"album":       "Unhappy Refrain",
				"albumartist": "wowaka",
				"track":       "4/14",
				"year":        "2011",
				"disc":        "3/5",
			},
			wantTitle:       "Unhappy Refrain",
			wantArtists:     "wowaka",
			wantAlbum:       "Unhappy Refrain",
			wantTrack:       4,
			wantAlbumArtist: "wowaka",
			wantYear:        2011,
			wantDisc:        3,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			tmpDir := t.TempDir()
			restoreSeams := stubScannerSeams()
			defer restoreSeams()

			audioDir := filepath.Join(tmpDir, "artist-folder", "album-folder")
			if err := os.MkdirAll(audioDir, 0o755); err != nil {
				t.Fatalf("mkdir audio dir: %v", err)
			}
			slug := strings.ReplaceAll(tc.name, " ", "-")
			audioPath := filepath.Join(audioDir, slug+".wav")
			if err := os.WriteFile(audioPath, []byte("not a real wav"), 0o644); err != nil {
				t.Fatalf("write audio file: %v", err)
			}

			ffprobeRunner = func(path string) (int, string, map[string]string) {
				if path != audioPath {
					t.Fatalf("ffprobe path = %q, want %q", path, audioPath)
				}
				return 123, "16bit PCM_S16LE", tc.tags
			}
			metadataReader = func(path string) (tag.Metadata, error) {
				if path != audioPath {
					t.Fatalf("metadataReader path = %q, want %q", path, audioPath)
				}
				return fakeMetadata{}, nil
			}
			embeddedPictureReader = func(path string) (*tag.Picture, error) {
				if path != audioPath {
					t.Fatalf("embeddedPictureReader path = %q, want %q", path, audioPath)
				}
				return nil, nil
			}
			wavCoverExtractor = func(gotAudioPath, gotAlbumDir string) string {
				if gotAudioPath != audioPath {
					t.Fatalf("wavCoverExtractor audioPath = %q, want %q", gotAudioPath, audioPath)
				}
				if gotAlbumDir != audioDir {
					t.Fatalf("wavCoverExtractor albumDir = %q, want %q", gotAlbumDir, audioDir)
				}
				return ""
			}
			videoThumbFinder = func(path string) string {
				t.Fatalf("videoThumbFinder should not be called, got %q", path)
				return ""
			}

			result := processFile(scanJob{audioPath: audioPath}, tmpDir)

			if result.track.Title != tc.wantTitle {
				t.Fatalf("title = %q, want %q", result.track.Title, tc.wantTitle)
			}
			if result.track.Artists != tc.wantArtists {
				t.Fatalf("artists = %q, want %q", result.track.Artists, tc.wantArtists)
			}
			if result.album.Title != tc.wantAlbum {
				t.Fatalf("album title = %q, want %q", result.album.Title, tc.wantAlbum)
			}
			if result.track.TrackNumber != tc.wantTrack {
				t.Fatalf("track number = %d, want %d", result.track.TrackNumber, tc.wantTrack)
			}
			if result.album.AlbumArtist != tc.wantAlbumArtist {
				t.Fatalf("album artist = %q, want %q", result.album.AlbumArtist, tc.wantAlbumArtist)
			}
			if result.producer.Name != tc.wantAlbumArtist {
				t.Fatalf("producer name = %q, want %q", result.producer.Name, tc.wantAlbumArtist)
			}
			if result.track.Year != tc.wantYear {
				t.Fatalf("year = %d, want %d", result.track.Year, tc.wantYear)
			}
			if result.track.DiscNumber != tc.wantDisc {
				t.Fatalf("disc number = %d, want %d", result.track.DiscNumber, tc.wantDisc)
			}
		})
	}
}

func TestExtractCoverFromTrackFallsBackForWAV(t *testing.T) {
	albumDir := t.TempDir()
	audioPath := filepath.Join(albumDir, "coverless.wav")
	if err := os.WriteFile(audioPath, []byte("RIFF"), 0o644); err != nil {
		t.Fatal(err)
	}

	restorePictureReader := embeddedPictureReader
	restoreWAVFallback := wavCoverExtractor
	t.Cleanup(func() {
		embeddedPictureReader = restorePictureReader
		wavCoverExtractor = restoreWAVFallback
	})

	embeddedPictureReader = func(string) (*tag.Picture, error) {
		return nil, nil
	}
	wavCoverExtractor = func(audioPath, albumDir string) string {
		out := filepath.Join(albumDir, "extracted_cover.png")
		if err := os.WriteFile(out, []byte("png"), 0o644); err != nil {
			t.Fatal(err)
		}
		return out
	}

	got := extractCoverFromTrack(audioPath, albumDir)
	want := filepath.Join(albumDir, "extracted_cover.png")
	if got != want {
		t.Fatalf("cover path = %q, want %q", got, want)
	}
}

func TestProcessFileUsesExistingCoverPNG(t *testing.T) {
	tmpDir := t.TempDir()
	restoreSeams := stubScannerSeams()
	defer restoreSeams()

	albumDir := filepath.Join(tmpDir, "artist-folder", "album-folder")
	if err := os.MkdirAll(albumDir, 0o755); err != nil {
		t.Fatalf("mkdir album dir: %v", err)
	}
	audioPath := filepath.Join(albumDir, "track.flac")
	if err := os.WriteFile(audioPath, []byte("fLaC"), 0o644); err != nil {
		t.Fatalf("write audio file: %v", err)
	}
	coverPath := filepath.Join(albumDir, "cover.png")
	if err := os.WriteFile(coverPath, []byte("png"), 0o644); err != nil {
		t.Fatalf("write cover file: %v", err)
	}

	ffprobeRunner = func(path string) (int, string, map[string]string) {
		if path != audioPath {
			t.Fatalf("ffprobe path = %q, want %q", path, audioPath)
		}
		return 180, "FLAC", map[string]string{
			"title": "Track",
			"album": "Album",
		}
	}
	metadataReader = func(path string) (tag.Metadata, error) {
		if path != audioPath {
			t.Fatalf("metadataReader path = %q, want %q", path, audioPath)
		}
		return fakeMetadata{}, nil
	}
	embeddedPictureReader = func(path string) (*tag.Picture, error) {
		t.Fatalf("embeddedPictureReader should not be called when directory cover exists, got %q", path)
		return nil, nil
	}
	wavCoverExtractor = func(audioPath, albumDir string) string {
		t.Fatalf("wavCoverExtractor should not be called for existing directory cover, got audioPath=%q albumDir=%q", audioPath, albumDir)
		return ""
	}
	videoThumbFinder = func(path string) string {
		t.Fatalf("videoThumbFinder should not be called, got %q", path)
		return ""
	}

	result := processFile(scanJob{audioPath: audioPath}, tmpDir)

	if result.album.CoverPath != coverPath {
		t.Fatalf("cover path = %q, want %q", result.album.CoverPath, coverPath)
	}
}

func TestProcessFileRefreshesStaleCrossFormatExtractedCoverForWAV(t *testing.T) {
	tmpDir := t.TempDir()
	restoreSeams := stubScannerSeams()
	defer restoreSeams()

	albumDir := filepath.Join(tmpDir, "artist-folder", "album-folder")
	if err := os.MkdirAll(albumDir, 0o755); err != nil {
		t.Fatalf("mkdir album dir: %v", err)
	}
	audioPath := filepath.Join(albumDir, "coverless.wav")
	if err := os.WriteFile(audioPath, []byte("RIFF"), 0o644); err != nil {
		t.Fatalf("write audio file: %v", err)
	}

	staleJPGPath := filepath.Join(albumDir, "extracted_cover.jpg")
	if err := os.WriteFile(staleJPGPath, []byte("stale-jpg"), 0o644); err != nil {
		t.Fatalf("seed stale jpg: %v", err)
	}

	ffprobeRunner = func(path string) (int, string, map[string]string) {
		if path != audioPath {
			t.Fatalf("ffprobe path = %q, want %q", path, audioPath)
		}
		return 0, "", nil
	}
	metadataReader = func(path string) (tag.Metadata, error) {
		if path != audioPath {
			t.Fatalf("metadataReader path = %q, want %q", path, audioPath)
		}
		return fakeMetadata{}, nil
	}
	embeddedPictureReader = func(path string) (*tag.Picture, error) {
		if path != audioPath {
			t.Fatalf("embeddedPictureReader path = %q, want %q", path, audioPath)
		}
		return nil, nil
	}
	wavCoverExtractor = func(gotAudioPath, gotAlbumDir string) string {
		if gotAudioPath != audioPath {
			t.Fatalf("wavCoverExtractor audioPath = %q, want %q", gotAudioPath, audioPath)
		}
		if gotAlbumDir != albumDir {
			t.Fatalf("wavCoverExtractor albumDir = %q, want %q", gotAlbumDir, albumDir)
		}
		outPath := filepath.Join(albumDir, "extracted_cover.png")
		if err := os.WriteFile(outPath, []byte("fresh-png"), 0o644); err != nil {
			t.Fatalf("write refreshed png: %v", err)
		}
		return outPath
	}
	videoThumbFinder = func(path string) string {
		t.Fatalf("videoThumbFinder should not be called, got %q", path)
		return ""
	}

	result := processFile(scanJob{audioPath: audioPath}, tmpDir)

	wantCoverPath := filepath.Join(albumDir, "extracted_cover.png")
	if result.album.CoverPath != wantCoverPath {
		t.Fatalf("cover path = %q, want %q", result.album.CoverPath, wantCoverPath)
	}
	if _, err := os.Stat(staleJPGPath); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("expected stale jpg to be removed, stat err = %v", err)
	}
	if _, err := os.Stat(wantCoverPath); err != nil {
		t.Fatalf("expected refreshed png to exist: %v", err)
	}
}

func TestProcessFilePreservesExistingExtractedCoverWhenRefreshReplacementFails(t *testing.T) {
	tmpDir := t.TempDir()
	restoreSeams := stubScannerSeams()
	defer restoreSeams()

	albumDir := filepath.Join(tmpDir, "artist-folder", "album-folder")
	if err := os.MkdirAll(albumDir, 0o755); err != nil {
		t.Fatalf("mkdir album dir: %v", err)
	}
	audioPath := filepath.Join(albumDir, "coverless.wav")
	if err := os.WriteFile(audioPath, []byte("RIFF"), 0o644); err != nil {
		t.Fatalf("write audio file: %v", err)
	}

	existingCoverPath := filepath.Join(albumDir, "extracted_cover.jpg")
	existingCoverData := []byte("existing-jpg")
	if err := os.WriteFile(existingCoverPath, existingCoverData, 0o644); err != nil {
		t.Fatalf("seed existing extracted cover: %v", err)
	}

	ffprobeRunner = func(path string) (int, string, map[string]string) {
		if path != audioPath {
			t.Fatalf("ffprobe path = %q, want %q", path, audioPath)
		}
		return 0, "", nil
	}
	metadataReader = func(path string) (tag.Metadata, error) {
		if path != audioPath {
			t.Fatalf("metadataReader path = %q, want %q", path, audioPath)
		}
		return fakeMetadata{}, nil
	}

	embeddedReads := 0
	embeddedPictureReader = func(path string) (*tag.Picture, error) {
		embeddedReads++
		if path != audioPath {
			t.Fatalf("embeddedPictureReader path = %q, want %q", path, audioPath)
		}
		return &tag.Picture{Ext: "png", Data: []byte("replacement-png")}, nil
	}
	wavFallbackCalls := 0
	wavCoverExtractor = func(gotAudioPath, gotAlbumDir string) string {
		wavFallbackCalls++
		t.Fatalf("wavCoverExtractor should not be called when embedded art exists; got audioPath=%q albumDir=%q", gotAudioPath, gotAlbumDir)
		return ""
	}
	videoThumbFinder = func(path string) string {
		t.Fatalf("videoThumbFinder should not be called, got %q", path)
		return ""
	}

	if err := os.Chmod(albumDir, 0o555); err != nil {
		t.Fatalf("chmod album dir read-only: %v", err)
	}
	t.Cleanup(func() {
		_ = os.Chmod(albumDir, 0o755)
	})

	result := processFile(scanJob{audioPath: audioPath}, tmpDir)

	if result.album.CoverPath != existingCoverPath {
		t.Fatalf("cover path = %q, want preserved existing path %q", result.album.CoverPath, existingCoverPath)
	}
	if embeddedReads != 1 {
		t.Fatalf("embeddedPictureReader calls = %d, want %d", embeddedReads, 1)
	}
	if wavFallbackCalls != 0 {
		t.Fatalf("wavCoverExtractor calls = %d, want %d", wavFallbackCalls, 0)
	}
	data, err := os.ReadFile(existingCoverPath)
	if err != nil {
		t.Fatalf("read existing cover after failed refresh: %v", err)
	}
	if string(data) != string(existingCoverData) {
		t.Fatalf("existing cover data = %q, want %q", string(data), string(existingCoverData))
	}
}

func TestProcessFileAvoidsDuplicateRefreshAttemptsWhenWAVRefreshFails(t *testing.T) {
	tmpDir := t.TempDir()
	restoreSeams := stubScannerSeams()
	defer restoreSeams()

	albumDir := filepath.Join(tmpDir, "artist-folder", "album-folder")
	if err := os.MkdirAll(albumDir, 0o755); err != nil {
		t.Fatalf("mkdir album dir: %v", err)
	}
	audioPath := filepath.Join(albumDir, "coverless.wav")
	if err := os.WriteFile(audioPath, []byte("RIFF"), 0o644); err != nil {
		t.Fatalf("write audio file: %v", err)
	}

	existingCoverPath := filepath.Join(albumDir, "extracted_cover.png")
	existingCoverData := []byte("existing-png")
	if err := os.WriteFile(existingCoverPath, existingCoverData, 0o644); err != nil {
		t.Fatalf("seed existing extracted cover: %v", err)
	}

	ffprobeRunner = func(path string) (int, string, map[string]string) {
		if path != audioPath {
			t.Fatalf("ffprobe path = %q, want %q", path, audioPath)
		}
		return 0, "", nil
	}
	metadataReader = func(path string) (tag.Metadata, error) {
		if path != audioPath {
			t.Fatalf("metadataReader path = %q, want %q", path, audioPath)
		}
		return fakeMetadata{}, nil
	}

	embeddedReads := 0
	embeddedPictureReader = func(path string) (*tag.Picture, error) {
		embeddedReads++
		if path != audioPath {
			t.Fatalf("embeddedPictureReader path = %q, want %q", path, audioPath)
		}
		return nil, nil
	}
	wavFallbackCalls := 0
	wavCoverExtractor = func(gotAudioPath, gotAlbumDir string) string {
		wavFallbackCalls++
		if gotAudioPath != audioPath {
			t.Fatalf("wavCoverExtractor audioPath = %q, want %q", gotAudioPath, audioPath)
		}
		if gotAlbumDir != albumDir {
			t.Fatalf("wavCoverExtractor albumDir = %q, want %q", gotAlbumDir, albumDir)
		}
		return ""
	}
	videoThumbFinder = func(path string) string {
		t.Fatalf("videoThumbFinder should not be called, got %q", path)
		return ""
	}

	result := processFile(scanJob{audioPath: audioPath}, tmpDir)

	if result.album.CoverPath != existingCoverPath {
		t.Fatalf("cover path = %q, want preserved existing path %q", result.album.CoverPath, existingCoverPath)
	}
	if embeddedReads != 1 {
		t.Fatalf("embeddedPictureReader calls = %d, want %d", embeddedReads, 1)
	}
	if wavFallbackCalls != 1 {
		t.Fatalf("wavCoverExtractor calls = %d, want %d", wavFallbackCalls, 1)
	}
	data, err := os.ReadFile(existingCoverPath)
	if err != nil {
		t.Fatalf("read existing cover after failed wav refresh: %v", err)
	}
	if string(data) != string(existingCoverData) {
		t.Fatalf("existing cover data = %q, want %q", string(data), string(existingCoverData))
	}
}

func TestProcessFileWithAlbumCoverCoordinatorAttemptsFailedWAVRefreshOncePerAlbum(t *testing.T) {
	tmpDir := t.TempDir()
	restoreSeams := stubScannerSeams()
	defer restoreSeams()

	albumDir := filepath.Join(tmpDir, "artist-folder", "album-folder")
	if err := os.MkdirAll(albumDir, 0o755); err != nil {
		t.Fatalf("mkdir album dir: %v", err)
	}
	audioPaths := []string{
		filepath.Join(albumDir, "track-01.wav"),
		filepath.Join(albumDir, "track-02.wav"),
	}
	for _, audioPath := range audioPaths {
		if err := os.WriteFile(audioPath, []byte("RIFF"), 0o644); err != nil {
			t.Fatalf("write audio file %q: %v", audioPath, err)
		}
	}

	existingCoverPath := filepath.Join(albumDir, "extracted_cover.png")
	existingCoverData := []byte("existing-png")
	if err := os.WriteFile(existingCoverPath, existingCoverData, 0o644); err != nil {
		t.Fatalf("seed existing extracted cover: %v", err)
	}

	ffprobeRunner = func(path string) (int, string, map[string]string) {
		for _, audioPath := range audioPaths {
			if path == audioPath {
				return 0, "", nil
			}
		}
		t.Fatalf("unexpected ffprobe path %q", path)
		return 0, "", nil
	}
	metadataReader = func(path string) (tag.Metadata, error) {
		for _, audioPath := range audioPaths {
			if path == audioPath {
				return fakeMetadata{}, nil
			}
		}
		t.Fatalf("unexpected metadataReader path %q", path)
		return nil, nil
	}
	embeddedReads := []string{}
	embeddedPictureReader = func(path string) (*tag.Picture, error) {
		embeddedReads = append(embeddedReads, filepath.Base(path))
		for _, audioPath := range audioPaths {
			if path == audioPath {
				return nil, nil
			}
		}
		t.Fatalf("unexpected embeddedPictureReader path %q", path)
		return nil, nil
	}

	var (
		wavFallbackMu    sync.Mutex
		wavFallbackCalls int
		firstFallback    = make(chan struct{})
		releaseFallback  = make(chan struct{})
	)
	wavCoverExtractor = func(gotAudioPath, gotAlbumDir string) string {
		if gotAlbumDir != albumDir {
			t.Fatalf("wavCoverExtractor albumDir = %q, want %q", gotAlbumDir, albumDir)
		}
		found := false
		for _, audioPath := range audioPaths {
			if gotAudioPath == audioPath {
				found = true
				break
			}
		}
		if !found {
			t.Fatalf("unexpected wavCoverExtractor audioPath %q", gotAudioPath)
		}

		wavFallbackMu.Lock()
		wavFallbackCalls++
		callNumber := wavFallbackCalls
		wavFallbackMu.Unlock()

		if callNumber == 1 {
			close(firstFallback)
			<-releaseFallback
		}
		return ""
	}
	videoThumbFinder = func(path string) string {
		t.Fatalf("videoThumbFinder should not be called, got %q", path)
		return ""
	}

	coordinator := newAlbumCoverCoordinator()
	results := make(chan scanResult, len(audioPaths))
	start := make(chan struct{})
	var wg sync.WaitGroup
	for _, audioPath := range audioPaths {
		wg.Add(1)
		go func(audioPath string) {
			defer wg.Done()
			<-start
			results <- processFileWithAlbumCoverCoordinator(scanJob{audioPath: audioPath}, tmpDir, coordinator)
		}(audioPath)
	}

	close(start)
	<-firstFallback
	close(releaseFallback)
	wg.Wait()
	close(results)

	gotCoverPaths := map[string]int{}
	for result := range results {
		gotCoverPaths[result.album.CoverPath]++
	}

	if wavFallbackCalls != 1 {
		t.Fatalf("wavCoverExtractor calls = %d, want %d", wavFallbackCalls, 1)
	}
	if !reflect.DeepEqual(embeddedReads, []string{"track-01.wav", "track-02.wav"}) {
		t.Fatalf("embedded reads = %#v, want deterministic album order", embeddedReads)
	}
	if !reflect.DeepEqual(gotCoverPaths, map[string]int{existingCoverPath: len(audioPaths)}) {
		t.Fatalf("cover paths = %#v, want all tracks to reuse %q", gotCoverPaths, existingCoverPath)
	}
	data, err := os.ReadFile(existingCoverPath)
	if err != nil {
		t.Fatalf("read existing cover after shared refresh failure: %v", err)
	}
	if string(data) != string(existingCoverData) {
		t.Fatalf("existing cover data = %q, want %q", string(data), string(existingCoverData))
	}
}

func TestProcessFileWithAlbumCoverCoordinatorUsesDeterministicAlbumWAVCoverSource(t *testing.T) {
	for _, tc := range []struct {
		name        string
		firstTrack  string
		secondTrack string
	}{
		{
			name:        "no-art track enters first",
			firstTrack:  "track-01.wav",
			secondTrack: "track-02.wav",
		},
		{
			name:        "art track enters first",
			firstTrack:  "track-02.wav",
			secondTrack: "track-01.wav",
		},
	} {
		t.Run(tc.name, func(t *testing.T) {
			tmpDir := t.TempDir()
			restoreSeams := stubScannerSeams()
			defer restoreSeams()

			albumDir := filepath.Join(tmpDir, "artist-folder", "album-folder")
			if err := os.MkdirAll(albumDir, 0o755); err != nil {
				t.Fatalf("mkdir album dir: %v", err)
			}
			trackPaths := map[string]string{
				"track-01.wav": filepath.Join(albumDir, "track-01.wav"),
				"track-02.wav": filepath.Join(albumDir, "track-02.wav"),
			}
			for _, audioPath := range trackPaths {
				if err := os.WriteFile(audioPath, []byte("RIFF"), 0o644); err != nil {
					t.Fatalf("write audio file %q: %v", audioPath, err)
				}
			}

			ffprobeRunner = func(path string) (int, string, map[string]string) {
				for _, audioPath := range trackPaths {
					if path == audioPath {
						return 0, "", nil
					}
				}
				t.Fatalf("unexpected ffprobe path %q", path)
				return 0, "", nil
			}
			metadataReader = func(path string) (tag.Metadata, error) {
				for _, audioPath := range trackPaths {
					if path == audioPath {
						return fakeMetadata{}, nil
					}
				}
				t.Fatalf("unexpected metadataReader path %q", path)
				return nil, nil
			}

			embeddedReads := []string{}
			embeddedPictureReader = func(path string) (*tag.Picture, error) {
				embeddedReads = append(embeddedReads, filepath.Base(path))
				switch filepath.Base(path) {
				case "track-01.wav":
					return nil, nil
				case "track-02.wav":
					return &tag.Picture{Ext: "jpg", Data: []byte("album-art")}, nil
				default:
					t.Fatalf("unexpected embeddedPictureReader path %q", path)
					return nil, nil
				}
			}

			wavFallbackCalls := 0
			wavCoverExtractor = func(gotAudioPath, gotAlbumDir string) string {
				wavFallbackCalls++
				t.Fatalf("wavCoverExtractor should not be called when album has usable embedded art; got audioPath=%q albumDir=%q", gotAudioPath, gotAlbumDir)
				return ""
			}
			videoThumbFinder = func(path string) string {
				t.Fatalf("videoThumbFinder should not be called, got %q", path)
				return ""
			}

			coordinator := newAlbumCoverCoordinator()
			first := processFileWithAlbumCoverCoordinator(scanJob{audioPath: trackPaths[tc.firstTrack]}, tmpDir, coordinator)
			second := processFileWithAlbumCoverCoordinator(scanJob{audioPath: trackPaths[tc.secondTrack]}, tmpDir, coordinator)

			wantCoverPath := filepath.Join(albumDir, "extracted_cover.jpg")
			if first.album.CoverPath != wantCoverPath {
				t.Fatalf("first cover path = %q, want %q", first.album.CoverPath, wantCoverPath)
			}
			if second.album.CoverPath != wantCoverPath {
				t.Fatalf("second cover path = %q, want %q", second.album.CoverPath, wantCoverPath)
			}
			if wavFallbackCalls != 0 {
				t.Fatalf("wavCoverExtractor calls = %d, want %d", wavFallbackCalls, 0)
			}
			if !reflect.DeepEqual(embeddedReads, []string{"track-01.wav", "track-02.wav"}) {
				t.Fatalf("embedded reads = %#v, want deterministic album order", embeddedReads)
			}
			data, err := os.ReadFile(wantCoverPath)
			if err != nil {
				t.Fatalf("read deterministic extracted cover: %v", err)
			}
			if string(data) != "album-art" {
				t.Fatalf("cover data = %q, want %q", string(data), "album-art")
			}
		})
	}
}

func TestProcessFileWithAlbumCoverCoordinatorUsesDeterministicMixedFormatAlbumCoverSource(t *testing.T) {
	for _, tc := range []struct {
		name        string
		firstTrack  string
		secondTrack string
	}{
		{
			name:        "wav caller enters first",
			firstTrack:  "track-02.wav",
			secondTrack: "track-01.mp3",
		},
		{
			name:        "mp3 caller enters first",
			firstTrack:  "track-01.mp3",
			secondTrack: "track-02.wav",
		},
	} {
		t.Run(tc.name, func(t *testing.T) {
			tmpDir := t.TempDir()
			restoreSeams := stubScannerSeams()
			defer restoreSeams()

			albumDir := filepath.Join(tmpDir, "artist-folder", "album-folder")
			if err := os.MkdirAll(albumDir, 0o755); err != nil {
				t.Fatalf("mkdir album dir: %v", err)
			}

			trackPaths := map[string]string{
				"track-01.mp3": filepath.Join(albumDir, "track-01.mp3"),
				"track-02.wav": filepath.Join(albumDir, "track-02.wav"),
			}
			for _, audioPath := range trackPaths {
				if err := os.WriteFile(audioPath, []byte("audio"), 0o644); err != nil {
					t.Fatalf("write audio file %q: %v", audioPath, err)
				}
			}

			ffprobeRunner = func(path string) (int, string, map[string]string) {
				for _, audioPath := range trackPaths {
					if path == audioPath {
						return 0, "", nil
					}
				}
				t.Fatalf("unexpected ffprobe path %q", path)
				return 0, "", nil
			}
			metadataReader = func(path string) (tag.Metadata, error) {
				for _, audioPath := range trackPaths {
					if path == audioPath {
						return fakeMetadata{}, nil
					}
				}
				t.Fatalf("unexpected metadataReader path %q", path)
				return nil, nil
			}

			var embeddedReadsMu sync.Mutex
			embeddedReads := []string{}
			embeddedPictureReader = func(path string) (*tag.Picture, error) {
				base := filepath.Base(path)

				embeddedReadsMu.Lock()
				embeddedReads = append(embeddedReads, base)
				embeddedReadsMu.Unlock()

				switch base {
				case "track-01.mp3":
					return &tag.Picture{Ext: "jpg", Data: []byte("mp3-art")}, nil
				case "track-02.wav":
					return nil, nil
				default:
					t.Fatalf("unexpected embeddedPictureReader path %q", path)
					return nil, nil
				}
			}

			var (
				wavFallbackMu    sync.Mutex
				wavFallbackCalls int
			)
			wavCoverExtractor = func(gotAudioPath, gotAlbumDir string) string {
				if gotAudioPath != trackPaths["track-02.wav"] {
					t.Fatalf("wavCoverExtractor audioPath = %q, want %q", gotAudioPath, trackPaths["track-02.wav"])
				}
				if gotAlbumDir != albumDir {
					t.Fatalf("wavCoverExtractor albumDir = %q, want %q", gotAlbumDir, albumDir)
				}

				wavFallbackMu.Lock()
				wavFallbackCalls++
				wavFallbackMu.Unlock()

				outPath := filepath.Join(albumDir, "extracted_cover.png")
				if err := os.WriteFile(outPath, []byte("wav-fallback-art"), 0o644); err != nil {
					t.Fatalf("write wav fallback cover: %v", err)
				}
				return outPath
			}
			videoThumbFinder = func(path string) string {
				t.Fatalf("videoThumbFinder should not be called, got %q", path)
				return ""
			}

			coordinator := newAlbumCoverCoordinator()
			gotResults := map[string]scanResult{
				tc.firstTrack: processFileWithAlbumCoverCoordinator(
					scanJob{audioPath: trackPaths[tc.firstTrack]},
					tmpDir,
					coordinator,
				),
				tc.secondTrack: processFileWithAlbumCoverCoordinator(
					scanJob{audioPath: trackPaths[tc.secondTrack]},
					tmpDir,
					coordinator,
				),
			}

			wantCoverPath := filepath.Join(albumDir, "extracted_cover.jpg")
			for track, result := range gotResults {
				if result.album.CoverPath != wantCoverPath {
					t.Fatalf("%s cover path = %q, want %q", track, result.album.CoverPath, wantCoverPath)
				}
			}

			wavFallbackMu.Lock()
			gotWAVFallbackCalls := wavFallbackCalls
			wavFallbackMu.Unlock()
			if gotWAVFallbackCalls != 0 {
				t.Fatalf("wavCoverExtractor calls = %d, want %d", gotWAVFallbackCalls, 0)
			}

			if gotCoverPath := findCoverInDir(albumDir); gotCoverPath != wantCoverPath {
				t.Fatalf("persisted cover path = %q, want %q", gotCoverPath, wantCoverPath)
			}
			data, err := os.ReadFile(wantCoverPath)
			if err != nil {
				t.Fatalf("read deterministic mixed-format cover: %v", err)
			}
			if string(data) != "mp3-art" {
				t.Fatalf("cover data = %q, want %q", string(data), "mp3-art")
			}

			embeddedReadsMu.Lock()
			gotEmbeddedReads := append([]string(nil), embeddedReads...)
			embeddedReadsMu.Unlock()
			if !reflect.DeepEqual(gotEmbeddedReads, []string{"track-01.mp3"}) {
				t.Fatalf("embedded reads = %#v, want deterministic album order", gotEmbeddedReads)
			}
		})
	}
}

func TestProcessFileWithAlbumCoverCoordinatorAllowsWAVFallbackAfterNonWAVReadError(t *testing.T) {
	tmpDir := t.TempDir()
	restoreSeams := stubScannerSeams()
	defer restoreSeams()

	albumDir := filepath.Join(tmpDir, "artist-folder", "album-folder")
	if err := os.MkdirAll(albumDir, 0o755); err != nil {
		t.Fatalf("mkdir album dir: %v", err)
	}

	trackPaths := map[string]string{
		"track-01.mp3": filepath.Join(albumDir, "track-01.mp3"),
		"track-02.wav": filepath.Join(albumDir, "track-02.wav"),
	}
	for _, audioPath := range trackPaths {
		if err := os.WriteFile(audioPath, []byte("audio"), 0o644); err != nil {
			t.Fatalf("write audio file %q: %v", audioPath, err)
		}
	}

	ffprobeRunner = func(path string) (int, string, map[string]string) {
		for _, audioPath := range trackPaths {
			if path == audioPath {
				return 0, "", nil
			}
		}
		t.Fatalf("unexpected ffprobe path %q", path)
		return 0, "", nil
	}
	metadataReader = func(path string) (tag.Metadata, error) {
		for _, audioPath := range trackPaths {
			if path == audioPath {
				return fakeMetadata{}, nil
			}
		}
		t.Fatalf("unexpected metadataReader path %q", path)
		return nil, nil
	}

	embeddedReads := []string{}
	embeddedPictureReader = func(path string) (*tag.Picture, error) {
		embeddedReads = append(embeddedReads, filepath.Base(path))
		switch filepath.Base(path) {
		case "track-01.mp3":
			return nil, errors.New("mp3 embedded art read failed")
		case "track-02.wav":
			return nil, nil
		default:
			t.Fatalf("unexpected embeddedPictureReader path %q", path)
			return nil, nil
		}
	}

	wavFallbackCalls := 0
	wavCoverExtractor = func(gotAudioPath, gotAlbumDir string) string {
		wavFallbackCalls++
		if gotAudioPath != trackPaths["track-02.wav"] {
			t.Fatalf("wavCoverExtractor audioPath = %q, want %q", gotAudioPath, trackPaths["track-02.wav"])
		}
		if gotAlbumDir != albumDir {
			t.Fatalf("wavCoverExtractor albumDir = %q, want %q", gotAlbumDir, albumDir)
		}

		outPath := filepath.Join(albumDir, "extracted_cover.png")
		if err := os.WriteFile(outPath, []byte("wav-fallback-art"), 0o644); err != nil {
			t.Fatalf("write wav fallback cover: %v", err)
		}
		return outPath
	}
	videoThumbFinder = func(path string) string {
		t.Fatalf("videoThumbFinder should not be called, got %q", path)
		return ""
	}

	coordinator := newAlbumCoverCoordinator()
	mp3Result := processFileWithAlbumCoverCoordinator(scanJob{audioPath: trackPaths["track-01.mp3"]}, tmpDir, coordinator)
	wavResult := processFileWithAlbumCoverCoordinator(scanJob{audioPath: trackPaths["track-02.wav"]}, tmpDir, coordinator)

	wantCoverPath := filepath.Join(albumDir, "extracted_cover.png")
	if mp3Result.album.CoverPath != wantCoverPath {
		t.Fatalf("mp3 cover path = %q, want %q", mp3Result.album.CoverPath, wantCoverPath)
	}
	if wavResult.album.CoverPath != wantCoverPath {
		t.Fatalf("wav cover path = %q, want %q", wavResult.album.CoverPath, wantCoverPath)
	}
	if wavFallbackCalls != 1 {
		t.Fatalf("wavCoverExtractor calls = %d, want %d", wavFallbackCalls, 1)
	}
	if !reflect.DeepEqual(embeddedReads, []string{"track-01.mp3", "track-02.wav"}) {
		t.Fatalf("embedded reads = %#v, want deterministic album order", embeddedReads)
	}
	data, err := os.ReadFile(wantCoverPath)
	if err != nil {
		t.Fatalf("read wav fallback cover: %v", err)
	}
	if string(data) != "wav-fallback-art" {
		t.Fatalf("cover data = %q, want %q", string(data), "wav-fallback-art")
	}
}

func TestProcessFileWithAlbumCoverCoordinatorAllowsWAVFallbackAfterWAVReadError(t *testing.T) {
	tmpDir := t.TempDir()
	restoreSeams := stubScannerSeams()
	defer restoreSeams()

	albumDir := filepath.Join(tmpDir, "artist-folder", "album-folder")
	if err := os.MkdirAll(albumDir, 0o755); err != nil {
		t.Fatalf("mkdir album dir: %v", err)
	}

	trackPaths := map[string]string{
		"track-01.wav": filepath.Join(albumDir, "track-01.wav"),
		"track-02.wav": filepath.Join(albumDir, "track-02.wav"),
	}
	for _, audioPath := range trackPaths {
		if err := os.WriteFile(audioPath, []byte("audio"), 0o644); err != nil {
			t.Fatalf("write audio file %q: %v", audioPath, err)
		}
	}

	ffprobeRunner = func(path string) (int, string, map[string]string) {
		for _, audioPath := range trackPaths {
			if path == audioPath {
				return 0, "", nil
			}
		}
		t.Fatalf("unexpected ffprobe path %q", path)
		return 0, "", nil
	}
	metadataReader = func(path string) (tag.Metadata, error) {
		for _, audioPath := range trackPaths {
			if path == audioPath {
				return fakeMetadata{}, nil
			}
		}
		t.Fatalf("unexpected metadataReader path %q", path)
		return nil, nil
	}

	embeddedReads := []string{}
	embeddedPictureReader = func(path string) (*tag.Picture, error) {
		embeddedReads = append(embeddedReads, filepath.Base(path))
		switch filepath.Base(path) {
		case "track-01.wav", "track-02.wav":
			return nil, errors.New("wav embedded art read failed")
		default:
			t.Fatalf("unexpected embeddedPictureReader path %q", path)
			return nil, nil
		}
	}

	wavFallbackCalls := 0
	wavCoverExtractor = func(gotAudioPath, gotAlbumDir string) string {
		wavFallbackCalls++
		if gotAudioPath != trackPaths["track-01.wav"] {
			t.Fatalf("wavCoverExtractor audioPath = %q, want %q", gotAudioPath, trackPaths["track-01.wav"])
		}
		if gotAlbumDir != albumDir {
			t.Fatalf("wavCoverExtractor albumDir = %q, want %q", gotAlbumDir, albumDir)
		}

		outPath := filepath.Join(albumDir, "extracted_cover.png")
		if err := os.WriteFile(outPath, []byte("wav-read-error-fallback-art"), 0o644); err != nil {
			t.Fatalf("write wav fallback cover: %v", err)
		}
		return outPath
	}
	videoThumbFinder = func(path string) string {
		t.Fatalf("videoThumbFinder should not be called, got %q", path)
		return ""
	}

	coordinator := newAlbumCoverCoordinator()
	firstResult := processFileWithAlbumCoverCoordinator(scanJob{audioPath: trackPaths["track-01.wav"]}, tmpDir, coordinator)
	secondResult := processFileWithAlbumCoverCoordinator(scanJob{audioPath: trackPaths["track-02.wav"]}, tmpDir, coordinator)

	wantCoverPath := filepath.Join(albumDir, "extracted_cover.png")
	if firstResult.album.CoverPath != wantCoverPath {
		t.Fatalf("first wav cover path = %q, want %q", firstResult.album.CoverPath, wantCoverPath)
	}
	if secondResult.album.CoverPath != wantCoverPath {
		t.Fatalf("second wav cover path = %q, want %q", secondResult.album.CoverPath, wantCoverPath)
	}
	if wavFallbackCalls != 1 {
		t.Fatalf("wavCoverExtractor calls = %d, want %d", wavFallbackCalls, 1)
	}
	if !reflect.DeepEqual(embeddedReads, []string{"track-01.wav", "track-02.wav"}) {
		t.Fatalf("embedded reads = %#v, want deterministic album order", embeddedReads)
	}
	data, err := os.ReadFile(wantCoverPath)
	if err != nil {
		t.Fatalf("read wav fallback cover: %v", err)
	}
	if string(data) != "wav-read-error-fallback-art" {
		t.Fatalf("cover data = %q, want %q", string(data), "wav-read-error-fallback-art")
	}
}

func TestExtractCoverFromTrackDoesNotFallBackWhenEmbeddedArtReadFails(t *testing.T) {
	albumDir := t.TempDir()
	audioPath := filepath.Join(albumDir, "cover-error.wav")
	if err := os.WriteFile(audioPath, []byte("RIFF"), 0o644); err != nil {
		t.Fatal(err)
	}

	restorePictureReader := embeddedPictureReader
	restoreWAVFallback := wavCoverExtractor
	t.Cleanup(func() {
		embeddedPictureReader = restorePictureReader
		wavCoverExtractor = restoreWAVFallback
	})

	embeddedPictureReader = func(gotPath string) (*tag.Picture, error) {
		if gotPath != audioPath {
			t.Fatalf("audio path = %q, want %q", gotPath, audioPath)
		}
		return nil, errors.New("embedded art read failed")
	}
	wavFallbackCalled := false
	wavCoverExtractor = func(gotAudioPath, gotAlbumDir string) string {
		wavFallbackCalled = true
		t.Fatalf("wav fallback should not be called when embedded art read fails; got audioPath=%q albumDir=%q", gotAudioPath, gotAlbumDir)
		return ""
	}

	got := extractCoverFromTrack(audioPath, albumDir)

	if got != "" {
		t.Fatalf("cover path = %q, want empty path after embedded art read failure", got)
	}
	if wavFallbackCalled {
		t.Fatal("wav fallback was called")
	}
}

func TestExtractCoverFromTrackDoesNotFallBackWhenEmbeddedArtWriteFails(t *testing.T) {
	baseDir := t.TempDir()
	albumDir := filepath.Join(baseDir, "missing-album-dir")
	audioPath := filepath.Join(baseDir, "art-present.wav")
	if err := os.WriteFile(audioPath, []byte("RIFF"), 0o644); err != nil {
		t.Fatal(err)
	}

	restorePictureReader := embeddedPictureReader
	restoreWAVFallback := wavCoverExtractor
	t.Cleanup(func() {
		embeddedPictureReader = restorePictureReader
		wavCoverExtractor = restoreWAVFallback
	})

	embeddedPictureReader = func(gotPath string) (*tag.Picture, error) {
		if gotPath != audioPath {
			t.Fatalf("audio path = %q, want %q", gotPath, audioPath)
		}
		return &tag.Picture{
			Ext:  "png",
			Data: []byte("png"),
		}, nil
	}
	wavFallbackCalled := false
	wavCoverExtractor = func(gotAudioPath, gotAlbumDir string) string {
		wavFallbackCalled = true
		t.Fatalf("wav fallback should not be called when embedded art exists; got audioPath=%q albumDir=%q", gotAudioPath, gotAlbumDir)
		return ""
	}

	got := extractCoverFromTrack(audioPath, albumDir)

	if got != "" {
		t.Fatalf("cover path = %q, want empty path after embedded art write failure", got)
	}
	if wavFallbackCalled {
		t.Fatal("wav fallback was called")
	}
}

func TestWriteExtractedCoverNormalizesJPEGExtensionToJPG(t *testing.T) {
	albumDir := t.TempDir()

	got := writeExtractedCover(albumDir, &tag.Picture{
		Ext:  "jpeg",
		Data: []byte("jpeg-data"),
	})

	want := filepath.Join(albumDir, "extracted_cover.jpg")
	if got != want {
		t.Fatalf("cover path = %q, want %q", got, want)
	}
	data, err := os.ReadFile(want)
	if err != nil {
		t.Fatalf("read written jpg: %v", err)
	}
	if string(data) != "jpeg-data" {
		t.Fatalf("cover data = %q, want %q", string(data), "jpeg-data")
	}
}

func TestExtractCoverFromWAVUsesFFmpegFromPATHAndRequiresOutputFile(t *testing.T) {
	albumDir := t.TempDir()
	audioPath := filepath.Join(albumDir, "coverless.wav")
	if err := os.WriteFile(audioPath, []byte("RIFF"), 0o644); err != nil {
		t.Fatal(err)
	}

	ffmpegDir := t.TempDir()
	outPath := filepath.Join(albumDir, "extracted_cover.png")
	ffmpegPath := filepath.Join(ffmpegDir, "ffmpeg")
	script := `#!/bin/sh
if [ "$1" != "-y" ]; then
	echo "arg1=$1" >&2
	exit 9
fi
if [ "$2" != "-i" ]; then
	echo "arg2=$2" >&2
	exit 9
fi
if [ "$3" != "` + audioPath + `" ]; then
	echo "input=$3" >&2
	exit 9
fi
if [ "$4" != "-an" ]; then
	echo "arg4=$4" >&2
	exit 9
fi
if [ "$5" != "-c:v" ] || [ "$6" != "png" ]; then
	echo "codec=$5,$6" >&2
	exit 9
fi
if [ "$7" != "-frames:v" ] || [ "$8" != "1" ]; then
	echo "frames=$7,$8" >&2
	exit 9
fi
if [ "$9" != "` + outPath + `" ]; then
	echo "output=$9" >&2
	exit 9
fi
printf png-data > "$9"
`
	if err := os.WriteFile(ffmpegPath, []byte(script), 0o755); err != nil {
		t.Fatalf("write fake ffmpeg: %v", err)
	}

	origPath := os.Getenv("PATH")
	t.Setenv("PATH", ffmpegDir+string(os.PathListSeparator)+origPath)

	got := extractCoverFromWAV(audioPath, albumDir)

	if got != outPath {
		t.Fatalf("cover path = %q, want %q", got, outPath)
	}
	if _, err := os.Stat(outPath); err != nil {
		t.Fatalf("expected extracted cover to exist after ffmpeg run: %v", err)
	}
}

func TestExtractCoverFromWAVReturnsEmptyWhenFFmpegDoesNotCreateOutput(t *testing.T) {
	albumDir := t.TempDir()
	audioPath := filepath.Join(albumDir, "coverless.wav")
	if err := os.WriteFile(audioPath, []byte("RIFF"), 0o644); err != nil {
		t.Fatal(err)
	}

	ffmpegDir := t.TempDir()
	ffmpegPath := filepath.Join(ffmpegDir, "ffmpeg")
	script := `#!/bin/sh
if [ "$1" != "-y" ] || [ "$2" != "-i" ] || [ "$3" != "` + audioPath + `" ]; then
	exit 9
fi
if [ "$4" != "-an" ] || [ "$5" != "-c:v" ] || [ "$6" != "png" ]; then
	exit 9
fi
if [ "$7" != "-frames:v" ] || [ "$8" != "1" ]; then
	exit 9
fi
if [ "$9" != "` + filepath.Join(albumDir, "extracted_cover.png") + `" ]; then
	exit 9
fi
exit 0
`
	if err := os.WriteFile(ffmpegPath, []byte(script), 0o755); err != nil {
		t.Fatalf("write fake ffmpeg: %v", err)
	}

	origPath := os.Getenv("PATH")
	t.Setenv("PATH", ffmpegDir+string(os.PathListSeparator)+origPath)

	got := extractCoverFromWAV(audioPath, albumDir)

	if got != "" {
		t.Fatalf("cover path = %q, want empty path when ffmpeg does not create output", got)
	}
}

func TestExtractCoverFromWAVRemovesStaleOutputWhenFFmpegFails(t *testing.T) {
	albumDir := t.TempDir()
	audioPath := filepath.Join(albumDir, "coverless.wav")
	if err := os.WriteFile(audioPath, []byte("RIFF"), 0o644); err != nil {
		t.Fatal(err)
	}

	ffmpegDir := t.TempDir()
	outPath := filepath.Join(albumDir, "extracted_cover.png")
	ffmpegPath := filepath.Join(ffmpegDir, "ffmpeg")
	script := `#!/bin/sh
if [ "$1" != "-y" ] || [ "$2" != "-i" ] || [ "$3" != "` + audioPath + `" ]; then
	exit 9
fi
if [ "$4" != "-an" ] || [ "$5" != "-c:v" ] || [ "$6" != "png" ]; then
	exit 9
fi
if [ "$7" != "-frames:v" ] || [ "$8" != "1" ]; then
	exit 9
fi
if [ "$9" != "` + outPath + `" ]; then
	exit 9
fi
printf stale-data > "$9"
exit 7
`
	if err := os.WriteFile(ffmpegPath, []byte(script), 0o755); err != nil {
		t.Fatalf("write fake ffmpeg: %v", err)
	}
	if err := os.WriteFile(outPath, []byte("old-data"), 0o644); err != nil {
		t.Fatalf("seed stale output: %v", err)
	}

	origPath := os.Getenv("PATH")
	t.Setenv("PATH", ffmpegDir+string(os.PathListSeparator)+origPath)

	got := extractCoverFromWAV(audioPath, albumDir)

	if got != "" {
		t.Fatalf("cover path = %q, want empty path when ffmpeg exits non-zero", got)
	}
	if _, err := os.Stat(outPath); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("expected stale output to be removed, stat err = %v", err)
	}
}

func TestScanWithOptionsForceReprocessesUnchangedFiles(t *testing.T) {
	tmpDir := t.TempDir()
	st, err := store.New(filepath.Join(tmpDir, "test.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	defer st.Close()

	mediaRoot := filepath.Join(tmpDir, "media")
	albumDir := filepath.Join(mediaRoot, "artist", "album")
	if err := os.MkdirAll(albumDir, 0o755); err != nil {
		t.Fatalf("mkdir album dir: %v", err)
	}
	audioPath := filepath.Join(albumDir, "track.wav")
	if err := os.WriteFile(audioPath, []byte("audio"), 0o644); err != nil {
		t.Fatalf("write audio file: %v", err)
	}

	restoreSeams := stubScannerSeams()
	defer restoreSeams()

	ffprobeCalls := 0
	ffprobeRunner = func(path string) (int, string, map[string]string) {
		if path != audioPath {
			t.Fatalf("ffprobe path = %q, want %q", path, audioPath)
		}
		ffprobeCalls++
		return 123, "16bit PCM_S16LE", map[string]string{
			"title": "Rescan Track",
			"album": "Rescan Album",
		}
	}
	metadataReader = func(path string) (tag.Metadata, error) {
		if path != audioPath {
			t.Fatalf("metadataReader path = %q, want %q", path, audioPath)
		}
		return fakeMetadata{}, nil
	}
	embeddedPictureReader = func(path string) (*tag.Picture, error) {
		if path != audioPath {
			t.Fatalf("embeddedPictureReader path = %q, want %q", path, audioPath)
		}
		return nil, nil
	}
	wavCoverExtractor = func(gotAudioPath, gotAlbumDir string) string {
		if gotAudioPath != audioPath {
			t.Fatalf("wavCoverExtractor audioPath = %q, want %q", gotAudioPath, audioPath)
		}
		if gotAlbumDir != albumDir {
			t.Fatalf("wavCoverExtractor albumDir = %q, want %q", gotAlbumDir, albumDir)
		}
		return ""
	}
	videoThumbFinder = func(string) string { return "" }

	if err := Scan(mediaRoot, st, 1, 10); err != nil {
		t.Fatalf("initial scan: %v", err)
	}
	if err := ScanWithOptions(mediaRoot, st, 1, 10, ScanOptions{Force: true}); err != nil {
		t.Fatalf("force scan: %v", err)
	}

	if ffprobeCalls != 2 {
		t.Fatalf("ffprobeCalls = %d, want %d", ffprobeCalls, 2)
	}
}

func TestScanWithOptionsForceKeepsTrackIDsStable(t *testing.T) {
	tmpDir := t.TempDir()
	st, err := store.New(filepath.Join(tmpDir, "test.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	defer st.Close()

	mediaRoot := filepath.Join(tmpDir, "media")
	albumDir := filepath.Join(mediaRoot, "artist", "album")
	if err := os.MkdirAll(albumDir, 0o755); err != nil {
		t.Fatalf("mkdir album dir: %v", err)
	}
	audioPath := filepath.Join(albumDir, "track.flac")
	if err := os.WriteFile(audioPath, []byte("audio"), 0o644); err != nil {
		t.Fatalf("write audio file: %v", err)
	}

	restoreSeams := stubScannerSeams()
	defer restoreSeams()

	ffprobeRunner = func(path string) (int, string, map[string]string) {
		if path != audioPath {
			t.Fatalf("ffprobe path = %q, want %q", path, audioPath)
		}
		return 180, "FLAC", map[string]string{
			"title": "Stable Track",
			"album": "Stable Album",
		}
	}
	metadataReader = func(path string) (tag.Metadata, error) {
		if path != audioPath {
			t.Fatalf("metadataReader path = %q, want %q", path, audioPath)
		}
		return fakeMetadata{}, nil
	}
	embeddedPictureReader = func(path string) (*tag.Picture, error) {
		if path != audioPath {
			t.Fatalf("embeddedPictureReader path = %q, want %q", path, audioPath)
		}
		return nil, nil
	}
	videoThumbFinder = func(string) string { return "" }

	if err := Scan(mediaRoot, st, 1, 10); err != nil {
		t.Fatalf("initial scan: %v", err)
	}
	before, err := st.ListTracks()
	if err != nil {
		t.Fatalf("list tracks before: %v", err)
	}
	if len(before) != 1 {
		t.Fatalf("before len = %d, want %d", len(before), 1)
	}

	if err := ScanWithOptions(mediaRoot, st, 1, 10, ScanOptions{Force: true}); err != nil {
		t.Fatalf("force scan: %v", err)
	}
	after, err := st.ListTracks()
	if err != nil {
		t.Fatalf("list tracks after: %v", err)
	}
	if len(after) != 1 {
		t.Fatalf("after len = %d, want %d", len(after), 1)
	}
	if before[0].ID != after[0].ID {
		t.Fatalf("track id changed from %d to %d", before[0].ID, after[0].ID)
	}
}

func TestScanWithOptionsWritesScannedComposerAndPreservesManualMetadata(t *testing.T) {
	tmpDir := t.TempDir()
	st, err := store.New(filepath.Join(tmpDir, "test.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	defer st.Close()

	mediaRoot := filepath.Join(tmpDir, "media")
	albumDir := filepath.Join(mediaRoot, "artist", "album")
	if err := os.MkdirAll(albumDir, 0o755); err != nil {
		t.Fatalf("mkdir album dir: %v", err)
	}
	audioPath := filepath.Join(albumDir, "track.flac")
	if err := os.WriteFile(audioPath, []byte("audio"), 0o644); err != nil {
		t.Fatalf("write audio file: %v", err)
	}

	restoreSeams := stubScannerSeams()
	defer restoreSeams()

	ffprobeRunner = func(path string) (int, string, map[string]string) {
		if path != audioPath {
			t.Fatalf("ffprobe path = %q, want %q", path, audioPath)
		}
		return 180, "FLAC", map[string]string{
			"title":             "Track",
			"album":             "Album",
			"composer":          "scan composer",
			"lyricist":          "scan lyricist",
			"arranger":          "scan arranger",
			"vocal":             "scan vocal",
			"voice_manipulator": "scan manipulator",
			"illustrator":       "scan illustrator",
			"movie":             "scan movie",
			"source":            "scan source",
		}
	}
	metadataReader = func(string) (tag.Metadata, error) { return fakeMetadata{}, nil }
	embeddedPictureReader = func(string) (*tag.Picture, error) { return nil, nil }
	videoThumbFinder = func(string) string { return "" }

	if err := ScanWithOptions(mediaRoot, st, 1, 10, ScanOptions{}); err != nil {
		t.Fatalf("initial scan: %v", err)
	}

	manualComposer := "manual composer"
	manualVocal := "manual vocal"
	if err := st.UpdateTrackMetadata(1, store.TrackMetadataPatch{
		Composer: &manualComposer,
		Vocal:    &manualVocal,
	}); err != nil {
		t.Fatalf("seed manual metadata: %v", err)
	}

	if err := ScanWithOptions(mediaRoot, st, 1, 10, ScanOptions{Force: true}); err != nil {
		t.Fatalf("rescan: %v", err)
	}

	row, ok, err := st.GetTrackMetadataByID(1)
	if err != nil || !ok {
		t.Fatalf("get metadata after rescan: ok=%v err=%v", ok, err)
	}
	if row.Composer != "manual composer" || row.ComposerSource != "manual" {
		t.Fatalf("composer = %q (%s)", row.Composer, row.ComposerSource)
	}
	if row.Lyricist != "scan lyricist" || row.LyricistSource != "scanned" {
		t.Fatalf("lyricist = %q (%s)", row.Lyricist, row.LyricistSource)
	}
	if row.Vocal != "manual vocal" {
		t.Fatalf("vocal = %q, want %q", row.Vocal, "manual vocal")
	}
	if row.Arranger != "" || row.VoiceManipulator != "" || row.Illustrator != "" || row.Movie != "" || row.Source != "" {
		t.Fatalf("manual-only fields were overwritten by scan: %+v", row)
	}
}

func TestScanWithOptionsReportsProgress(t *testing.T) {
	tmpDir := t.TempDir()
	st, err := store.New(filepath.Join(tmpDir, "test.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	defer st.Close()

	mediaRoot := filepath.Join(tmpDir, "media")
	albumDir := filepath.Join(mediaRoot, "artist", "album")
	if err := os.MkdirAll(albumDir, 0o755); err != nil {
		t.Fatalf("mkdir album dir: %v", err)
	}
	audioPath := filepath.Join(albumDir, "track.flac")
	if err := os.WriteFile(audioPath, []byte("audio"), 0o644); err != nil {
		t.Fatalf("write audio file: %v", err)
	}

	restoreSeams := stubScannerSeams()
	defer restoreSeams()

	ffprobeRunner = func(path string) (int, string, map[string]string) {
		if path != audioPath {
			t.Fatalf("ffprobe path = %q, want %q", path, audioPath)
		}
		return 180, "FLAC", map[string]string{
			"title": "Progress Track",
			"album": "Progress Album",
		}
	}
	metadataReader = func(path string) (tag.Metadata, error) {
		if path != audioPath {
			t.Fatalf("metadataReader path = %q, want %q", path, audioPath)
		}
		return fakeMetadata{}, nil
	}
	embeddedPictureReader = func(path string) (*tag.Picture, error) {
		if path != audioPath {
			t.Fatalf("embeddedPictureReader path = %q, want %q", path, audioPath)
		}
		return nil, nil
	}
	videoThumbFinder = func(string) string { return "" }

	var progress []ScanProgress
	err = ScanWithOptions(mediaRoot, st, 1, 10, ScanOptions{
		OnProgress: func(update ScanProgress) {
			progress = append(progress, update)
		},
	})
	if err != nil {
		t.Fatalf("scan with progress: %v", err)
	}
	if len(progress) == 0 {
		t.Fatal("expected progress updates")
	}
	last := progress[len(progress)-1]
	if last.ProcessedFiles != 1 {
		t.Fatalf("processed = %d, want %d", last.ProcessedFiles, 1)
	}
	if last.TotalFiles != 1 {
		t.Fatalf("total = %d, want %d", last.TotalFiles, 1)
	}
	if last.NewFiles != 1 {
		t.Fatalf("new files = %d, want %d", last.NewFiles, 1)
	}
}

func TestScanWithOptionsCompletedProgressCountsSkippedFiles(t *testing.T) {
	tmpDir := t.TempDir()
	st, err := store.New(filepath.Join(tmpDir, "test.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	defer st.Close()

	mediaRoot := filepath.Join(tmpDir, "media")
	albumDir := filepath.Join(mediaRoot, "artist", "album")
	if err := os.MkdirAll(albumDir, 0o755); err != nil {
		t.Fatalf("mkdir album dir: %v", err)
	}
	audioPath := filepath.Join(albumDir, "track.flac")
	if err := os.WriteFile(audioPath, []byte("audio"), 0o644); err != nil {
		t.Fatalf("write audio file: %v", err)
	}

	restoreSeams := stubScannerSeams()
	defer restoreSeams()

	ffprobeRunner = func(path string) (int, string, map[string]string) {
		if path != audioPath {
			t.Fatalf("ffprobe path = %q, want %q", path, audioPath)
		}
		return 180, "FLAC", map[string]string{
			"title": "Skipped Track",
			"album": "Skipped Album",
		}
	}
	metadataReader = func(path string) (tag.Metadata, error) {
		if path != audioPath {
			t.Fatalf("metadataReader path = %q, want %q", path, audioPath)
		}
		return fakeMetadata{}, nil
	}
	embeddedPictureReader = func(path string) (*tag.Picture, error) {
		if path != audioPath {
			t.Fatalf("embeddedPictureReader path = %q, want %q", path, audioPath)
		}
		return nil, nil
	}
	videoThumbFinder = func(string) string { return "" }

	if err := Scan(mediaRoot, st, 1, 10); err != nil {
		t.Fatalf("initial scan: %v", err)
	}

	var progress []ScanProgress
	err = ScanWithOptions(mediaRoot, st, 1, 10, ScanOptions{
		OnProgress: func(update ScanProgress) {
			progress = append(progress, update)
		},
	})
	if err != nil {
		t.Fatalf("scan with progress: %v", err)
	}
	if len(progress) == 0 {
		t.Fatal("expected progress updates")
	}
	last := progress[len(progress)-1]
	if last.Phase != "completed" {
		t.Fatalf("last phase = %q, want %q", last.Phase, "completed")
	}
	if last.ProcessedFiles != 1 {
		t.Fatalf("processed = %d, want %d", last.ProcessedFiles, 1)
	}
	if last.TotalFiles != 1 {
		t.Fatalf("total = %d, want %d", last.TotalFiles, 1)
	}
	if last.SkippedFiles != 1 {
		t.Fatalf("skipped = %d, want %d", last.SkippedFiles, 1)
	}
}

func TestReadEmbeddedPictureUsesMetadataReaderSeam(t *testing.T) {
	restoreSeams := stubScannerSeams()
	defer restoreSeams()

	wantPath := filepath.Join(t.TempDir(), "coverless.wav")
	wantPic := &tag.Picture{Ext: "png", Data: []byte("png")}
	metadataReader = func(gotPath string) (tag.Metadata, error) {
		if gotPath != wantPath {
			t.Fatalf("metadataReader path = %q, want %q", gotPath, wantPath)
		}
		return fakeMetadata{picture: wantPic}, nil
	}

	got, err := readEmbeddedPicture(wantPath)
	if err != nil {
		t.Fatalf("readEmbeddedPicture error = %v, want nil", err)
	}
	if !reflect.DeepEqual(got, wantPic) {
		t.Fatalf("picture = %#v, want %#v", got, wantPic)
	}
}

func TestFindArtistAvatarUsesPreferredImageFormats(t *testing.T) {
	tests := []struct {
		name       string
		files      []string
		wantAvatar string
	}{
		{
			name:       "prefers jpg before other supported formats",
			files:      []string{"artist.webp", "artist.png", "artist.jpeg", "artist.jpg"},
			wantAvatar: "artist.jpg",
		},
		{
			name:       "falls back to jpeg when jpg is missing",
			files:      []string{"artist.webp", "artist.png", "artist.jpeg"},
			wantAvatar: "artist.jpeg",
		},
		{
			name:       "falls back to png when jpeg is missing",
			files:      []string{"artist.webp", "artist.png"},
			wantAvatar: "artist.png",
		},
		{
			name:       "falls back to webp when it is the only supported format",
			files:      []string{"artist.webp"},
			wantAvatar: "artist.webp",
		},
		{
			name:       "ignores unsupported artist image names",
			files:      []string{"artist.gif", "avatar.jpg"},
			wantAvatar: "",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			artistDir := t.TempDir()
			for _, name := range tc.files {
				path := filepath.Join(artistDir, name)
				if err := os.WriteFile(path, []byte(name), 0o644); err != nil {
					t.Fatalf("write %s: %v", name, err)
				}
			}

			got := findArtistAvatar(artistDir)
			want := ""
			if tc.wantAvatar != "" {
				want = filepath.Join(artistDir, tc.wantAvatar)
			}
			if got != want {
				t.Fatalf("findArtistAvatar() = %q, want %q", got, want)
			}
		})
	}
}

func TestStubScannerSeamsRestoresAllScannerSeams(t *testing.T) {
	origFFprobeRunner := ffprobeRunner
	origMetadataReader := metadataReader
	origVideoThumbFinder := videoThumbFinder
	origEmbeddedPictureReader := embeddedPictureReader
	origWAVCoverExtractor := wavCoverExtractor

	restoreSeams := stubScannerSeams()

	ffprobeRunner = func(string) (int, string, map[string]string) { return 1, "changed", nil }
	metadataReader = func(string) (tag.Metadata, error) { return nil, errors.New("changed") }
	videoThumbFinder = func(string) string { return "changed" }
	embeddedPictureReader = func(string) (*tag.Picture, error) { return &tag.Picture{Ext: "png", Data: []byte("changed")}, nil }
	wavCoverExtractor = func(string, string) string { return "changed" }

	restoreSeams()

	if ffprobeRunner == nil || metadataReader == nil || videoThumbFinder == nil || embeddedPictureReader == nil || wavCoverExtractor == nil {
		t.Fatal("expected all seams to be restored to non-nil functions")
	}
	if reflect.ValueOf(ffprobeRunner).Pointer() != reflect.ValueOf(origFFprobeRunner).Pointer() {
		t.Fatal("ffprobeRunner was not restored")
	}
	if reflect.ValueOf(metadataReader).Pointer() != reflect.ValueOf(origMetadataReader).Pointer() {
		t.Fatal("metadataReader was not restored")
	}
	if reflect.ValueOf(videoThumbFinder).Pointer() != reflect.ValueOf(origVideoThumbFinder).Pointer() {
		t.Fatal("videoThumbFinder was not restored")
	}
	if reflect.ValueOf(embeddedPictureReader).Pointer() != reflect.ValueOf(origEmbeddedPictureReader).Pointer() {
		t.Fatal("embeddedPictureReader was not restored")
	}
	if reflect.ValueOf(wavCoverExtractor).Pointer() != reflect.ValueOf(origWAVCoverExtractor).Pointer() {
		t.Fatal("wavCoverExtractor was not restored")
	}
}

func stubScannerSeams() func() {
	origFFprobeRunner := ffprobeRunner
	origMetadataReader := metadataReader
	origVideoThumbFinder := videoThumbFinder
	origEmbeddedPictureReader := embeddedPictureReader
	origWAVCoverExtractor := wavCoverExtractor
	return func() {
		ffprobeRunner = origFFprobeRunner
		metadataReader = origMetadataReader
		videoThumbFinder = origVideoThumbFinder
		embeddedPictureReader = origEmbeddedPictureReader
		wavCoverExtractor = origWAVCoverExtractor
	}
}

func mapsKeys(values map[string]bool) []string {
	keys := make([]string, 0, len(values))
	for key := range values {
		keys = append(keys, key)
	}
	slices.Sort(keys)
	return keys
}

type fakeMetadata struct {
	picture *tag.Picture
}

func (m fakeMetadata) Format() tag.Format          { return tag.UnknownFormat }
func (m fakeMetadata) FileType() tag.FileType      { return tag.UnknownFileType }
func (m fakeMetadata) Title() string               { return "" }
func (m fakeMetadata) Album() string               { return "" }
func (m fakeMetadata) Artist() string              { return "" }
func (m fakeMetadata) AlbumArtist() string         { return "" }
func (m fakeMetadata) Composer() string            { return "" }
func (m fakeMetadata) Year() int                   { return 0 }
func (m fakeMetadata) Genre() string               { return "" }
func (m fakeMetadata) Track() (int, int)           { return 0, 0 }
func (m fakeMetadata) Disc() (int, int)            { return 0, 0 }
func (m fakeMetadata) Picture() *tag.Picture       { return m.picture }
func (m fakeMetadata) Lyrics() string              { return "" }
func (m fakeMetadata) Comment() string             { return "" }
func (m fakeMetadata) Raw() map[string]interface{} { return nil }
