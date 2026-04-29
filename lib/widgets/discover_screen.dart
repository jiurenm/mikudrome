import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/album.dart';
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

enum DiscoverSection { albums, producers, vocalists, mv }

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    this.currentSection,
    this.onSectionChanged,
    this.child,
    this.showSectionTabs = true,
    this.preferMobileHome = false,
    this.onMobileMoreSelected,
  });

  final DiscoverSection? currentSection;
  final ValueChanged<DiscoverSection>? onSectionChanged;
  final Widget? child;
  final bool showSectionTabs;
  final bool preferMobileHome;
  final ValueChanged<DiscoverSection>? onMobileMoreSelected;

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
      DiscoverSection.producers => ProducersScreen(),
      DiscoverSection.vocalists => const VocalistsScreen(),
      DiscoverSection.mv => const MvGalleryScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showSectionTabs &&
        isMobile(context) &&
        (widget.child == null || widget.preferMobileHome)) {
      return _MobileDiscoverHome(onMoreSelected: widget.onMobileMoreSelected);
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
  const _MobileDiscoverHome({this.onMoreSelected});

  final ValueChanged<DiscoverSection>? onMoreSelected;

  @override
  State<_MobileDiscoverHome> createState() => _MobileDiscoverHomeState();
}

class _MobileDiscoverHomeState extends State<_MobileDiscoverHome> {
  final TextEditingController _searchController = TextEditingController();
  List<Album> _albums = const [];
  List<Producer> _producers = const [];
  List<Vocalist> _vocalists = const [];
  List<Video> _videos = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDiscoverData();
  }

  Future<void> _loadDiscoverData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ApiClient();
      final albums = await api.getAlbums();
      final producers = await api.getProducers();
      final vocalists = await api.getVocalists();
      final videos = await api.getVideos();
      if (!mounted) return;
      setState(() {
        _albums = albums;
        _producers = producers;
        _vocalists = vocalists;
        _videos = videos;
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
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          sliver: SliverList.list(
            children: [
              const _MobileDiscoverTopBar(),
              const SizedBox(height: 12),
              _MobileSearchField(controller: _searchController),
              const SizedBox(height: 16),
              _FeaturedAlbumBanner(album: featuredAlbum),
              const SizedBox(height: 20),
              _MobileSectionHeader(
                title: '专辑推荐',
                section: DiscoverSection.albums,
                onMoreSelected: widget.onMoreSelected,
              ),
              const SizedBox(height: 10),
              _AlbumStrip(albums: _albums.take(5).toList()),
              const SizedBox(height: 20),
              _MobileSectionHeader(
                title: '热门P主',
                section: DiscoverSection.producers,
                onMoreSelected: widget.onMoreSelected,
              ),
              const SizedBox(height: 10),
              _ProducerStrip(producers: _producers.take(5).toList()),
              const SizedBox(height: 20),
              _MobileSectionHeader(
                title: '虚拟歌手',
                section: DiscoverSection.vocalists,
                onMoreSelected: widget.onMoreSelected,
              ),
              const SizedBox(height: 10),
              _VocalistStrip(vocalists: _vocalists.take(5).toList()),
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

class _FeaturedAlbumBanner extends StatelessWidget {
  const _FeaturedAlbumBanner({required this.album});

  final Album? album;

  @override
  Widget build(BuildContext context) {
    final title = album?.title ?? 'GHOST';
    final producer = album?.producerName.isNotEmpty == true
        ? album!.producerName
        : 'DECO*27 feat. 初音ミク';
    return Container(
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
                  onPressed: () {},
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
  const _AlbumStrip({required this.albums});

  final List<Album> albums;

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
          return SizedBox(
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
          );
        },
      ),
    );
  }
}

class _ProducerStrip extends StatelessWidget {
  const _ProducerStrip({required this.producers});

  final List<Producer> producers;

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
          return SizedBox(
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
          );
        },
      ),
    );
  }
}

class _VocalistStrip extends StatelessWidget {
  const _VocalistStrip({required this.vocalists});

  final List<Vocalist> vocalists;

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
          return SizedBox(
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
