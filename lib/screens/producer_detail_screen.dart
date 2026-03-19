import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/album.dart';
import '../models/producer.dart';
import '../models/track.dart';
import '../theme/app_theme.dart';
import '../widgets/producer_detail/discography_grid.dart';
import '../widgets/producer_detail/featured_mvs_grid.dart';
import '../widgets/producer_detail/producer_hero_section.dart';
import '../widgets/producer_detail/producer_tab_bar.dart';
import '../widgets/producer_detail/producer_track_list.dart';
import 'album_detail_screen.dart';

class ProducerDetailScreen extends StatefulWidget {
  ProducerDetailScreen({
    super.key,
    required this.producer,
    this.baseUrl = '',
    this.onAlbumTap,
    this.onPlayTrack,
  });

  final Producer producer;
  final String baseUrl;
  String get _effectiveBaseUrl =>
      baseUrl.isEmpty ? ApiConfig.defaultBaseUrl : baseUrl;
  final ValueChanged<Album>? onAlbumTap;
  final void Function(Track track, List<Track> queue, int index)? onPlayTrack;

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

  Producer get _displayProducer => _loadedProducer ?? widget.producer;

  @override
  void initState() {
    super.initState();
    _loadProducer();
  }

  Future<void> _loadProducer() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiClient(baseUrl: widget._effectiveBaseUrl)
          .getProducer(widget.producer.id);
      if (result == null || !mounted) return;
      setState(() {
        _loadedProducer = result.producer;
        _albums = result.albums;
        _tracks = result.tracks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Track> get _tracksWithMv =>
      _tracks.where((t) => t.videoPath.isNotEmpty).toList();

  void _playTrack(Track track, int index, {List<Track>? queue}) {
    widget.onPlayTrack?.call(track, queue ?? _tracks, index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.mikuDark,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: ProducerHeroSection(
                    producer: _displayProducer,
                    baseUrl: widget._effectiveBaseUrl,
                  ),
                ),
                SliverToBoxAdapter(
                  child: ProducerTabBar(
                    index: _tabIndex,
                    onTap: (i) => setState(() => _tabIndex = i),
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
                                child: const Text('Retry')),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(48),
                    sliver: _tabIndex == 0
                        ? SliverList(
                            delegate: SliverChildListDelegate([
                              const _SectionTitle('Discography'),
                              const SizedBox(height: 32),
                              DiscographyGrid(
                                albums: _albums,
                                onAlbumTap: (album) {
                                  if (widget.onAlbumTap != null) {
                                    widget.onAlbumTap!(album);
                                  } else {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (context) => AlbumDetailScreen(
                                          album: album,
                                          baseUrl: widget._effectiveBaseUrl,
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
                                  const _SectionTitle('All Tracks'),
                                  const SizedBox(height: 8),
                                  ProducerTrackList(
                                    tracks: _tracks,
                                    baseUrl: widget._effectiveBaseUrl,
                                    onPlay: (track, index) =>
                                        _playTrack(track, index),
                                  ),
                                ]),
                              )
                            : SliverList(
                                delegate: SliverChildListDelegate([
                                  const _SectionTitle('Featured MVs'),
                                  const SizedBox(height: 8),
                                  FeaturedMvsGrid(
                                    tracks: _tracksWithMv,
                                    baseUrl: widget._effectiveBaseUrl,
                                    onPlay: (track, index) => _playTrack(
                                        track, index,
                                        queue: _tracksWithMv),
                                  ),
                                ]),
                              ),
                  ),
              ],
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
        Container(
          width: 32,
          height: 2,
          color: AppTheme.mikuGreen,
        ),
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
