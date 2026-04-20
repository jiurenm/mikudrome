package scanner

import (
	"errors"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/dhowden/tag"
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
				t.Fatalf("metadataReader should not be called, got %q", path)
				return nil, errors.New("unexpected metadata read")
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
				t.Fatalf("metadataReader should not be called, got %q", path)
				return nil, errors.New("unexpected metadata read")
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

func stubScannerSeams() func() {
	origFFprobeRunner := ffprobeRunner
	origMetadataReader := metadataReader
	origVideoThumbFinder := videoThumbFinder
	return func() {
		ffprobeRunner = origFFprobeRunner
		metadataReader = origMetadataReader
		videoThumbFinder = origVideoThumbFinder
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
