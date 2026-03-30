import 'package:flutter/material.dart';

import '../../models/track.dart';
import '../../theme/app_theme.dart';
import 'album_track_row.dart';

class AlbumTrackList extends StatelessWidget {
  const AlbumTrackList({
    super.key,
    required this.tracks,
    required this.isMultiDisc,
    required this.tracksByDisc,
    required this.baseUrl,
    required this.onDownloadComplete,
    required this.onPlayTrack,
    required this.showTopMessage,
    this.currentPlayingTrackId,
    this.isPlaying = false,
  });

  final List<Track> tracks;
  final bool isMultiDisc;
  final Map<int, List<Track>> tracksByDisc;
  final String baseUrl;
  final VoidCallback onDownloadComplete;
  final void Function(Track track, int index, {List<Track>? queue}) onPlayTrack;
  final AlbumTopMessage showTopMessage;
  final int? currentPlayingTrackId;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 80),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          if (isMultiDisc)
            ...tracksByDisc.entries.expand((entry) {
              final discNumber = entry.key;
              final discTracks = entry.value;
              return [
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 12, left: 16),
                  child: Text(
                    'Disc $discNumber',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.mikuGreen,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const _TrackListHeader(),
                ...discTracks.asMap().entries.map(
                      (e) => AlbumTrackRow(
                        index: e.key + 1,
                        track: e.value,
                        baseUrl: baseUrl,
                        onDownloadComplete: onDownloadComplete,
                        onPlay: () =>
                            onPlayTrack(e.value, e.key, queue: discTracks),
                        showTopMessage: showTopMessage,
                        isCurrentlyPlaying:
                            e.value.id == currentPlayingTrackId,
                        isPlaying: e.value.id == currentPlayingTrackId && isPlaying,
                      ),
                    ),
              ];
            })
          else ...[
            const _TrackListHeader(),
            ...tracks.asMap().entries.map(
                  (e) => AlbumTrackRow(
                    index: e.key + 1,
                    track: e.value,
                    baseUrl: baseUrl,
                    onDownloadComplete: onDownloadComplete,
                    onPlay: () => onPlayTrack(e.value, e.key),
                    showTopMessage: showTopMessage,
                    isCurrentlyPlaying: e.value.id == currentPlayingTrackId,
                    isPlaying: e.value.id == currentPlayingTrackId && isPlaying,
                  ),
                ),
          ],
        ]),
      ),
    );
  }
}

class _TrackListHeader extends StatelessWidget {
  const _TrackListHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text('#', style: _headerStyle(context))),
          const SizedBox(width: 16),
          Expanded(
            flex: 6,
            child: Text('Title / Vocalists', style: _headerStyle(context)),
          ),
          Expanded(
            flex: 3,
            child:
                Center(child: Text('Tags / MV', style: _headerStyle(context))),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 48,
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  Icon(Icons.access_time, size: 12, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle? _headerStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.textMuted,
        );
  }
}
