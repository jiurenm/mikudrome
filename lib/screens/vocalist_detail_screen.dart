import 'dart:math';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/album.dart';
import '../models/track.dart';
import '../models/vocalist.dart';
import '../theme/app_theme.dart';
import '../theme/vocal_theme.dart';
import '../utils/responsive.dart';
import '../widgets/producer_detail/discography_grid.dart';
import '../widgets/producer_detail/featured_mvs_grid.dart';
import '../widgets/producer_detail/producer_track_list.dart';
import '../widgets/vocalist_detail/vocalist_hero_section.dart';
import '../widgets/vocalist_detail/vocalist_tab_bar.dart';
import 'album_detail_screen.dart';
import 'player_playback_policy.dart';

class VocalistDetailScreen extends StatefulWidget {
  const VocalistDetailScreen({
    super.key,
    required this.vocalist,
    this.onBack,
    this.onAlbumTap,
    this.onPlayTrack,
  });

  final Vocalist vocalist;
  final VoidCallback? onBack;
  final ValueChanged<Album>? onAlbumTap;
  final void Function(
    Track track,
    List<Track> queue,
    int index, {
    PlaybackStartIntent intent,
  })?
  onPlayTrack;

  @override
  State<VocalistDetailScreen> createState() => _VocalistDetailScreenState();
}

class _VocalistDetailScreenState extends State<VocalistDetailScreen> {
  int _tabIndex = 0;
  String? _loadedName;
  List<Album> _albums = [];
  List<Track> _tracks = [];
  bool _loading = true;
  bool _hasLoadedDetail = false;
  String? _error;
  String? _refreshError;

  String get _displayName => _loadedName ?? widget.vocalist.name;

  int get _displayTrackCount =>
      _hasLoadedDetail ? _tracks.length : widget.vocalist.trackCount;

  int get _displayAlbumCount =>
      _hasLoadedDetail ? _albums.length : widget.vocalist.albumCount;

  List<Track> get _tracksWithMv =>
      _tracks.where((track) => track.videoPath.isNotEmpty).toList();

  List<Widget> _mobileRefreshErrorWidgets(BuildContext context) {
    if (!(isMobile(context) || isMobileSurface(context)) ||
        _refreshError == null) {
      return const [];
    }
    return [
      _RefreshErrorBanner(message: _refreshError!),
      const SizedBox(height: 12),
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await ApiClient().getVocalistTracks(widget.vocalist.name);
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _error = 'Vocalist not found';
          _loading = false;
        });
        return;
      }
      setState(() {
        _loadedName = result.name;
        _tracks = result.tracks;
        _albums = result.albums;
        _hasLoadedDetail = true;
        _loading = false;
        _error = null;
        _refreshError = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_hasLoadedDetail) {
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

  Future<void> _refreshData() {
    return _loadData(showLoading: false);
  }

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
    _playTrack(shuffled.first, 0);
  }

  void _shufflePlayWithShuffledQueue() {
    if (_tracks.isEmpty) return;
    final shuffled = List<Track>.from(_tracks);
    shuffled.shuffle(Random());
    _playTrack(shuffled.first, 0, queue: shuffled);
  }

  double _mobileLandscapeHeroWidth(BuildContext context) {
    return (MediaQuery.sizeOf(context).width * 0.3)
        .clamp(240.0, 360.0)
        .toDouble();
  }

  Widget _buildMobileBackControl(BuildContext context) {
    if (widget.onBack == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        icon: const Icon(Icons.chevron_left),
        color: AppTheme.textPrimary,
        onPressed: widget.onBack,
        tooltip: 'Back',
      ),
    );
  }

  Widget _buildMobileHero(BuildContext context, Color color) {
    return VocalistHeroSection(
      name: _displayName,
      avatarUrl: ApiClient().vocalistAvatarUrl(widget.vocalist.name),
      color: color,
      trackCount: _displayTrackCount,
      albumCount: _displayAlbumCount,
      mvCount: _tracksWithMv.length,
      hasTracks: _tracks.isNotEmpty,
      onPlayAll: _playAll,
      onShuffle: _shufflePlayWithShuffledQueue,
    );
  }

  Widget _buildMobilePrimaryActions(BuildContext context) {
    return const SizedBox.shrink();
  }

  Widget _buildMobileLandscapeHeroColumn(BuildContext context, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMobileBackControl(context),
        const SizedBox(height: 12),
        _buildMobileHero(context, color),
        const SizedBox(height: 14),
        _buildMobilePrimaryActions(context),
      ],
    );
  }

  Widget _buildMobileScrollableContent(BuildContext context, Color color) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: VocalistTabBar(
              index: _tabIndex,
              onTap: (i) => setState(() => _tabIndex = i),
              albumCount: _displayAlbumCount,
              trackCount: _displayTrackCount,
              mvCount: _tracksWithMv.length,
              color: color,
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: _MobileInitialError(message: _error!, onRetry: _loadData),
            )
          else
            _buildMobileTabSliver(context),
        ],
      ),
    );
  }

  Widget _buildMobileLandscapeContentColumn(BuildContext context, Color color) {
    return _buildMobileScrollableContent(context, color);
  }

  Widget _buildMobileLandscape(BuildContext context, Color color) {
    return Scaffold(
      backgroundColor: AppTheme.mikuDark,
      body: SafeArea(
        child: Row(
          key: const ValueKey('vocalist-detail-mobile-landscape'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _mobileLandscapeHeroWidth(context),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 20),
                child: _buildMobileLandscapeHeroColumn(context, color),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 18, 20),
                child: _buildMobileLandscapeContentColumn(context, color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = VocalColors.colorForName(widget.vocalist.name);

    if (isNativePhoneLandscapeSurface(context)) {
      return _buildMobileLandscape(context, color);
    }

    final mobile = isMobile(context);

    if (mobile) {
      return _buildMobile(context, color);
    }

    return Scaffold(
      backgroundColor: AppTheme.mikuDark,
      body: CustomScrollView(
        slivers: [
          // Hero section
          SliverToBoxAdapter(
            child: _VocalistHero(
              vocalist: widget.vocalist,
              color: color,
              trackCount: _tracks.length,
              albumCount: _albums.length,
              onShuffle: _shufflePlay,
              hasTracks: _tracks.isNotEmpty,
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
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.all(mobile ? 16 : 48),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_albums.isNotEmpty) ...[
                    _SectionTitle('Albums', color: color),
                    const SizedBox(height: 24),
                    DiscographyGrid(
                      albums: _albums,
                      onAlbumTap: (album) {
                        if (widget.onAlbumTap != null) {
                          widget.onAlbumTap!(album);
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  AlbumDetailScreen(album: album),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                  _SectionTitle('All Tracks', color: color),
                  const SizedBox(height: 8),
                  ProducerTrackList(
                    tracks: _tracks,
                    baseUrl: ApiConfig.defaultBaseUrl,
                    onPlay:
                        (track, index, {intent = PlaybackStartIntent.audio}) =>
                            _playTrack(track, index, intent: intent),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context, Color color) {
    return Scaffold(
      backgroundColor: AppTheme.mikuDark,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.onBack != null)
              SliverAppBar(
                key: const ValueKey('vocalist-detail-mobile-app-bar'),
                backgroundColor: AppTheme.cardBg,
                pinned: true,
                floating: false,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: widget.onBack,
                ),
                title: Text(
                  _displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            SliverToBoxAdapter(
              child: VocalistHeroSection(
                name: _displayName,
                avatarUrl: ApiClient().vocalistAvatarUrl(widget.vocalist.name),
                color: color,
                trackCount: _displayTrackCount,
                albumCount: _displayAlbumCount,
                mvCount: _tracksWithMv.length,
                hasTracks: _tracks.isNotEmpty,
                onPlayAll: _playAll,
                onShuffle: _shufflePlayWithShuffledQueue,
              ),
            ),
            SliverToBoxAdapter(
              child: VocalistTabBar(
                index: _tabIndex,
                onTap: (i) => setState(() => _tabIndex = i),
                albumCount: _displayAlbumCount,
                trackCount: _displayTrackCount,
                mvCount: _tracksWithMv.length,
                color: color,
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: _MobileInitialError(
                  message: _error!,
                  onRetry: _loadData,
                ),
              )
            else
              _buildMobileTabSliver(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTabSliver(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          ..._mobileRefreshErrorWidgets(context),
          if (_tabIndex == 0)
            DiscographyGrid(
              albums: _albums,
              onAlbumTap: (album) {
                if (widget.onAlbumTap != null) {
                  widget.onAlbumTap!(album);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => AlbumDetailScreen(album: album),
                    ),
                  );
                }
              },
            )
          else if (_tabIndex == 1)
            ProducerTrackList(
              tracks: _tracks,
              baseUrl: ApiConfig.defaultBaseUrl,
              useMobileLayout: true,
              onPlay: (track, index, {intent = PlaybackStartIntent.audio}) =>
                  _playTrack(track, index, intent: intent),
            )
          else
            FeaturedMvsGrid(
              tracks: _tracksWithMv,
              baseUrl: ApiConfig.defaultBaseUrl,
              onPlay: (track, index) => _playTrack(
                track,
                index,
                queue: _tracksWithMv,
                intent: PlaybackStartIntent.video,
              ),
            ),
        ]),
      ),
    );
  }
}

class _VocalistHero extends StatelessWidget {
  const _VocalistHero({
    required this.vocalist,
    required this.color,
    required this.trackCount,
    required this.albumCount,
    required this.onShuffle,
    required this.hasTracks,
  });

  final Vocalist vocalist;
  final Color color;
  final int trackCount;
  final int albumCount;
  final VoidCallback onShuffle;
  final bool hasTracks;

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        mobile ? 24 : 64,
        mobile ? 24 : 48,
        mobile ? 24 : 64,
        mobile ? 24 : 40,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.15), AppTheme.mikuDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: mobile ? 28 : 40,
                backgroundColor: color.withValues(alpha: 0.15),
                foregroundImage: NetworkImage(
                  ApiClient().vocalistAvatarUrl(vocalist.name),
                  headers: ApiConfig.defaultHeaders,
                ),
                onForegroundImageError: (_, __) {},
                child: Icon(Icons.mic, size: mobile ? 28 : 40, color: color),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vocalist.name,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: color, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '$trackCount tracks',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textMuted),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppTheme.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$albumCount albums',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (hasTracks)
            FilledButton.icon(
              onPressed: onShuffle,
              icon: const Icon(Icons.shuffle, size: 18),
              label: const Text('Shuffle Play'),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.color = AppTheme.mikuGreen});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 32, height: 2, color: color),
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

class _MobileInitialError extends StatelessWidget {
  const _MobileInitialError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
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
