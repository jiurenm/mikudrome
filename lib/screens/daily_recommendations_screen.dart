import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/daily_recommendations.dart';
import '../models/track.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/playlist_detail/playlist_track_row.dart';

class DailyRecommendationsScreen extends StatefulWidget {
  const DailyRecommendationsScreen({
    super.key,
    this.client,
    this.onBack,
    this.onPlayTrack,
    this.currentPlayingTrackId,
    this.isPlaying = false,
  });

  final ApiClient? client;
  final VoidCallback? onBack;
  final void Function(Track track, List<Track> queue, int index)? onPlayTrack;
  final int? currentPlayingTrackId;
  final bool isPlaying;

  @override
  State<DailyRecommendationsScreen> createState() =>
      _DailyRecommendationsScreenState();
}

class _DailyRecommendationsScreenState
    extends State<DailyRecommendationsScreen> {
  late final ApiClient _client = widget.client ?? ApiClient();
  late Future<DailyRecommendations> _future;

  @override
  void initState() {
    super.initState();
    _future = _client.getDailyRecommendations();
  }

  Future<void> _reload() async {
    final future = _client.getDailyRecommendations();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {
      // The FutureBuilder renders the error state from _future.
    }
  }

  void _playTrack(List<Track> tracks, int index) {
    if (tracks.isEmpty || index < 0 || index >= tracks.length) return;
    widget.onPlayTrack?.call(tracks[index], tracks, index);
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    return Scaffold(
      backgroundColor: AppTheme.mikuDark,
      body: FutureBuilder<DailyRecommendations>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _DailyRecommendationsError(onRetry: _reload);
          }
          final recommendations = snapshot.data;
          final tracks = recommendations?.tracks ?? const <Track>[];
          return RefreshIndicator(
            onRefresh: _reload,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (mobile && widget.onBack != null)
                  SliverAppBar(
                    backgroundColor: AppTheme.mikuDark,
                    floating: true,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: widget.onBack,
                    ),
                    title: const Text('每日推荐', style: TextStyle(fontSize: 16)),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      mobile ? 16 : 40,
                      mobile ? 20 : 36,
                      mobile ? 16 : 40,
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '每日推荐',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          recommendations?.date ?? '',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: tracks.isEmpty
                              ? null
                              : () => _playTrack(tracks, 0),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('播放全部'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (tracks.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        '暂无推荐歌曲',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      mobile ? 8 : 32,
                      8,
                      mobile ? 8 : 32,
                      96,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final track = tracks[index];
                        return PlaylistTrackRow.track(
                          key: ValueKey('daily-recommendation-${track.id}'),
                          track: track,
                          baseUrl: _client.baseUrl,
                          onTap: () => _playTrack(tracks, index),
                          isCurrentlyPlaying:
                              widget.currentPlayingTrackId == track.id &&
                              widget.isPlaying,
                        );
                      }, childCount: tracks.length),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DailyRecommendationsError extends StatelessWidget {
  const _DailyRecommendationsError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '每日推荐加载失败',
            style: TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
