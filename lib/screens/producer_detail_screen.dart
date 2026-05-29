import 'dart:math';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/album.dart';
import '../models/producer.dart';
import '../models/track.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/producer_detail/discography_grid.dart';
import '../widgets/producer_detail/featured_mvs_grid.dart';
import '../widgets/producer_detail/producer_detail_data_cache.dart';
import '../widgets/producer_detail/producer_hero_section.dart';
import '../widgets/producer_detail/producer_tab_bar.dart';
import '../widgets/producer_detail/producer_track_list.dart';
import 'album_detail_screen.dart';
import 'player_playback_policy.dart';

class ProducerDetailScreen extends StatefulWidget {
  const ProducerDetailScreen({
    super.key,
    required this.producer,
    this.baseUrl = '',
    this.onBack,
    this.onAlbumTap,
    this.onPlayTrack,
  });

  final Producer producer;
  final String baseUrl;
  final VoidCallback? onBack;
  String get _effectiveBaseUrl =>
      baseUrl.isEmpty ? ApiConfig.defaultBaseUrl : baseUrl;
  final ValueChanged<Album>? onAlbumTap;
  final void Function(
    Track track,
    List<Track> queue,
    int index, {
    PlaybackStartIntent intent,
  })?
  onPlayTrack;

  @override
  State<ProducerDetailScreen> createState() => _ProducerDetailScreenState();
}

class _ProducerDetailScreenState extends State<ProducerDetailScreen> {
  int _tabIndex = 0;
  Producer? _loadedProducer;
  List<Album> _albums = [];
  List<Track> _tracks = [];
  bool _loading = true;
  String? _error;
  String? _refreshError;

  Producer get _displayProducer => _loadedProducer ?? widget.producer;

  bool get _hasDetailData =>
      _loadedProducer != null || _albums.isNotEmpty || _tracks.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final cached = ProducerDetailDataCache.read(
      baseUrl: widget._effectiveBaseUrl,
      producerId: widget.producer.id,
    );
    if (cached != null) {
      _applyProducerDetailData(cached);
    } else {
      _loadProducer();
    }
  }

  void _applyProducerDetailData(ProducerDetailData data) {
    setState(() {
      _loadedProducer = data.producer;
      _albums = data.albums;
      _tracks = data.tracks;
      _loading = false;
      _error = null;
      _refreshError = null;
    });
  }

  Future<void> _loadProducer({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await ApiClient(
        baseUrl: widget._effectiveBaseUrl,
      ).getProducer(widget.producer.id);
      if (result == null) {
        throw StateError('Producer not found');
      }
      final data = ProducerDetailData(
        producer: result.producer,
        albums: result.albums,
        tracks: result.tracks,
      );
      ProducerDetailDataCache.write(
        baseUrl: widget._effectiveBaseUrl,
        producerId: widget.producer.id,
        data: data,
      );
      if (!mounted) return;
      _applyProducerDetailData(data);
    } catch (e) {
      if (!mounted) return;
      if (_hasDetailData) {
        setState(() {
          _refreshError = '刷新失败，请稍后再试';
          _loading = false;
        });
        return;
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refreshProducer() {
    return _loadProducer(showLoading: false);
  }

  List<Track> get _tracksWithMv =>
      _tracks.where((t) => t.videoPath.isNotEmpty).toList();

  int get _displayAlbumCount =>
      _albums.isNotEmpty ? _albums.length : _displayProducer.albumCount;

  int get _displayTrackCount =>
      _tracks.isNotEmpty ? _tracks.length : _displayProducer.trackCount;

  void _playTrack(
    Track track,
    int index, {
    List<Track>? queue,
    PlaybackStartIntent intent = PlaybackStartIntent.audio,
  }) {
    widget.onPlayTrack?.call(track, queue ?? _tracks, index, intent: intent);
  }

  void _playAll() {
    if (_tracks.isEmpty) return;
    _playTrack(_tracks.first, 0);
  }

  void _shufflePlay() {
    if (_tracks.isEmpty) return;
    final shuffled = List<Track>.from(_tracks);
    shuffled.shuffle(Random());
    _playTrack(shuffled.first, 0, queue: shuffled);
  }

  List<Widget> _mobileRefreshErrorWidgets(BuildContext context) {
    if (!isMobile(context) || _refreshError == null) return const [];
    return [
      _RefreshErrorBanner(message: _refreshError!),
      const SizedBox(height: 12),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.mikuDark,
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshProducer,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (isMobile(context) && widget.onBack != null)
                    SliverAppBar(
                      key: const ValueKey('producer-detail-mobile-app-bar'),
                      backgroundColor: AppTheme.cardBg,
                      pinned: true,
                      floating: false,
                      elevation: 0,
                      leading: IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: widget.onBack,
                      ),
                      title: Text(
                        _displayProducer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: ProducerHeroSection(
                      producer: _displayProducer,
                      baseUrl: widget._effectiveBaseUrl,
                      onPlayAll: _playAll,
                      onShuffle: _shufflePlay,
                      hasTracks: _tracks.isNotEmpty,
                      albumCount: _displayAlbumCount,
                      trackCount: _displayTrackCount,
                      mvCount: _tracksWithMv.length,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: ProducerTabBar(
                      index: _tabIndex,
                      onTap: (i) => setState(() => _tabIndex = i),
                      albumCount: _displayAlbumCount,
                      trackCount: _displayTrackCount,
                      mvCount: _tracksWithMv.length,
                    ),
                  ),
                  if (_loading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _loadProducer,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        isMobile(context) ? 16 : 48,
                        isMobile(context) ? 4 : 48,
                        isMobile(context) ? 16 : 48,
                        88,
                      ),
                      sliver: _tabIndex == 0
                          ? SliverList(
                              delegate: SliverChildListDelegate([
                                ..._mobileRefreshErrorWidgets(context),
                                if (!isMobile(context))
                                  const _SectionTitle('Discography'),
                                if (!isMobile(context))
                                  const SizedBox(height: 32),
                                DiscographyGrid(
                                  albums: _albums,
                                  onAlbumTap: (album) {
                                    if (widget.onAlbumTap != null) {
                                      widget.onAlbumTap!(album);
                                    } else {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (context) =>
                                              AlbumDetailScreen(
                                                album: album,
                                                baseUrl:
                                                    widget._effectiveBaseUrl,
                                              ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ]),
                            )
                          : _tabIndex == 1
                          ? SliverList(
                              delegate: SliverChildListDelegate([
                                ..._mobileRefreshErrorWidgets(context),
                                if (!isMobile(context))
                                  const _SectionTitle('All Tracks'),
                                if (!isMobile(context))
                                  const SizedBox(height: 8),
                                ProducerTrackList(
                                  tracks: _tracks,
                                  baseUrl: widget._effectiveBaseUrl,
                                  useMobileLayout: true,
                                  onPlay:
                                      (
                                        track,
                                        index, {
                                        intent = PlaybackStartIntent.audio,
                                      }) => _playTrack(
                                        track,
                                        index,
                                        intent: intent,
                                      ),
                                ),
                              ]),
                            )
                          : SliverList(
                              delegate: SliverChildListDelegate([
                                ..._mobileRefreshErrorWidgets(context),
                                if (!isMobile(context))
                                  const _SectionTitle('Featured MVs'),
                                if (!isMobile(context))
                                  const SizedBox(height: 8),
                                FeaturedMvsGrid(
                                  tracks: _tracksWithMv,
                                  baseUrl: widget._effectiveBaseUrl,
                                  onPlay: (track, index) => _playTrack(
                                    track,
                                    index,
                                    queue: _tracksWithMv,
                                    intent: PlaybackStartIntent.video,
                                  ),
                                ),
                              ]),
                            ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshErrorBanner extends StatelessWidget {
  const _RefreshErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 32, height: 2, color: AppTheme.mikuGreen),
        const SizedBox(width: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
