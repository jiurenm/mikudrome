package scanner

import (
	"encoding/json"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

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

// scanJob represents a file to be processed.
type scanJob struct {
	audioPath string
	modTime   int64
	size      int64
}

// scanResult holds the result of processing a single file.
type scanResult struct {
	track    store.Track
	album    store.Album
	producer store.Producer
	err      error
}

// scanStats tracks scanning statistics.
type scanStats struct {
	total   int
	skipped int
	new     int
	updated int
	deleted int
	failed  int
}

// Scan walks mediaRoot, finds audio files, and for each audio reads metadata (title, track#, disc#, album, producer, vocal),
// looks for same-named video. Assumes structure media/Artist/Album/*.flac. Album title comes from metadata when
// present, otherwise falls back to folder name. If album dir has no cover file, extracts cover from embedded art.
// Uses incremental scanning with mtime/size comparison and concurrent processing.
func Scan(mediaRoot string, s *store.Store, workers, batchSize int) error {
	startTime := time.Now()
	log.Println("scan: phase 1/3 - discovering files...")

	// Get existing tracks metadata from database
	existingTracks, err := s.GetAllTracksMeta()
	if err != nil {
		return err
	}

	// Walk filesystem and collect audio files
	audioPaths := make(map[string]string) // base name (no ext) -> full path
	fileInfos := make(map[string]scanJob) // audio path -> file info
	err = filepath.Walk(mediaRoot, func(path string, info os.FileInfo, err error) error {
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
			fileInfos[path] = scanJob{
				audioPath: path,
				modTime:   info.ModTime().Unix(),
				size:      info.Size(),
			}
		}
		return nil
	})
	if err != nil {
		return err
	}

	stats := scanStats{total: len(audioPaths)}
	if stats.total == 0 {
		log.Println("scan: no audio files found")
		return nil
	}

	// Determine which files need processing
	var jobsToProcess []scanJob
	for _, job := range fileInfos {
		existing, exists := existingTracks[job.audioPath]
		if !exists {
			// New file
			jobsToProcess = append(jobsToProcess, job)
			stats.new++
		} else if existing.ModTime != job.modTime || existing.Size != job.size {
			// Modified file
			jobsToProcess = append(jobsToProcess, job)
			stats.updated++
		} else {
			// Unchanged file
			stats.skipped++
		}
	}

	// Find deleted files
	var deletedPaths []string
	for path := range existingTracks {
		if _, exists := fileInfos[path]; !exists {
			deletedPaths = append(deletedPaths, path)
			stats.deleted++
		}
	}

	log.Printf("scan: found %d files (%d new, %d updated, %d skipped, %d deleted)",
		stats.total, stats.new, stats.updated, stats.skipped, stats.deleted)

	// Phase 2: Process files with worker pool
	if len(jobsToProcess) > 0 {
		log.Printf("scan: phase 2/3 - processing %d files with %d workers...", len(jobsToProcess), workers)

		mediaRootAbs := filepath.Clean(mediaRoot)
		if abs, err := filepath.Abs(mediaRootAbs); err == nil {
			mediaRootAbs = abs
		}

		jobs := make(chan scanJob, workers*2)
		results := make(chan scanResult, workers*2)
		var wg sync.WaitGroup

		// Start workers
		for range workers {
			wg.Go(func() {
				for job := range jobs {
					result := processFile(job, mediaRootAbs)
					results <- result
				}
			})
		}

		// Start result collector
		collectorDone := make(chan error, 1)
		go func() {
			collectorDone <- collectResults(s, results, batchSize, len(jobsToProcess), &stats)
		}()

		// Send jobs to workers
		for _, job := range jobsToProcess {
			jobs <- job
		}
		close(jobs)

		// Wait for workers to finish
		wg.Wait()
		close(results)

		// Wait for collector to finish
		if err := <-collectorDone; err != nil {
			return err
		}
	}

	// Phase 3: Clean up deleted files
	if len(deletedPaths) > 0 {
		log.Printf("scan: phase 3/3 - cleaning %d deleted files...", len(deletedPaths))
		if err := s.DeleteTracksByPaths(deletedPaths); err != nil {
			log.Printf("scan: error deleting tracks: %v", err)
		}
		if err := s.CleanOrphanedAlbums(); err != nil {
			log.Printf("scan: error cleaning orphaned albums: %v", err)
		}
		if err := s.CleanOrphanedProducers(); err != nil {
			log.Printf("scan: error cleaning orphaned producers: %v", err)
		}
	}

	duration := time.Since(startTime)
	log.Printf("scan: completed in %s (new=%d updated=%d skipped=%d deleted=%d failed=%d)",
		duration.Round(time.Second), stats.new, stats.updated, stats.skipped, stats.deleted, stats.failed)

	return nil
}

// processFile processes a single audio file and returns the result.
func processFile(job scanJob, mediaRoot string) scanResult {
	audioPath := job.audioPath
	dir := filepath.Dir(audioPath)
	dirAbs, _ := filepath.Abs(dir)
	dirAbs = filepath.Clean(dirAbs)

	base := strings.TrimSuffix(audioPath, filepath.Ext(audioPath))
	fallbackTitle := filepath.Base(base)

	videoPath := findVideoForBase(dir, base)
	videoThumbPath := ""
	if videoPath != "" {
		videoThumbPath = findOrExtractVideoThumb(videoPath)
	}

	title := fallbackTitle
	trackNumber := 0
	discNumber := 1
	albumProducer := "" // AlbumArtist for album-level producer
	artists := ""       // Artist field, may contain multiple artists
	year := 0
	durationSeconds := 0
	albumTitleFromMeta := ""
	format := ""
	// Extended metadata fields
	composer := ""
	lyricist := ""
	arranger := ""
	vocal := ""
	voiceManipulator := ""
	illustrator := ""
	movie := ""
	source := ""
	lyrics := ""
	comment := ""

	// Use ffprobe to read all metadata in one call
	ffprobeDur, ffprobeFormat, ffprobeTags := runFFprobe(audioPath)

	if ffprobeTags != nil {
		// Read metadata from ffprobe tags
		if t, ok := ffprobeTags["title"]; ok && t != "" {
			title = t
		}
		if a, ok := ffprobeTags["artist"]; ok && a != "" {
			artists = strings.TrimSpace(a)
		}
		if aa, ok := ffprobeTags["album_artist"]; ok && aa != "" {
			albumProducer = strings.TrimSpace(aa)
		} else if aa, ok := ffprobeTags["albumartist"]; ok && aa != "" {
			albumProducer = strings.TrimSpace(aa)
		}
		if album, ok := ffprobeTags["album"]; ok && album != "" {
			albumTitleFromMeta = strings.TrimSpace(album)
		}
		if dateStr, ok := ffprobeTags["date"]; ok && dateStr != "" {
			if y, err := strconv.Atoi(dateStr); err == nil && y > 0 {
				year = y
			}
		}
		if trackStr, ok := ffprobeTags["track"]; ok && trackStr != "" {
			// Track might be "5" or "5/12"
			parts := strings.Split(trackStr, "/")
			if n, err := strconv.Atoi(strings.TrimSpace(parts[0])); err == nil && n > 0 {
				trackNumber = n
			}
		}
		if discStr, ok := ffprobeTags["disc"]; ok && discStr != "" {
			// Disc might be "1" or "1/2"
			parts := strings.Split(discStr, "/")
			if d, err := strconv.Atoi(strings.TrimSpace(parts[0])); err == nil && d > 0 {
				discNumber = d
			}
		}
		// Read extended metadata fields
		if c, ok := ffprobeTags["composer"]; ok && c != "" {
			composer = normalizeCreditList(c)
		}
		if l, ok := ffprobeTags["lyricist"]; ok && l != "" {
			lyricist = normalizeCreditList(l)
		}
		if arr, ok := ffprobeTags["arranger"]; ok && arr != "" {
			arranger = normalizeCreditList(arr)
		}
		if v, ok := ffprobeTags["vocal"]; ok && v != "" {
			vocal = normalizeCreditList(v)
		}
		if vm, ok := ffprobeTags["voice_manipulator"]; ok && vm != "" {
			voiceManipulator = strings.TrimSpace(vm)
		}
		if ill, ok := ffprobeTags["illustrator"]; ok && ill != "" {
			illustrator = strings.TrimSpace(ill)
		}
		if mov, ok := ffprobeTags["movie"]; ok && mov != "" {
			movie = strings.TrimSpace(mov)
		}
		if src, ok := ffprobeTags["source"]; ok && src != "" {
			source = strings.TrimSpace(src)
		}
		if lyr, ok := ffprobeTags["lyrics"]; ok && lyr != "" {
			lyrics = strings.TrimSpace(lyr)
		}
		if cmt, ok := ffprobeTags["comment"]; ok && cmt != "" {
			comment = strings.TrimSpace(cmt)
		}
	}

	// Use ffprobe duration and format
	if ffprobeDur > 0 {
		durationSeconds = ffprobeDur
	}
	format = ffprobeFormat

	// Fallback to tag library if ffprobe failed
	if title == fallbackTitle || albumTitleFromMeta == "" {
		if m, err := readMetadata(audioPath); err == nil {
			if title == fallbackTitle {
				if t := m.Title(); t != "" {
					title = t
				}
			}
			if albumTitleFromMeta == "" {
				if a := m.Album(); a != "" {
					albumTitleFromMeta = strings.TrimSpace(a)
				}
			}
			if artists == "" {
				artists = strings.TrimSpace(m.Artist())
			}
			if albumProducer == "" {
				albumProducer = strings.TrimSpace(m.AlbumArtist())
			}
			if year == 0 {
				if y := m.Year(); y > 0 {
					year = y
				}
			}
			if trackNumber == 0 {
				if n, _ := m.Track(); n > 0 {
					trackNumber = n
				}
			}
			if discNumber == 1 {
				if d, _ := m.Disc(); d > 0 {
					discNumber = d
				}
			}
			if durationSeconds == 0 {
				durationSeconds = parseDurationFromMetadata(m)
			}
		}
	}

	// Final fallback for duration: FLAC direct parsing
	if durationSeconds == 0 && strings.ToLower(filepath.Ext(audioPath)) == ".flac" {
		durationSeconds = getFLACDuration(audioPath)
	}

	composer = normalizeCreditList(composer)
	lyricist = normalizeCreditList(lyricist)
	arranger = normalizeCreditList(arranger)
	vocal = normalizeCreditList(vocal)

	mediaRootAbs := mediaRoot

	// Build album and producer info
	var albumTitle, coverPath, avatarPath string
	if dirAbs != mediaRootAbs {
		albumDir := dirAbs
		artistDir := filepath.Dir(albumDir)

		// Check if this is a disc subdirectory (e.g., "Disc 1", "Disc 2")
		dirName := filepath.Base(albumDir)
		if strings.HasPrefix(dirName, "Disc ") || strings.HasPrefix(dirName, "CD ") {
			// Move up one level: the parent is the actual album directory
			albumDir = artistDir
			artistDir = filepath.Dir(albumDir)
		}

		// Use metadata album title as primary source
		albumTitle = albumTitleFromMeta
		if albumTitle == "" {
			// Fallback to folder name only if no metadata
			albumTitle = filepath.Base(albumDir)
		}

		coverPath = findCoverInDir(albumDir)
		if coverPath == "" {
			coverPath = extractCoverFromTrack(audioPath, albumDir)
		}
		avatarPath = findArtistAvatar(artistDir)
	}

	return scanResult{
		track: store.Track{
			Title:            title,
			AudioPath:        audioPath,
			VideoPath:        videoPath,
			VideoThumbPath:   videoThumbPath,
			DiscNumber:       discNumber,
			TrackNumber:      trackNumber,
			Artists:          artists,
			Year:             year,
			DurationSeconds:  durationSeconds,
			Format:           format,
			Composer:         composer,
			Lyricist:         lyricist,
			Arranger:         arranger,
			Vocal:            vocal,
			VoiceManipulator: voiceManipulator,
			Illustrator:      illustrator,
			Movie:            movie,
			Source:           source,
			Lyrics:           lyrics,
			Comment:          comment,
			FileMtime:        job.modTime,
			FileSize:         job.size,
		},
		album: store.Album{
			Title:     albumTitle,
			CoverPath: coverPath,
		},
		producer: store.Producer{
			Name:       albumProducer,
			AvatarPath: avatarPath,
		},
		err: nil,
	}
}

// collectResults collects results from workers and writes to database in batches.
func collectResults(s *store.Store, results <-chan scanResult, batchSize, totalJobs int, stats *scanStats) error {
	batch, err := s.BeginBatch(batchSize)
	if err != nil {
		return err
	}
	defer batch.Close()

	processed := 0
	lastLog := time.Now()
	for result := range results {
		processed++
		if result.err != nil {
			log.Printf("scan: error processing %s: %v", result.track.AudioPath, result.err)
			stats.failed++
			continue
		}

		if err := batch.Add(result.track, result.album, result.producer); err != nil {
			log.Printf("scan: error adding to batch: %v", err)
			stats.failed++
			continue
		}

		// Log progress every 5 seconds
		if time.Since(lastLog) >= 5*time.Second {
			log.Printf("scan: processed %d/%d files...", processed, totalJobs)
			lastLog = time.Now()
		}
	}

	return nil
}

// runFFprobe runs ffprobe once and returns all metadata including duration, format, and tags.
func runFFprobe(path string) (duration int, formatLabel string, tags map[string]string) {
	cmd := exec.Command("ffprobe",
		"-v", "error",
		"-select_streams", "a:0",
		"-show_entries", "stream=codec_name,bits_per_sample",
		"-show_entries", "format=duration,bit_rate",
		"-show_entries", "format_tags=title,artist,album,album_artist,albumartist,date,track,disc,composer,lyricist,arranger,vocal,voice_manipulator,illustrator,movie,source,lyrics,comment",
		"-of", "json",
		path,
	)
	out, err := cmd.Output()
	if err != nil {
		return 0, "", nil
	}
	var probe struct {
		Streams []struct {
			CodecName     string `json:"codec_name"`
			BitsPerSample *int   `json:"bits_per_sample"`
		} `json:"streams"`
		Format struct {
			Duration string            `json:"duration"`
			BitRate  string            `json:"bit_rate"`
			Tags     map[string]string `json:"tags"`
		} `json:"format"`
	}
	if err := json.Unmarshal(out, &probe); err != nil {
		return 0, "", nil
	}

	// Parse duration
	if probe.Format.Duration != "" {
		if sec, err := strconv.ParseFloat(probe.Format.Duration, 64); err == nil && sec > 0 {
			duration = int(sec + 0.5)
		}
	}

	// Parse format label
	if len(probe.Streams) > 0 {
		s := probe.Streams[0]
		codec := strings.ToUpper(s.CodecName)
		if codec != "" {
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
		}
	}

	// Return tags
	tags = probe.Format.Tags
	return duration, formatLabel, tags
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

func normalizeCreditList(value string) string {
	parts := strings.FieldsFunc(value, func(r rune) bool {
		return r == ';' || r == '；'
	})
	cleaned := make([]string, 0, len(parts))
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part != "" {
			cleaned = append(cleaned, part)
		}
	}
	return strings.Join(cleaned, "; ")
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

// FindVideoForBase is the exported version for use after downloading MV (e.g. from api package).
func FindVideoForBase(dir, base string) string {
	return findVideoForBase(dir, base)
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

// FindOrExtractVideoThumb is the exported version for use after downloading MV (e.g. from api package).
func FindOrExtractVideoThumb(videoPath string) string {
	return findOrExtractVideoThumb(videoPath)
}
