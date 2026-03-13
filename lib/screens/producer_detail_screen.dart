import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/album.dart';
import '../models/producer.dart';
import '../models/track.dart';
import '../theme/app_theme.dart';
import 'album_detail_screen.dart';

/// Producer profile: hero with blurred avatar, tabs, Discography, Featured MVs (miku_produce_detail.html).
class ProducerDetailScreen extends StatefulWidget {
  ProducerDetailScreen({
    super.key,
    required this.producer,
    this.baseUrl = '',
    this.onAlbumTap,
  });

  final Producer producer;
  final String baseUrl;
  String get _effectiveBaseUrl => baseUrl.isEmpty ? ApiConfig.defaultBaseUrl : baseUrl;
  final ValueChanged<Album>? onAlbumTap;

  @override
  State<ProducerDetailScreen> createState() => _ProducerDetailScreenState();
}

class _ProducerDetailScreenState extends State<ProducerDetailScreen> {
  int _tabIndex = 0;
  Producer? _loadedProducer; // API 返回的完整数据，含正确 trackCount/albumCount
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
      final result = await ApiClient(baseUrl: widget._effectiveBaseUrl).getProducer(widget.producer.id);
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

  List<Track> get _tracksWithMv => _tracks.where((t) => t.videoPath.isNotEmpty).toList();

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
                  child: _HeroSection(producer: _displayProducer, baseUrl: widget._effectiveBaseUrl),
                ),
                SliverToBoxAdapter(
                  child: _TabBar(
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
                            FilledButton(onPressed: _loadProducer, child: const Text('Retry')),
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
                              _SectionTitle('Discography'),
                              const SizedBox(height: 32),
                              _DiscographyGrid(
                                albums: _albums,
                                baseUrl: widget._effectiveBaseUrl,
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
                                  _SectionTitle('All Tracks'),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_tracks.length} tracks',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: AppTheme.textMuted,
                                        ),
                                  ),
                                  const SizedBox(height: 24),
                                  if (_tracks.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 48),
                                      child: Text(
                                        'No tracks for this producer.',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: AppTheme.textMuted,
                                            ),
                                      ),
                                    )
                                  else ...[
                                    _ProducerTrackListHeader(),
                                    ..._tracks.asMap().entries.map((e) => _ProducerTrackRow(
                                          index: e.key + 1,
                                          track: e.value,
                                          baseUrl: widget._effectiveBaseUrl,
                                        )),
                                  ],
                                ]),
                              )
                            : SliverList(
                                delegate: SliverChildListDelegate([
                                  _SectionTitle('Featured MVs'),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '${_tracksWithMv.length} tracks with local MV',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: AppTheme.textMuted,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _FeaturedMVsGrid(
                                    tracks: _tracksWithMv,
                                    baseUrl: widget._effectiveBaseUrl,
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

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.producer, required this.baseUrl});

  final Producer producer;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = ApiClient(baseUrl: baseUrl).producerAvatarUrl(producer.id);
    return Stack(
      children: [
        SizedBox(
          height: 384,
          width: double.infinity,
          child: Image.network(
            avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: AppTheme.cardBg),
          ),
        ),
        Container(
          height: 384,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.mikuDark.withValues(alpha: 0.5),
                AppTheme.mikuDark,
              ],
            ),
          ),
        ),
        Positioned(
          left: 48,
          right: 48,
          bottom: 32,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 192,
                height: 192,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.mikuGreen.withValues(alpha: 0.2), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 24,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.cardBg,
                      child: const Icon(Icons.person, color: AppTheme.textMuted, size: 64),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectableText(
                      producer.name,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${producer.trackCount} Tracks across ${producer.albumCount} Albums in your NAS.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.mikuGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                icon: const Icon(Icons.shuffle),
                label: const Text('SHUFFLE CREATOR'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onTap, this.mvCount = 0});

  final int index;
  final ValueChanged<int> onTap;
  final int mvCount;

  @override
  Widget build(BuildContext context) {
    const tabs = ['ALBUMS', 'ALL TRACKS', 'LOCAL MVs'];
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.mikuDark,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isActive = index == i;
          final label = tabs[i];
          final showBadge = i == 2 && mvCount > 0;
          return InkWell(
            onTap: () => onTap(i),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              margin: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                border: isActive
                    ? const Border(
                        bottom: BorderSide(color: AppTheme.mikuGreen, width: 2),
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: isActive ? AppTheme.mikuGreen : AppTheme.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (showBadge) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.mikuGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$mvCount',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.black,
                              fontSize: 9,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
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

class _ProducerTrackListHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text('#', style: _trackHeaderStyle(context))),
          const SizedBox(width: 16),
          Expanded(
            flex: 6,
            child: Text('Title / Vocalists', style: _trackHeaderStyle(context)),
          ),
          Expanded(
            flex: 3,
            child: Center(child: Text('Tags / MV', style: _trackHeaderStyle(context))),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 48,
            child: Align(
              alignment: Alignment.centerRight,
              child: Icon(Icons.access_time, size: 12, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle? _trackHeaderStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.textMuted,
        );
  }
}

class _ProducerTrackRow extends StatefulWidget {
  const _ProducerTrackRow({
    required this.index,
    required this.track,
    required this.baseUrl,
  });

  final int index;
  final Track track;
  final String baseUrl;

  @override
  State<_ProducerTrackRow> createState() => _ProducerTrackRowState();
}

class _ProducerTrackRowState extends State<_ProducerTrackRow> {
  bool _hovering = false;

  String get _vocalLine {
    final composer = widget.track.composer.trim();
    final lyricist = widget.track.lyricist.trim();
    final vocal = widget.track.vocal.trim();

    final parts = <String>[];

    if (composer.isNotEmpty && lyricist.isNotEmpty) {
      if (composer == lyricist) {
        parts.add(composer);
      } else {
        parts.add('$composer, $lyricist');
      }
    } else if (composer.isNotEmpty) {
      parts.add(composer);
    } else if (lyricist.isNotEmpty) {
      parts.add(lyricist);
    }

    if (vocal.isNotEmpty) {
      if (parts.isNotEmpty) {
        parts.add('feat. $vocal');
      } else {
        parts.add(vocal);
      }
    }

    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final titleColor = _hovering ? AppTheme.mikuGreen : AppTheme.textPrimary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white.withValues(alpha: 0.03),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        track.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (_vocalLine.isNotEmpty)
                        Text(
                          _vocalLine,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (track.hasVideo)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.mikuGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.mikuGreen.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.movie, size: 10, color: AppTheme.mikuGreen),
                              const SizedBox(width: 4),
                              Text(
                                'LOCAL MV',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppTheme.mikuGreen,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      if (track.hasVideo && track.format.isNotEmpty) const SizedBox(width: 12),
                      if (track.format.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Text(
                            track.format,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: const Color(0xFF9CA3AF),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                        ),
                      if (!track.hasVideo && track.format.isEmpty && _hovering)
                        IconButton(
                          onPressed: () {},
                          style: IconButton.styleFrom(
                            foregroundColor: AppTheme.textMuted,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.all(8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ).copyWith(
                            overlayColor: MaterialStateProperty.resolveWith<Color?>((states) {
                              if (states.contains(MaterialState.hovered)) {
                                return AppTheme.textPrimary.withValues(alpha: 0.08);
                              }
                              return null;
                            }),
                            foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                              if (states.contains(MaterialState.hovered)) {
                                return AppTheme.textPrimary;
                              }
                              return AppTheme.textMuted;
                            }),
                          ),
                          icon: const Icon(Icons.download, size: 20),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 48,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      track.durationFormatted,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscographyGrid extends StatelessWidget {
  const _DiscographyGrid({
    required this.albums,
    required this.baseUrl,
    required this.onAlbumTap,
  });

  final List<Album> albums;
  final String baseUrl;
  final ValueChanged<Album> onAlbumTap;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return Text(
        'No albums',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textMuted,
            ),
      );
    }
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 5,
      mainAxisSpacing: 32,
      crossAxisSpacing: 32,
      childAspectRatio: 0.85,
      children: albums
          .map((a) => _AlbumTile(
                coverUrl: a.coverUrl,
                title: a.title,
                subtitle: '${a.trackCount} Tracks',
                onTap: () => onAlbumTap(a),
              ))
          .toList(),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({
    required this.coverUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String coverUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                coverUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppTheme.cardBg,
                  child: const Icon(Icons.album, color: AppTheme.textMuted),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedMVsGrid extends StatelessWidget {
  const _FeaturedMVsGrid({
    required this.tracks,
    required this.baseUrl,
  });

  final List<Track> tracks;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return Text(
        'No tracks with local MV',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textMuted,
            ),
      );
    }
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 24,
      crossAxisSpacing: 24,
      childAspectRatio: 16 / 9,
      children: tracks
          .map((t) => _MVCard(
                imageUrl: t.videoThumbPath.isNotEmpty
                    ? ApiClient(baseUrl: baseUrl).streamThumbUrl(t.id)
                    : '',
                title: t.title,
                subtitle: 'Local MV',
                trackId: t.id,
                baseUrl: baseUrl,
              ))
          .toList(),
    );
  }
}

class _MVCard extends StatefulWidget {
  const _MVCard({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.trackId,
    required this.baseUrl,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final int trackId;
  final String baseUrl;

  @override
  State<_MVCard> createState() => _MVCardState();
}

class _MVCardState extends State<_MVCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: () {
          // Could open video player; for now just placeholder
        },
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: widget.imageUrl.isNotEmpty
                  ? Image.network(
                      widget.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(context),
                    )
                  : _placeholder(context),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  widget.subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.mikuGreen,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
          Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _hovering ? 1 : 0,
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white.withValues(alpha: 0.9),
                size: 48,
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        color: AppTheme.cardBg,
        child: const Icon(Icons.movie, color: AppTheme.textMuted, size: 48),
      );
}
