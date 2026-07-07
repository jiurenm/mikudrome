package store

import (
	"crypto/sha256"
	"encoding/binary"
	"sort"
	"time"
)

const (
	defaultDailyRecommendationLimit = 20
	playbackCooldownSeconds         = 7 * 24 * 60 * 60
	playbackRecoverySeconds         = 30 * 24 * 60 * 60
	playbackCooldownPenalty         = 4.0
)

type recommendationCandidate struct {
	Track    Track
	Favorite bool
	PlayedAt int64
	Score    float64
}

// DailyRecommendations returns a deterministic recommendation queue for the
// server-local date represented by now.
func (s *Store) DailyRecommendations(now time.Time, limit int) ([]Track, error) {
	if limit <= 0 {
		limit = defaultDailyRecommendationLimit
	}
	localNow := now.Local()
	date := localNow.Format("2006-01-02")
	scoreAnchor := recommendationDateAnchor(localNow)
	candidates, err := s.listRecommendationCandidates()
	if err != nil {
		return nil, err
	}
	for i := range candidates {
		candidates[i].Score = recommendationScore(candidates[i], date, scoreAnchor)
	}
	sort.SliceStable(candidates, func(i, j int) bool {
		if candidates[i].Score == candidates[j].Score {
			return candidates[i].Track.ID < candidates[j].Track.ID
		}
		return candidates[i].Score > candidates[j].Score
	})
	candidates = capDailyRecommendationFavorites(candidates, limit)
	tracks := make([]Track, len(candidates))
	for i, candidate := range candidates {
		tracks[i] = candidate.Track
	}
	return tracks, nil
}

func (s *Store) listRecommendationCandidates() ([]recommendationCandidate, error) {
	rows, err := s.db.Query(
		`SELECT ` + trackSelectColumns("t", "a") + `,
		        CASE WHEN f.track_id IS NULL THEN 0 ELSE 1 END,
		        COALESCE(h.played_at, 0)
		   FROM tracks t
		   LEFT JOIN albums a ON t.album_id = a.id
		   LEFT JOIN favorites f ON f.track_id = t.id
		   LEFT JOIN playback_history h ON h.track_id = t.id
		  WHERE TRIM(COALESCE(t.audio_path, '')) != ''`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []recommendationCandidate
	for rows.Next() {
		var candidate recommendationCandidate
		var favorite int
		dest := append(trackScanDest(&candidate.Track), &favorite, &candidate.PlayedAt)
		if err := rows.Scan(dest...); err != nil {
			return nil, err
		}
		candidate.Favorite = favorite == 1
		out = append(out, candidate)
	}
	return out, rows.Err()
}

func capDailyRecommendationFavorites(candidates []recommendationCandidate, limit int) []recommendationCandidate {
	favoriteLimit := dailyRecommendationFavoriteLimit(limit)
	out := make([]recommendationCandidate, 0, recommendationResultCapacity(candidates, limit))
	favoriteCount := 0
	for _, candidate := range candidates {
		if len(out) == limit {
			break
		}
		if candidate.Favorite {
			if favoriteCount == favoriteLimit {
				continue
			}
			favoriteCount++
		}
		out = append(out, candidate)
	}
	return out
}

func dailyRecommendationFavoriteLimit(limit int) int {
	favoriteLimit := limit / 4
	if favoriteLimit < 1 {
		return 1
	}
	return favoriteLimit
}

func recommendationResultCapacity(candidates []recommendationCandidate, limit int) int {
	if len(candidates) < limit {
		return len(candidates)
	}
	return limit
}

func recommendationDateAnchor(localNow time.Time) time.Time {
	year, month, day := localNow.Date()
	return time.Date(year, month, day, 0, 0, 0, 0, localNow.Location())
}

func recommendationScore(candidate recommendationCandidate, date string, scoreAnchor time.Time) float64 {
	score := stableDailyScore(date, candidate.Track.ID)
	if candidate.Favorite {
		score += 3.0
	}
	if candidate.PlayedAt > 0 {
		score -= playbackHistoryPenalty(candidate.PlayedAt, scoreAnchor)
	}
	if candidate.Track.VideoPath != "" {
		score += 0.15
	}
	if candidate.Track.Composer != "" || candidate.Track.Lyricist != "" || candidate.Track.Vocal != "" {
		score += 0.10
	}
	return score
}

func playbackHistoryPenalty(playedAt int64, scoreAnchor time.Time) float64 {
	age := scoreAnchor.Unix() - playedAt
	if age < 0 {
		age = 0
	}
	if age >= playbackRecoverySeconds {
		return 0
	}
	if age <= playbackCooldownSeconds {
		return playbackCooldownPenalty
	}
	recoveryProgress := float64(age-playbackCooldownSeconds) /
		float64(playbackRecoverySeconds-playbackCooldownSeconds)
	return playbackCooldownPenalty * (1 - recoveryProgress)
}

func stableDailyScore(date string, trackID int64) float64 {
	var input [40]byte
	copy(input[:], date)
	binary.BigEndian.PutUint64(input[32:], uint64(trackID))
	sum := sha256.Sum256(input[:])
	value := binary.BigEndian.Uint64(sum[:8])
	return float64(value) / float64(^uint64(0))
}
