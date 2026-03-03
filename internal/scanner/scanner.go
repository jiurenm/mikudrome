package scanner

import (
	"encoding/json"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/dhowden/tag"
	"github.com/mikudrome/mikudrome/internal/store"
)

// AudioExts lists supported audio extensions (lowercase).
var AudioExts = map[string]bool{
	".flac": true, ".mp3": true, ".m4a": true, ".ogg": true, ".wav": true,
}

// VideoExts lists supported video extensions for MV matching (lowercase).
var VideoExts = map[string]bool{
	".mp4": true, ".mkv": true, ".webm": true, ".avi": true,
}

// ThumbExts preferred extensions for MV thumbnail (same base name as video).
var ThumbExts = []string{".jpg", ".jpeg", ".png", ".webp"}

// CoverNames preferred filenames for album cover image (same dir as tracks).
// extracted_cover.jpg is written when we extract from a track's embedded art.
var CoverNames = []string{"Cover.jpg", "cover.jpg", "Jacket.jpg", "jacket.jpg", "folder.jpg", "Folder.jpg", "extracted_cover.jpg", "extracted_cover.png"}

// Scan walks mediaRoot, finds audio files, and for each audio reads metadata (title, track#, producer, vocal),
// looks for same-named video. Assumes structure media/Artist/Album/*.flac. If album dir has no cover file,
// extracts cover from the first track that has embedded art.
func Scan(mediaRoot string, s *store.Store) error {
	audioPaths := make(map[string]string) // base name (no ext) -> full path
	err := filepath.Walk(mediaRoot, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}
		ext := strings.ToLower(filepath.Ext(path))
		if AudioExts[ext] {
			base := strings.TrimSuffix(path, ext)
			audioPaths[base] = path
		}
		return nil
	})
	if err != nil {
		return err
	}

	total := len(audioPaths)
	if total == 0 {
		log.Println("scan: no audio files found")
		return nil
	}
	log.Printf("scan: found %d track(s), processing...", total)

	mediaRootAbs := filepath.Clean(mediaRoot)
	if abs, err := filepath.Abs(mediaRootAbs); err == nil {
		mediaRootAbs = abs
	}
	n := 0
	for base, audioPath := range audioPaths {
		n++
		log.Printf("scan: [%d/%d] %s", n, total, filepath.Base(audioPath))
		dir := filepath.Dir(audioPath)
		dirAbs, _ := filepath.Abs(dir)
		dirAbs = filepath.Clean(dirAbs)
		fallbackTitle := filepath.Base(base)
		videoPath := findVideoForBase(dir, base)
		videoThumbPath := ""
		if videoPath != "" {
			videoThumbPath = findOrExtractVideoThumb(videoPath)
		}

		title := fallbackTitle
		trackNumber := 0
		producer := ""
		vocal := ""
		year := 0
		durationSeconds := 0
		if m, err := readMetadata(audioPath); err == nil {
			if t := m.Title(); t != "" {
				title = t
			}
			if n, _ := m.Track(); n > 0 {
				trackNumber = n
			}
			producer = strings.TrimSpace(m.Composer())
			vocal = m.Artist()
			if y := m.Year(); y > 0 {
				year = y
			}
			durationSeconds = parseDurationFromMetadata(m)
		}
		// Producer fallback: use album folder artist when Composer is empty (media/Artist/Album structure)
		if producer == "" && dirAbs != mediaRootAbs {
			producer = strings.TrimSpace(filepath.Base(filepath.Dir(dirAbs)))
		}
		ffprobeDur, ffprobeFormat := runFFprobe(audioPath)
		if durationSeconds == 0 && ffprobeDur > 0 {
			durationSeconds = ffprobeDur
		}
		if durationSeconds == 0 && strings.ToLower(filepath.Ext(audioPath)) == ".flac" {
			durationSeconds = getFLACDuration(audioPath)
		}
		format := ffprobeFormat

		var albumID int64
		if dirAbs != mediaRootAbs {
			albumDir := dirAbs
			artistDir := filepath.Dir(albumDir) // P主 folder (media/Artist)
			artist := filepath.Base(artistDir)
			albumTitle := filepath.Base(albumDir)
			coverPath := findCoverInDir(albumDir)
			if coverPath == "" {
				coverPath = extractCoverFromTrack(audioPath, albumDir)
			}
			id, err := s.UpsertAlbum(albumDir, artist, albumTitle, coverPath)
			if err != nil {
				return err
			}
			albumID = id
			// P主头像: artist.jpg in P主 folder
			if avatarPath := findArtistAvatar(artistDir); avatarPath != "" && producer != "" {
				_ = s.UpsertProducerAvatar(producer, avatarPath)
			}
		}
		if err := s.UpsertTrack(title, audioPath, videoPath, videoThumbPath, albumID, trackNumber, producer, vocal, year, durationSeconds, format); err != nil {
			return err
		}
	}
	log.Printf("scan: done (%d track(s))", total)
	return nil
}

// runFFprobe runs ffprobe once and returns duration (seconds) and format label (e.g. "24bit FLAC"). Empty/0 on failure.
func runFFprobe(path string) (duration int, formatLabel string) {
	cmd := exec.Command("ffprobe",
		"-v", "error",
		"-select_streams", "a:0",
		"-show_entries", "stream=codec_name,bits_per_sample",
		"-show_entries", "format=duration,bit_rate",
		"-of", "json",
		path,
	)
	out, err := cmd.Output()
	if err != nil {
		return 0, ""
	}
	var probe struct {
		Streams []struct {
			CodecName     string `json:"codec_name"`
			BitsPerSample *int   `json:"bits_per_sample"`
		} `json:"streams"`
		Format struct {
			Duration string `json:"duration"`
			BitRate  string `json:"bit_rate"`
		} `json:"format"`
	}
	if err := json.Unmarshal(out, &probe); err != nil {
		return 0, ""
	}
	if probe.Format.Duration != "" {
		if sec, err := strconv.ParseFloat(probe.Format.Duration, 64); err == nil && sec > 0 {
			duration = int(sec + 0.5)
		}
	}
	if len(probe.Streams) == 0 {
		return duration, ""
	}
	s := probe.Streams[0]
	codec := strings.ToUpper(s.CodecName)
	if codec == "" {
		return duration, ""
	}
	if s.BitsPerSample != nil && *s.BitsPerSample > 0 {
		formatLabel = strconv.Itoa(*s.BitsPerSample) + "bit " + codec
	} else if probe.Format.BitRate != "" {
		if kbps, err := strconv.Atoi(probe.Format.BitRate); err == nil && kbps > 0 {
			kbps = (kbps + 500) / 1000
			formatLabel = strconv.Itoa(kbps) + "kbps " + codec
		} else {
			formatLabel = codec
		}
	} else {
		formatLabel = codec
	}
	return duration, formatLabel
}

// getFLACDuration reads FLAC STREAMINFO to get duration. Returns 0 on failure. Used when ffprobe is unavailable.
func getFLACDuration(path string) int {
	f, err := os.Open(path)
	if err != nil {
		return 0
	}
	defer f.Close()
	// FLAC: fLaC (4) + metadata block header (4) + STREAMINFO payload (34 bytes).
	buf := make([]byte, 4+4+34)
	if _, err := f.Read(buf); err != nil {
		return 0
	}
	if string(buf[0:4]) != "fLaC" {
		return 0
	}
	blockLen := int(buf[5])<<16 | int(buf[6])<<8 | int(buf[7])
	if blockLen < 34 {
		return 0
	}
	si := buf[8:] // STREAMINFO 34 bytes
	if len(si) < 34 {
		return 0
	}
	// Sample rate: 20 bits big-endian at byte 10-12 (high 4 bits of si[12]).
	sampleRate := int(si[10])<<12 | int(si[11])<<4 | int(si[12])>>4
	if sampleRate <= 0 {
		return 0
	}
	// Total samples: 36 bits, si[13] low 4 bits + si[14:18] 32 bits big-endian.
	totalSamples := (uint64(si[13]&0x0F) << 32) | (uint64(si[14]) << 24) | (uint64(si[15]) << 16) | (uint64(si[16]) << 8) | uint64(si[17])
	if totalSamples == 0 {
		return 0
	}
	return int(totalSamples / uint64(sampleRate))
}

// parseDurationFromMetadata tries to get duration in seconds from tag Raw() (e.g. "length", "duration", "LENGTH").
func parseDurationFromMetadata(m tag.Metadata) int {
	raw := m.Raw()
	if raw == nil {
		return 0
	}
	for _, key := range []string{"length", "LENGTH", "duration", "DURATION", "Duration"} {
		if v, ok := raw[key]; ok && v != nil {
			switch x := v.(type) {
			case int:
				if x > 0 {
					return x
				}
			case int64:
				if x > 0 {
					return int(x)
				}
			case float64:
				if x > 0 {
					return int(x)
				}
			case string:
				if sec := parseDurationString(x); sec > 0 {
					return sec
				}
			}
		}
	}
	return 0
}

// parseDurationString parses "mm:ss" or plain seconds string.
func parseDurationString(s string) int {
	s = strings.TrimSpace(s)
	if s == "" {
		return 0
	}
	if sec, err := strconv.Atoi(s); err == nil && sec >= 0 {
		return sec
	}
	parts := strings.Split(s, ":")
	if len(parts) == 2 {
		m, err1 := strconv.Atoi(strings.TrimSpace(parts[0]))
		sec, err2 := strconv.Atoi(strings.TrimSpace(parts[1]))
		if err1 == nil && err2 == nil && m >= 0 && sec >= 0 {
			return m*60 + sec
		}
	}
	if len(parts) == 3 {
		h, _ := strconv.Atoi(strings.TrimSpace(parts[0]))
		m, _ := strconv.Atoi(strings.TrimSpace(parts[1]))
		sec, _ := strconv.Atoi(strings.TrimSpace(parts[2]))
		if h >= 0 && m >= 0 && sec >= 0 {
			return h*3600 + m*60 + sec
		}
	}
	return 0
}

func readMetadata(path string) (tag.Metadata, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	return tag.ReadFrom(f)
}

// extractCoverFromTrack reads embedded picture from the audio file and writes to albumDir/extracted_cover.jpg.
// Returns the path to the written file, or "" on failure.
func extractCoverFromTrack(audioPath, albumDir string) string {
	f, err := os.Open(audioPath)
	if err != nil {
		return ""
	}
	defer f.Close()
	m, err := tag.ReadFrom(f)
	if err != nil {
		return ""
	}
	pic := m.Picture()
	if pic == nil || len(pic.Data) == 0 {
		return ""
	}
	ext := "jpg"
	if pic.Ext != "" {
		ext = pic.Ext
	}
	if ext != "jpg" && ext != "jpeg" && ext != "png" {
		ext = "jpg"
	}
	outPath := filepath.Join(albumDir, "extracted_cover."+ext)
	if err := os.WriteFile(outPath, pic.Data, 0644); err != nil {
		return ""
	}
	return outPath
}

func findCoverInDir(dir string) string {
	for _, name := range CoverNames {
		p := filepath.Join(dir, name)
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	return ""
}

// findArtistAvatar looks for artist.jpg in the P主 folder. Returns path or "".
func findArtistAvatar(artistDir string) string {
	p := filepath.Join(artistDir, "artist.jpg")
	if _, err := os.Stat(p); err == nil {
		return p
	}
	return ""
}

// findVideoForBase looks in dir for a file with same base name and a video extension.
func findVideoForBase(dir, base string) string {
	baseName := filepath.Base(base)
	for ext := range VideoExts {
		candidate := filepath.Join(dir, baseName+ext)
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
	}
	return ""
}

// findVideoThumb looks for a thumbnail in the same dir as video, same base name. Returns path or "".
func findVideoThumb(videoPath string) string {
	dir := filepath.Dir(videoPath)
	base := strings.TrimSuffix(filepath.Base(videoPath), filepath.Ext(videoPath))
	for _, ext := range ThumbExts {
		candidate := filepath.Join(dir, base+ext)
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
	}
	return ""
}

// extractVideoThumb uses ffmpeg to extract a frame at 1s and save as .jpg. Returns path or "".
func extractVideoThumb(videoPath string) string {
	dir := filepath.Dir(videoPath)
	base := strings.TrimSuffix(filepath.Base(videoPath), filepath.Ext(videoPath))
	outPath := filepath.Join(dir, base+".jpg")
	cmd := exec.Command("ffmpeg",
		"-y",
		"-i", videoPath,
		"-ss", "00:00:01",
		"-vframes", "1",
		"-q:v", "2",
		outPath,
	)
	if err := cmd.Run(); err != nil {
		return ""
	}
	if _, err := os.Stat(outPath); err != nil {
		return ""
	}
	return outPath
}

// findOrExtractVideoThumb returns existing thumbnail or generates one via ffmpeg.
func findOrExtractVideoThumb(videoPath string) string {
	if p := findVideoThumb(videoPath); p != "" {
		return p
	}
	return extractVideoThumb(videoPath)
}
