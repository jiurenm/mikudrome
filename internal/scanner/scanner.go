package scanner

import (
	"encoding/json"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
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
// extracted_cover.jpg or extracted_cover.png may be written when we extract art from a track.
var CoverNames = []string{"Cover.jpg", "cover.jpg", "Jacket.jpg", "jacket.jpg", "folder.jpg", "Folder.jpg", "extracted_cover.jpg", "extracted_cover.png"}

var (
	ffprobeRunner         = runFFprobe
	metadataReader        = readMetadata
	videoThumbFinder      = findOrExtractVideoThumb
	embeddedPictureReader = readEmbeddedPicture
	wavCoverExtractor     = extractCoverFromWAV
)

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

// ScanOptions controls optional scan behavior.
type ScanOptions struct {
	Force      bool
	OnProgress func(ScanProgress)
}

// ScanProgress reports scan progress and summary counters.
type ScanProgress struct {
	Phase          string
	TotalFiles     int
	ProcessedFiles int
	NewFiles       int
	UpdatedFiles   int
	SkippedFiles   int
	DeletedFiles   int
	FailedFiles    int
}

type albumCoverCoordinator struct {
	mu     sync.Mutex
	albums map[string]*albumCoverState
}

type albumCoverState struct {
	cond      *sync.Cond
	running   bool
	done      bool
	coverPath string
}

func newAlbumCoverCoordinator() *albumCoverCoordinator {
	return &albumCoverCoordinator{
		albums: make(map[string]*albumCoverState),
	}
}

func (c *albumCoverCoordinator) resolve(albumDir string, resolve func() string) string {
	if c == nil || albumDir == "" {
		return resolve()
	}

	albumDir = filepath.Clean(albumDir)

	c.mu.Lock()
	state := c.albums[albumDir]
	if state == nil {
		state = &albumCoverState{}
		state.cond = sync.NewCond(&c.mu)
		c.albums[albumDir] = state
	}
	for state.running && !state.done {
		state.cond.Wait()
	}
	if state.done {
		coverPath := state.coverPath
		c.mu.Unlock()
		return coverPath
	}
	state.running = true
	c.mu.Unlock()

	coverPath := resolve()

	c.mu.Lock()
	state.coverPath = coverPath
	state.done = true
	state.running = false
	state.cond.Broadcast()
	c.mu.Unlock()

	return coverPath
}

// Scan walks mediaRoot, finds audio files, and for each audio reads metadata (title, track#, disc#, album, producer, vocal),
// looks for same-named video. Assumes structure media/Artist/Album/*.flac. Album title comes from metadata when
// present, otherwise falls back to folder name. If album dir has no cover file, extracts cover from embedded art.
// Uses incremental scanning with mtime/size comparison and concurrent processing.
func Scan(mediaRoot string, s *store.Store, workers, batchSize int) error {
	return ScanWithOptions(mediaRoot, s, workers, batchSize, ScanOptions{})
}

// ScanWithOptions walks mediaRoot, discovers media files, and optionally forces
// reprocessing of unchanged files while emitting progress updates.
func ScanWithOptions(mediaRoot string, s *store.Store, workers, batchSize int, opts ScanOptions) error {
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
		emitScanProgress(opts, "completed", stats, 0)
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
		} else if opts.Force {
			// Force reprocess unchanged files during a full rescan.
			jobsToProcess = append(jobsToProcess, job)
			stats.updated++
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
	emitScanProgress(opts, "discovered", stats, 0)

	// Phase 2: Process files with worker pool
	if len(jobsToProcess) > 0 {
		log.Printf("scan: phase 2/3 - processing %d files with %d workers...", len(jobsToProcess), workers)

		mediaRootAbs := filepath.Clean(mediaRoot)
		if abs, err := filepath.Abs(mediaRootAbs); err == nil {
			mediaRootAbs = abs
		}
		albumCovers := newAlbumCoverCoordinator()

		jobs := make(chan scanJob, workers*2)
		results := make(chan scanResult, workers*2)
		var wg sync.WaitGroup

		// Start workers
		for range workers {
			wg.Go(func() {
				for job := range jobs {
					result := processFileWithAlbumCoverCoordinator(job, mediaRootAbs, albumCovers)
					results <- result
				}
			})
		}

		// Start result collector
		collectorDone := make(chan error, 1)
		go func() {
			collectorDone <- collectResults(s, results, batchSize, len(jobsToProcess), &stats, func(processed int, current scanStats) {
				emitScanProgress(opts, "processing", current, processed)
			})
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
		emitScanProgress(opts, "deleting", stats, len(jobsToProcess))
	}

	// Phase 4: Video consistency check
	log.Println("scan: phase 4 - video consistency check...")
	videoConsistencyCheck(s, fileInfos)

	// Phase 5: Scan standalone MVs from mediaRoot/MVs/
	scanStandaloneMVs(mediaRoot, s)

	// Phase 6: Sync track-associated MVs into videos table
	if err := s.SyncTrackVideos(); err != nil {
		log.Printf("scan: error syncing track videos: %v", err)
	}

	duration := time.Since(startTime)
	log.Printf("scan: completed in %s (new=%d updated=%d skipped=%d deleted=%d failed=%d)",
		duration.Round(time.Second), stats.new, stats.updated, stats.skipped, stats.deleted, stats.failed)
	emitScanProgress(opts, "completed", stats, stats.total)

	return nil
}

// processFile processes a single audio file and returns the result.
func processFile(job scanJob, mediaRoot string) scanResult {
	return processFileWithAlbumCoverCoordinator(job, mediaRoot, nil)
}

func processFileWithAlbumCoverCoordinator(job scanJob, mediaRoot string, albumCovers *albumCoverCoordinator) scanResult {
	audioPath := job.audioPath
	dir := filepath.Dir(audioPath)
	dirAbs, _ := filepath.Abs(dir)
	dirAbs = filepath.Clean(dirAbs)

	base := strings.TrimSuffix(audioPath, filepath.Ext(audioPath))
	fallbackTitle := filepath.Base(base)

	videoPath := findVideoForBase(dir, base)
	videoThumbPath := ""
	if videoPath != "" {
		videoThumbPath = videoThumbFinder(videoPath)
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
	ffprobeDur, ffprobeFormat, ffprobeTags := ffprobeRunner(audioPath)

	if ffprobeTags != nil {
		if t := lookupTag(ffprobeTags, "title", "INAM"); t != "" {
			title = t
		}
		if a := lookupTag(ffprobeTags, "artist", "IART"); a != "" {
			artists = a
		}
		if aa := lookupTag(ffprobeTags, "album_artist", "albumartist", "TPE2"); aa != "" {
			albumProducer = aa
		}
		if album := lookupTag(ffprobeTags, "album", "IPRD"); album != "" {
			albumTitleFromMeta = album
		}
		if y := parseYearTag(lookupTag(ffprobeTags, "date", "year", "ICRD")); y > 0 {
			year = y
		}
		if n := parseCountTag(lookupTag(ffprobeTags, "track", "ITRK")); n > 0 {
			trackNumber = n
		}
		if d := parseCountTag(lookupTag(ffprobeTags, "disc", "TPOS", "IPRT")); d > 0 {
			discNumber = d
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
		if lyr := lookupTag(ffprobeTags, "lyrics", "LYRICS"); lyr != "" {
			lyrics = lyr
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
		if m, err := metadataReader(audioPath); err == nil {
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

		coverPath = resolveAlbumCover(audioPath, albumDir, albumCovers)
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
			Title:       albumTitle,
			CoverPath:   coverPath,
			AlbumArtist: albumProducer,
		},
		producer: store.Producer{
			Name:       albumProducer,
			AvatarPath: avatarPath,
		},
		err: nil,
	}
}

func resolveAlbumCover(_ string, albumDir string, albumCovers *albumCoverCoordinator) string {
	resolve := func() string {
		return resolveDeterministicAlbumCover(albumDir)
	}
	if albumCovers == nil {
		return resolve()
	}
	return albumCovers.resolve(albumDir, resolve)
}

func resolveDeterministicAlbumCover(albumDir string) string {
	coverPath := findCoverInDir(albumDir)
	if coverPath != "" && !isExtractedCoverPath(coverPath) {
		return coverPath
	}

	audioTracks := findAudioTracksInAlbum(albumDir)
	if len(audioTracks) == 0 {
		return coverPath
	}

	wavFallbackTrack := ""
	for _, audioPath := range audioTracks {
		pic, err := embeddedPictureReader(audioPath)
		if err != nil {
			if wavFallbackTrack == "" && strings.EqualFold(filepath.Ext(audioPath), ".wav") {
				wavFallbackTrack = audioPath
			}
			continue
		}
		if pic == nil || len(pic.Data) == 0 {
			if wavFallbackTrack == "" && strings.EqualFold(filepath.Ext(audioPath), ".wav") {
				wavFallbackTrack = audioPath
			}
			continue
		}
		if outPath := writeExtractedCover(albumDir, pic); outPath != "" {
			removeStaleExtractedCoverOutputs(albumDir, outPath)
			return outPath
		}
		return coverPath
	}

	if wavFallbackTrack != "" {
		if outPath := wavCoverExtractor(wavFallbackTrack, albumDir); outPath != "" {
			removeStaleExtractedCoverOutputs(albumDir, outPath)
			return outPath
		}
	}
	return coverPath
}

func findAudioTracksInAlbum(albumDir string) []string {
	var audioTracks []string
	_ = filepath.Walk(albumDir, func(path string, info os.FileInfo, err error) error {
		if err != nil || info == nil || info.IsDir() {
			return nil
		}
		if AudioExts[strings.ToLower(filepath.Ext(path))] {
			audioTracks = append(audioTracks, path)
		}
		return nil
	})
	sort.Strings(audioTracks)
	return audioTracks
}

// collectResults collects results from workers and writes to database in batches.
func collectResults(s *store.Store, results <-chan scanResult, batchSize, totalJobs int, stats *scanStats, onProcessed func(processed int, stats scanStats)) error {
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
			if onProcessed != nil {
				onProcessed(processed, *stats)
			}
			continue
		}

		if err := batch.Add(result.track, result.album, result.producer); err != nil {
			log.Printf("scan: error adding to batch: %v", err)
			stats.failed++
			if onProcessed != nil {
				onProcessed(processed, *stats)
			}
			continue
		}

		if onProcessed != nil {
			onProcessed(processed, *stats)
		}

		// Log progress every 5 seconds
		if time.Since(lastLog) >= 5*time.Second {
			log.Printf("scan: processed %d/%d files...", processed, totalJobs)
			lastLog = time.Now()
		}
	}

	return nil
}

func emitScanProgress(opts ScanOptions, phase string, stats scanStats, processed int) {
	if opts.OnProgress == nil {
		return
	}
	opts.OnProgress(ScanProgress{
		Phase:          phase,
		TotalFiles:     stats.total,
		ProcessedFiles: processed,
		NewFiles:       stats.new,
		UpdatedFiles:   stats.updated,
		SkippedFiles:   stats.skipped,
		DeletedFiles:   stats.deleted,
		FailedFiles:    stats.failed,
	})
}

// runFFprobe runs ffprobe once and returns all metadata including duration, format, and tags.
func runFFprobe(path string) (duration int, formatLabel string, tags map[string]string) {
	cmd := exec.Command("ffprobe",
		"-v", "error",
		"-select_streams", "a:0",
		"-show_entries", "stream=codec_name,bits_per_sample",
		"-show_entries", "format=duration,bit_rate",
		"-show_entries", "format_tags=title,INAM,inam,artist,IART,iart,album,IPRD,iprd,album_artist,albumartist,TPE2,tpe2,date,year,ICRD,icrd,track,ITRK,itrk,disc,TPOS,tpos,IPRT,iprt,composer,lyricist,arranger,vocal,voice_manipulator,illustrator,movie,source,lyrics,LYRICS,comment",
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

func lookupTag(tags map[string]string, keys ...string) string {
	if len(tags) == 0 {
		return ""
	}
	for _, key := range keys {
		if value, ok := tags[key]; ok {
			value = strings.TrimSpace(value)
			if value != "" {
				return value
			}
		}
		normalizedKey := strings.ToLower(strings.TrimSpace(key))
		for tagKey, tagValue := range tags {
			if strings.ToLower(strings.TrimSpace(tagKey)) != normalizedKey {
				continue
			}
			tagValue = strings.TrimSpace(tagValue)
			if tagValue != "" {
				return tagValue
			}
		}
	}
	return ""
}

func parseCountTag(value string) int {
	value = strings.TrimSpace(value)
	if value == "" {
		return 0
	}
	parts := strings.Split(value, "/")
	if len(parts) == 0 {
		return 0
	}
	n, err := strconv.Atoi(strings.TrimSpace(parts[0]))
	if err != nil || n <= 0 {
		return 0
	}
	return n
}

func parseYearTag(value string) int {
	value = strings.TrimSpace(value)
	if value == "" {
		return 0
	}
	if len(value) >= 4 {
		if y, err := strconv.Atoi(value[:4]); err == nil && y > 0 {
			return y
		}
	}
	y, err := strconv.Atoi(value)
	if err != nil || y <= 0 {
		return 0
	}
	return y
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

func readEmbeddedPicture(path string) (*tag.Picture, error) {
	m, err := metadataReader(path)
	if err != nil {
		return nil, err
	}
	return m.Picture(), nil
}

func writeExtractedCover(albumDir string, pic *tag.Picture) string {
	if pic == nil || len(pic.Data) == 0 {
		return ""
	}
	ext := strings.ToLower(strings.TrimPrefix(strings.TrimSpace(pic.Ext), "."))
	switch ext {
	case "", "jpg", "jpeg":
		ext = "jpg"
	case "png":
	default:
		ext = "jpg"
	}
	outPath := filepath.Join(albumDir, "extracted_cover."+ext)
	tmpFile, err := os.CreateTemp(albumDir, "extracted_cover-*."+ext+".tmp")
	if err != nil {
		return ""
	}
	tmpPath := tmpFile.Name()
	if _, err := tmpFile.Write(pic.Data); err != nil {
		tmpFile.Close()
		_ = os.Remove(tmpPath)
		return ""
	}
	if err := tmpFile.Chmod(0o644); err != nil {
		tmpFile.Close()
		_ = os.Remove(tmpPath)
		return ""
	}
	if err := tmpFile.Close(); err != nil {
		_ = os.Remove(tmpPath)
		return ""
	}
	if err := os.Rename(tmpPath, outPath); err != nil {
		_ = os.Remove(tmpPath)
		return ""
	}
	return outPath
}

func shouldRefreshWAVExtractedCover(audioPath, coverPath string) bool {
	if !strings.EqualFold(filepath.Ext(audioPath), ".wav") {
		return false
	}
	return isExtractedCoverPath(coverPath)
}

func isExtractedCoverPath(coverPath string) bool {
	base := filepath.Base(coverPath)
	return base == "extracted_cover.jpg" || base == "extracted_cover.png"
}

func removeExtractedCoverOutputs(albumDir string) {
	_ = os.Remove(filepath.Join(albumDir, "extracted_cover.jpg"))
	_ = os.Remove(filepath.Join(albumDir, "extracted_cover.png"))
}

func removeStaleExtractedCoverOutputs(albumDir, keepPath string) {
	for _, name := range []string{"extracted_cover.jpg", "extracted_cover.png"} {
		path := filepath.Join(albumDir, name)
		if path == keepPath {
			continue
		}
		_ = os.Remove(path)
	}
}

// extractCoverFromTrack reads embedded picture from the audio file and writes to albumDir/extracted_cover.<ext>.
// Returns the path to the written file, or "" on failure.
func extractCoverFromTrack(audioPath, albumDir string) string {
	pic, err := embeddedPictureReader(audioPath)
	if err != nil {
		return ""
	}
	if pic != nil && len(pic.Data) > 0 {
		return writeExtractedCover(albumDir, pic)
	}
	if strings.EqualFold(filepath.Ext(audioPath), ".wav") {
		removeExtractedCoverOutputs(albumDir)
		return wavCoverExtractor(audioPath, albumDir)
	}
	return ""
}

func extractCoverFromWAV(audioPath, albumDir string) string {
	outPath := filepath.Join(albumDir, "extracted_cover.png")
	_ = os.Remove(outPath)
	cmd := exec.Command("ffmpeg",
		"-y",
		"-i", audioPath,
		"-an",
		"-c:v", "png",
		"-frames:v", "1",
		outPath,
	)
	if err := cmd.Run(); err != nil {
		log.Printf("scan: ffmpeg cover extraction failed for %s: %v", audioPath, err)
		_ = os.Remove(outPath)
		return ""
	}
	if _, err := os.Stat(outPath); err != nil {
		log.Printf("scan: ffmpeg cover extraction missing output for %s: %v", audioPath, err)
		_ = os.Remove(outPath)
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

// videoConsistencyCheck fixes stale video references on tracks.
// Step 1: Tracks with video_path that no longer exists on disk → clear.
// Step 2: Tracks without video_path whose audio file was in the current scan → check for new MV.
func videoConsistencyCheck(s *store.Store, fileInfos map[string]scanJob) {
	// Step 1: Clear stale video references
	tracksWithVideo, err := s.GetTracksWithVideo()
	if err != nil {
		log.Printf("scan: video check - error querying tracks with video: %v", err)
		return
	}
	cleared := 0
	for _, t := range tracksWithVideo {
		if _, err := os.Stat(t.VideoPath); os.IsNotExist(err) {
			if err := s.ClearTrackVideo(t.ID); err != nil {
				log.Printf("scan: video check - error clearing video for track %d: %v", t.ID, err)
			} else {
				cleared++
			}
		}
	}

	// Step 2: Check tracks without video whose audio was in current scan
	audioPaths := make([]string, 0, len(fileInfos))
	for p := range fileInfos {
		audioPaths = append(audioPaths, p)
	}
	tracksNoVideo, err := s.GetTracksByAudioPaths(audioPaths)
	if err != nil {
		log.Printf("scan: video check - error querying tracks without video: %v", err)
		return
	}
	found := 0
	for _, t := range tracksNoVideo {
		dir := filepath.Dir(t.AudioPath)
		base := strings.TrimSuffix(t.AudioPath, filepath.Ext(t.AudioPath))
		videoPath := findVideoForBase(dir, base)
		if videoPath != "" {
			thumbPath := videoThumbFinder(videoPath)
			if err := s.UpdateTrackVideo(t.ID, videoPath, thumbPath); err != nil {
				log.Printf("scan: video check - error updating video for track %d: %v", t.ID, err)
			} else {
				found++
			}
		}
	}

	if cleared > 0 || found > 0 {
		log.Printf("scan: video consistency - cleared %d stale, found %d new MVs", cleared, found)
	}
}

// scanStandaloneMVs scans mediaRoot/MVs/ for standalone video files.
func scanStandaloneMVs(mediaRoot string, s *store.Store) {
	mvsDir := filepath.Join(mediaRoot, "MVs")
	if _, err := os.Stat(mvsDir); os.IsNotExist(err) {
		return
	}

	existingVideos, err := s.GetAllVideosMeta()
	if err != nil {
		log.Printf("scan: MVs phase - error getting video meta: %v", err)
		return
	}

	var totalFound, newCount, skippedCount int
	var seenPaths []string

	err = filepath.Walk(mvsDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}
		ext := strings.ToLower(filepath.Ext(path))
		if !VideoExts[ext] {
			return nil
		}
		totalFound++
		seenPaths = append(seenPaths, path)

		mtime := info.ModTime().Unix()
		size := info.Size()

		// Check if unchanged
		if existing, ok := existingVideos[path]; ok {
			if existing.ModTime == mtime && existing.Size == size {
				skippedCount++
				return nil
			}
		}

		// Parse artist/title from directory structure: MVs/Artist/filename.ext
		artist := filepath.Base(filepath.Dir(path))
		if artist == "MVs" {
			artist = "" // file directly in MVs/, no artist
		}
		title := strings.TrimSuffix(filepath.Base(path), ext)

		duration, _, _ := ffprobeRunner(path)
		thumbPath := videoThumbFinder(path)

		_, upsertErr := s.UpsertVideo(store.Video{
			Title:           title,
			Artist:          artist,
			Path:            path,
			ThumbPath:       thumbPath,
			DurationSeconds: duration,
			Source:          "scan",
			FileMtime:       mtime,
			FileSize:        size,
		})
		if upsertErr != nil {
			log.Printf("scan: MVs phase - error upserting video %s: %v", path, upsertErr)
		} else {
			newCount++
		}
		return nil
	})
	if err != nil {
		log.Printf("scan: MVs phase - error walking directory: %v", err)
	}

	// Delete detection: standalone scan videos in DB under mvsDir that no longer exist on disk
	seenSet := make(map[string]bool, len(seenPaths))
	for _, p := range seenPaths {
		seenSet[p] = true
	}
	dbStandalone, err := s.GetStandaloneVideoPathsByPrefix(mvsDir + string(os.PathSeparator))
	if err != nil {
		log.Printf("scan: MVs phase - error querying standalone videos: %v", err)
	} else {
		var toDelete []string
		for _, path := range dbStandalone {
			if !seenSet[path] {
				toDelete = append(toDelete, path)
			}
		}
		if len(toDelete) > 0 {
			if err := s.DeleteVideosByPaths(toDelete); err != nil {
				log.Printf("scan: MVs phase - error deleting removed videos: %v", err)
			}
		}
	}

	log.Printf("scan: MVs phase - found %d standalone MVs (%d new, %d skipped)",
		totalFound, newCount, skippedCount)
}
