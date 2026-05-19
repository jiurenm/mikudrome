import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/playback_history_item.dart';
import '../models/track.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/playlist_detail/playlist_track_row.dart';

class RecentPlaybackScreen extends StatefulWidget {
  const RecentPlaybackScreen({
    super.key,
    this.client,
    this.onBack,
    this.onPlayTrack,
    this.onAddToQueue,
    this.currentPlayingTrackId,
    this.isPlaying = false,
  });

  final ApiClient? client;
  final VoidCallback? onBack;
  final void Function(Track track)? onPlayTrack;
  final void Function(Track track)? onAddToQueue;
  final int? currentPlayingTrackId;
  final bool isPlaying;

  @override
  State<RecentPlaybackScreen> createState() => _RecentPlaybackScreenState();
}

class _RecentPlaybackScreenState extends State<RecentPlaybackScreen> {
  late final ApiClient _client = widget.client ?? ApiClient();
  late Future<List<PlaybackHistoryItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _client.getPlaybackHistory(limit: 50);
  }

  void _reload() {
    setState(() {
      _itemsFuture = _client.getPlaybackHistory(limit: 50);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    return Scaffold(
      backgroundColor: AppTheme.mikuDark,
      body: CustomScrollView(
        slivers: [
          if (mobile && widget.onBack != null)
            SliverAppBar(
              backgroundColor: AppTheme.mikuDark,
              pinned: false,
              floating: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              title: const Text('最近播放', style: TextStyle(fontSize: 16)),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                mobile ? 16 : 40,
                mobile ? 20 : 36,
                mobile ? 16 : 40,
                12,
              ),
              child: const Text(
                '最近播放',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
          ),
          FutureBuilder<List<PlaybackHistoryItem>>(
            future: _itemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '最近播放加载失败',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _reload,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      '暂无最近播放记录',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  mobile ? 8 : 32,
                  8,
                  mobile ? 8 : 32,
                  96,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final track = items[index].track;
                    return PlaylistTrackRow.track(
                      key: ValueKey('recent-playback-${track.id}'),
                      track: track,
                      baseUrl: _client.baseUrl,
                      onTap: () => widget.onPlayTrack?.call(track),
                      onAddToQueue: () => widget.onAddToQueue?.call(track),
                      isCurrentlyPlaying:
                          widget.currentPlayingTrackId == track.id &&
                          widget.isPlaying,
                    );
                  }, childCount: items.length),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
