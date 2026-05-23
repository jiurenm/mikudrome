import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/album.dart';
import '../models/daily_recommendations.dart';
import '../models/producer.dart';
import '../models/video.dart';
import '../models/vocalist.dart';
import '../screens/albums_screen.dart';
import '../screens/mv_gallery_screen.dart';
import '../screens/producers_screen.dart';
import '../screens/vocalists_screen.dart';
import '../theme/app_theme.dart';
import '../theme/vocal_theme.dart';
import '../utils/responsive.dart';
import 'discover/discover_data_cache.dart';

enum DiscoverSection { albums, producers, vocalists, mv }

const int _mobileDiscoverAlbumLimit = 5;

@visibleForTesting
List<Album> pickMobileDiscoverAlbums(
  List<Album> albums, {
  Random? random,
  int limit = _mobileDiscoverAlbumLimit,
}) {
  if (albums.length <= limit) {
    return List<Album>.unmodifiable(albums);
  }
  final shuffled = List<Album>.from(albums)..shuffle(random ?? Random());
  return List<Album>.unmodifiable(shuffled.take(limit));
}

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    this.currentSection,
    this.onSectionChanged,
    this.child,
    this.showSectionTabs = true,
    this.preferMobileHome = false,
    this.onMobileMoreSelected,
    this.onMobileAlbumSelected,
    this.onMobileProducerSelected,
    this.onMobileVocalistSelected,
    this.onDailyRecommendationsSelected,
  });

  final DiscoverSection? currentSection;
  final ValueChanged<DiscoverSection>? onSectionChanged;
  final Widget? child;
  final bool showSectionTabs;
  final bool preferMobileHome;
  final ValueChanged<DiscoverSection>? onMobileMoreSelected;
  final ValueChanged<Album>? onMobileAlbumSelected;
  final ValueChanged<Producer>? onMobileProducerSelected;
  final ValueChanged<Vocalist>? onMobileVocalistSelected;
  final VoidCallback? onDailyRecommendationsSelected;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  DiscoverSection _section = DiscoverSection.albums;

  DiscoverSection get _currentSection => widget.currentSection ?? _section;

  void _selectSection(Set<DiscoverSection> selection) {
    final section = selection.first;
    widget.onSectionChanged?.call(section);
    if (widget.currentSection == null) {
      setState(() {
        _section = section;
      });
    }
  }

  Widget _defaultContent() {
    return switch (_currentSection) {
      DiscoverSection.albums => AlbumsScreen(),
      DiscoverSection.producers => const ProducersScreen(),
      DiscoverSection.vocalists => const VocalistsScreen(),
      DiscoverSection.mv => const MvGalleryScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showSectionTabs &&
        isMobile(context) &&
        (widget.child == null || widget.preferMobileHome)) {
      return _MobileDiscoverHome(
        onMoreSelected: widget.onMobileMoreSelected,
        onAlbumSelected: widget.onMobileAlbumSelected,
        onProducerSelected: widget.onMobileProducerSelected,
        onVocalistSelected: widget.onMobileVocalistSelected,
        onDailyRecommendationsSelected: widget.onDailyRecommendationsSelected,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showSectionTabs)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: SegmentedButton<DiscoverSection>(
              segments: const [
                ButtonSegment<DiscoverSection>(
                  value: DiscoverSection.albums,
                  icon: Icon(Icons.album_outlined),
                  label: Text('专辑'),
                ),
                ButtonSegment<DiscoverSection>(
                  value: DiscoverSection.producers,
                  icon: Icon(Icons.person_search_outlined),
                  label: Text('P主'),
                ),
                ButtonSegment<DiscoverSection>(
                  value: DiscoverSection.vocalists,
                  icon: Icon(Icons.record_voice_over_outlined),
                  label: Text('歌手'),
                ),
                ButtonSegment<DiscoverSection>(
                  value: DiscoverSection.mv,
                  icon: Icon(Icons.movie_outlined),
                  label: Text('MV'),
                ),
              ],
              selected: {_currentSection},
              showSelectedIcon: false,
              onSelectionChanged: _selectSection,
              style: _segmentStyle(),
            ),
          ),
        Expanded(child: widget.child ?? _defaultContent()),
      ],
    );
  }
}

ButtonStyle _segmentStyle() {
  return ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppTheme.mikuGreen.withValues(alpha: 0.16);
      }
      return AppTheme.cardBg;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppTheme.textPrimary;
      }
      return AppTheme.textMuted;
    }),
    side: WidgetStateProperty.resolveWith((states) {
      final color = states.contains(WidgetState.selected)
          ? AppTheme.mikuGreen.withValues(alpha: 0.42)
          : Colors.white.withValues(alpha: 0.08);
      return BorderSide(color: color);
    }),
  );
}

class _MobileDiscoverHome extends StatefulWidget {
  const _MobileDiscoverHome({
    this.onMoreSelected,
    this.onAlbumSelected,
    this.onProducerSelected,
    this.onVocalistSelected,
    this.onDailyRecommendationsSelected,
  });

  final ValueChanged<DiscoverSection>? onMoreSelected;
  final ValueChanged<Album>? onAlbumSelected;
  final ValueChanged<Producer>? onProducerSelected;
  final ValueChanged<Vocalist>? onVocalistSelected;
  final VoidCallback? onDailyRecommendationsSelected;

  @override
  State<_MobileDiscoverHome> createState() => _MobileDiscoverHomeState();
}

class _MobileDiscoverHomeState extends State<_MobileDiscoverHome> {
  final TextEditingController _searchController = TextEditingController();
  List<Album> _albums = const [];
  List<Album> _recommendedAlbums = const [];
  List<Producer> _producers = const [];
  List<Vocalist> _vocalists = const [];
  List<Video> _videos = const [];
  DailyRecommendations? _dailyRecommendations;
  bool _dailyRecommendationsFailed = false;
  bool _loading = true;
  String? _error;
  String? _refreshError;
  int _discoverRequestId = 0;
  int _dailyRecommendationsRequestId = 0;

  @override
  void initState() {
    super.initState();
    final cached = DiscoverDataCache.current;
    if (cached != null) {
      _applyDiscoverData(cached, loading: false);
    } else {
      _loadDiscoverData();
    }
  }

  bool get _hasDiscoverData =>
      _albums.isNotEmpty ||
      _producers.isNotEmpty ||
      _vocalists.isNotEmpty ||
      _videos.isNotEmpty ||
      _dailyRecommendations?.tracks.isNotEmpty == true;

  void _applyDiscoverData(DiscoverData data, {required bool loading}) {
    setState(() {
      _albums = data.albums;
      _recommendedAlbums =
          data.recommendedAlbums ?? pickMobileDiscoverAlbums(data.albums);
      _producers = data.producers;
      _vocalists = data.vocalists;
      _videos = data.videos;
      _dailyRecommendations = data.dailyRecommendations;
      _dailyRecommendationsFailed = false;
      _loading = loading;
      _error = null;
      _refreshError = null;
    });
  }

  Future<void> _loadDiscoverData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final discoverRequestId = ++_discoverRequestId;
    try {
      final api = ApiClient();
      final dailyRecommendationsRequestId = ++_dailyRecommendationsRequestId;
      final dailyRecommendationsFuture = api.getDailyRecommendations();
      unawaited(dailyRecommendationsFuture.then<void>((_) {}, onError: (_) {}));
      final albumsFuture = api.getAlbums();
      final producersFuture = api.getProducers();
      final vocalistsFuture = api.getVocalists();
      final videosFuture = api.getVideos();
      final coreResults = await Future.wait<Object>([
        albumsFuture,
        producersFuture,
        vocalistsFuture,
        videosFuture,
      ]);
      final albums = coreResults[0] as List<Album>;
      final producers = coreResults[1] as List<Producer>;
      final vocalists = coreResults[2] as List<Vocalist>;
      final videos = coreResults[3] as List<Video>;
      if (!mounted || discoverRequestId != _discoverRequestId) return;
      final preservedDailyRecommendations =
          _dailyRecommendations ??
          DiscoverDataCache.current?.dailyRecommendations;
      final recommendedAlbums = pickMobileDiscoverAlbums(albums);
      final data = DiscoverData(
        albums: albums,
        recommendedAlbums: recommendedAlbums,
        producers: producers,
        vocalists: vocalists,
        videos: videos,
        dailyRecommendations: preservedDailyRecommendations,
      );
      DiscoverDataCache.write(data);
      _applyDiscoverData(data, loading: false);
      unawaited(
        _applyDailyRecommendationsResult(
          dailyRecommendationsFuture,
          requestId: dailyRecommendationsRequestId,
        ),
      );
    } catch (e) {
      if (!mounted || discoverRequestId != _discoverRequestId) return;
      if (_hasDiscoverData) {
        setState(() {
          _refreshError = 'Failed to refresh discover data';
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

  Future<void> _applyDailyRecommendationsResult(
    Future<DailyRecommendations> future, {
    required int requestId,
  }) async {
    try {
      final dailyRecommendations = await future;
      if (!mounted || requestId != _dailyRecommendationsRequestId) return;
      setState(() {
        _dailyRecommendations = dailyRecommendations;
        _dailyRecommendationsFailed = false;
      });
      DiscoverDataCache.write(
        DiscoverData(
          albums: _albums,
          recommendedAlbums: _recommendedAlbums,
          producers: _producers,
          vocalists: _vocalists,
          videos: _videos,
          dailyRecommendations: dailyRecommendations,
        ),
      );
    } catch (_) {
      if (!mounted || requestId != _dailyRecommendationsRequestId) return;
      setState(() {
        _dailyRecommendationsFailed = true;
      });
      final current = DiscoverDataCache.current;
      if (current != null && current.dailyRecommendations != null) {
        DiscoverDataCache.write(
          DiscoverData(
            albums: _albums,
            recommendedAlbums: _recommendedAlbums,
            producers: _producers,
            vocalists: _vocalists,
            videos: _videos,
            dailyRecommendations: current.dailyRecommendations,
          ),
        );
      }
    }
  }

  Future<void> _refreshDiscoverData() {
    return _loadDiscoverData(showLoading: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadDiscoverData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final featuredAlbum = _albums.isNotEmpty ? _albums.first : null;
    return RefreshIndicator(
      onRefresh: _refreshDiscoverData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            sliver: SliverList.list(
              children: [
                const _MobileDiscoverTopBar(),
                const SizedBox(height: 12),
                _MobileSearchField(controller: _searchController),
                const SizedBox(height: 16),
                if (_refreshError != null) ...[
                  _RefreshErrorBanner(message: _refreshError!),
                  const SizedBox(height: 12),
                ],
                _DailyRecommendationsModule(
                  recommendations: _dailyRecommendations,
                  failed: _dailyRecommendationsFailed,
                  onTap: widget.onDailyRecommendationsSelected,
                  onRetry: () => _loadDiscoverData(showLoading: false),
                ),
                const SizedBox(height: 16),
                _FeaturedAlbumBanner(
                  album: featuredAlbum,
                  onAlbumSelected: widget.onAlbumSelected,
                ),
                const SizedBox(height: 20),
                _MobileSectionHeader(
                  title: '专辑推荐',
                  section: DiscoverSection.albums,
                  onMoreSelected: widget.onMoreSelected,
                ),
                const SizedBox(height: 10),
                _AlbumStrip(
                  albums: _recommendedAlbums,
                  onAlbumSelected: widget.onAlbumSelected,
                ),
                const SizedBox(height: 20),
                _MobileSectionHeader(
                  title: '热门P主',
                  section: DiscoverSection.producers,
                  onMoreSelected: widget.onMoreSelected,
                ),
                const SizedBox(height: 10),
                _ProducerStrip(
                  producers: _producers.take(5).toList(),
                  onProducerSelected: widget.onProducerSelected,
                ),
                const SizedBox(height: 20),
                _MobileSectionHeader(
                  title: '虚拟歌手',
                  section: DiscoverSection.vocalists,
                  onMoreSelected: widget.onMoreSelected,
                ),
                const SizedBox(height: 10),
                _VocalistStrip(
                  vocalists: _vocalists.take(5).toList(),
                  onVocalistSelected: widget.onVocalistSelected,
                ),
                const SizedBox(height: 20),
                _MobileSectionHeader(
                  title: '推荐MV',
                  section: DiscoverSection.mv,
                  onMoreSelected: widget.onMoreSelected,
                ),
                const SizedBox(height: 10),
                _VideoStrip(videos: _videos.take(3).toList()),
              ],
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.redAccent.shade100,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _MobileDiscoverTopBar extends StatelessWidget {
  const _MobileDiscoverTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '发现',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          onPressed: () {},
          tooltip: '通知',
          visualDensity: VisualDensity.compact,
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: AppTheme.textPrimary,
            size: 20,
          ),
        ),
      ],
    );
  }
}

class _MobileSearchField extends StatelessWidget {
  const _MobileSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: '搜索歌曲、专辑、P主、MV...',
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.textMuted,
            size: 16,
          ),
          suffixIcon: const Icon(
            Icons.manage_search_rounded,
            color: AppTheme.textMuted,
            size: 16,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: AppTheme.mikuGreen.withValues(alpha: 0.55),
            ),
          ),
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}

class _DailyRecommendationsModule extends StatelessWidget {
  const _DailyRecommendationsModule({
    required this.recommendations,
    required this.failed,
    required this.onRetry,
    this.onTap,
  });

  final DailyRecommendations? recommendations;
  final bool failed;
  final VoidCallback onRetry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tracks = recommendations?.tracks ?? const [];
    final preview = tracks.take(3).map((track) => track.title).join(' · ');
    final subtitle = failed
        ? '加载失败，重试'
        : preview.isNotEmpty
        ? preview
        : '暂无推荐歌曲';
    final date = recommendations?.date ?? '';

    return InkWell(
      onTap: failed ? onRetry : onTap,
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.mikuGreen.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.today_rounded,
                  color: AppTheme.mikuGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '每日推荐',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        if (date.isNotEmpty)
                          Text(
                            date,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppTheme.textMuted,
                                  fontSize: 10,
                                  letterSpacing: 0,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: failed
                            ? Colors.redAccent.shade100
                            : AppTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (failed) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onRetry,
                  tooltip: '重试',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: AppTheme.textMuted,
                    size: 18,
                  ),
                ),
              ] else ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textMuted,
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedAlbumBanner extends StatelessWidget {
  const _FeaturedAlbumBanner({required this.album, this.onAlbumSelected});

  final Album? album;
  final ValueChanged<Album>? onAlbumSelected;

  @override
  Widget build(BuildContext context) {
    final title = album?.title ?? 'GHOST';
    final producer = album?.producerName.isNotEmpty == true
        ? album!.producerName
        : 'DECO*27 feat. 初音ミク';
    return InkWell(
      onTap: album == null ? null : () => onAlbumSelected?.call(album!),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 144,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppTheme.cardBg,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (album != null)
              Image.network(
                album!.coverUrl,
                headers: ApiConfig.defaultHeaders,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.88),
                    Colors.black.withValues(alpha: 0.56),
                    AppTheme.mikuGreen.withValues(alpha: 0.16),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              top: 12,
              bottom: 12,
              width: 178,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FEATURED',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.mikuGreen,
                      fontSize: 9,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    producer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.76),
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: album == null
                        ? null
                        : () => onAlbumSelected?.call(album!),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.mikuGreen,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(74, 26),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('立即播放'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileSectionHeader extends StatelessWidget {
  const _MobileSectionHeader({
    required this.title,
    required this.section,
    this.onMoreSelected,
  });

  final String title;
  final DiscoverSection section;
  final ValueChanged<DiscoverSection>? onMoreSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton(
          onPressed: () => onMoreSelected?.call(section),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textMuted,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(44, 28),
            textStyle: const TextStyle(fontSize: 11),
          ),
          child: const Text('更多 >'),
        ),
      ],
    );
  }
}

class _AlbumStrip extends StatelessWidget {
  const _AlbumStrip({required this.albums, this.onAlbumSelected});

  final List<Album> albums;
  final ValueChanged<Album>? onAlbumSelected;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return const _EmptyStripMessage(text: '还没有专辑');
    }

    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: albums.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final album = albums[index];
          return InkWell(
            onTap: () => onAlbumSelected?.call(album),
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 64,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SquareImage(url: album.coverUrl, icon: Icons.album_rounded),
                  const SizedBox(height: 6),
                  Text(
                    album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: 10,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    album.producerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMuted,
                      fontSize: 8,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProducerStrip extends StatelessWidget {
  const _ProducerStrip({required this.producers, this.onProducerSelected});

  final List<Producer> producers;
  final ValueChanged<Producer>? onProducerSelected;

  @override
  Widget build(BuildContext context) {
    if (producers.isEmpty) {
      return const _EmptyStripMessage(text: '还没有P主');
    }

    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: producers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final producer = producers[index];
          return InkWell(
            key: ValueKey('discover-producer-${producer.id}'),
            onTap: () => onProducerSelected?.call(producer),
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 56,
              child: Column(
                children: [
                  _CircleImage(
                    url: ApiClient().producerAvatarUrl(producer.id),
                    icon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    producer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: 10,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VocalistStrip extends StatelessWidget {
  const _VocalistStrip({required this.vocalists, this.onVocalistSelected});

  final List<Vocalist> vocalists;
  final ValueChanged<Vocalist>? onVocalistSelected;

  @override
  Widget build(BuildContext context) {
    if (vocalists.isEmpty) {
      return const _EmptyStripMessage(text: '还没有歌手');
    }

    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: vocalists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final vocalist = vocalists[index];
          final color = VocalColors.colorForName(vocalist.name);
          return InkWell(
            key: ValueKey('discover-vocalist-${vocalist.name}'),
            onTap: () => onVocalistSelected?.call(vocalist),
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 56,
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.64),
                      ),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        ApiClient().vocalistAvatarUrl(vocalist.name),
                        headers: ApiConfig.defaultHeaders,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            vocalist.name.characters.first,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    vocalist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: 10,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VideoStrip extends StatelessWidget {
  const _VideoStrip({required this.videos});

  final List<Video> videos;

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return const _EmptyStripMessage(text: '还没有MV');
    }

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: videos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final video = videos[index];
          return SizedBox(
            width: 112,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    _WideImage(
                      url: ApiClient().videoThumbUrl(video.id),
                      icon: Icons.movie_rounded,
                    ),
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.58),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: AppTheme.mikuGreen,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  video.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: 10,
                    letterSpacing: 0,
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

class _SquareImage extends StatelessWidget {
  const _SquareImage({required this.url, required this.icon});

  final String url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url,
        headers: ApiConfig.defaultHeaders,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _ImageFallback(icon: icon, width: 64, height: 64),
      ),
    );
  }
}

class _WideImage extends StatelessWidget {
  const _WideImage({required this.url, required this.icon});

  final String url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url,
        headers: ApiConfig.defaultHeaders,
        width: 112,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _ImageFallback(icon: icon, width: 112, height: 64),
      ),
    );
  }
}

class _CircleImage extends StatelessWidget {
  const _CircleImage({required this.url, required this.icon});

  final String url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.network(
        url,
        headers: ApiConfig.defaultHeaders,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _ImageFallback(icon: icon, width: 50, height: 50),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({
    required this.icon,
    required this.width,
    required this.height,
  });

  final IconData icon;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.white.withValues(alpha: 0.06),
      child: Icon(icon, color: AppTheme.textMuted, size: 22),
    );
  }
}

class _EmptyStripMessage extends StatelessWidget {
  const _EmptyStripMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.textMuted,
          fontSize: 12,
        ),
      ),
    );
  }
}
