import 'package:flutter/material.dart';

import '../models/album.dart';
import '../theme/app_theme.dart';

/// Album detail: hero + PLAY ALL + track list with LOCAL MV tags (miku_album_detail.html).
class AlbumDetailScreen extends StatelessWidget {
  const AlbumDetailScreen({super.key, required this.album});

  final Album album;

  static List<({String title, String vocalist, String duration, bool hasLocalMv, String? format})> _mockTracks() {
    return [
      (title: 'ノンブレス・オブリージュ', vocalist: '初音ミク', duration: '03:52', hasLocalMv: true, format: '24bit FLAC'),
      (title: 'アルティメットセンパイ', vocalist: '初音ミク', duration: '03:14', hasLocalMv: false, format: null),
      (title: '神っぽいな', vocalist: '初音ミク', duration: '03:24', hasLocalMv: true, format: null),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tracks = _mockTracks();
    return Scaffold(
      backgroundColor: AppTheme.mikuDark,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _HeroSection(album: album),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                    child: Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () {},
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.mikuGreen,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow, size: 22),
                          label: const Text('PLAY ALL'),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.textMuted),
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(14),
                          ),
                          child: const Icon(Icons.shuffle),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.favorite_border, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 80),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _TrackListHeader(),
                      ...tracks.asMap().entries.map((e) => _TrackRow(
                            index: e.key + 1,
                            title: e.value.title,
                            vocalist: e.value.vocalist,
                            duration: e.value.duration,
                            hasLocalMv: e.value.hasLocalMv,
                            format: e.value.format,
                          )),
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
  const _HeroSection({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.mikuGreen.withValues(alpha: 0.2),
            AppTheme.mikuDark,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              album.coverUrl,
              width: 224,
              height: 224,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 224,
                height: 224,
                color: AppTheme.cardBg,
                child: const Icon(Icons.album, color: AppTheme.textMuted, size: 64),
              ),
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ALBUM',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.mikuGreen,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    album.title,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: NetworkImage(
                          'https://api.dicebear.com/7.x/identicon/svg?seed=${album.id}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        album.producerName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '• ${album.year}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• ${album.trackCount} Songs, 52 min',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                      ),
                    ],
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

class _TrackListHeader extends StatelessWidget {
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
            child: Center(child: Text('Tags / MV', style: _headerStyle(context))),
          ),
          const SizedBox(width: 16),
          SizedBox(width: 48, child: Align(
            alignment: Alignment.centerRight,
            child: Icon(Icons.access_time, size: 12, color: AppTheme.textMuted),
          )),
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

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.index,
    required this.title,
    required this.vocalist,
    required this.duration,
    required this.hasLocalMv,
    this.format,
  });

  final int index;
  final String title;
  final String vocalist;
  final String duration;
  final bool hasLocalMv;
  final String? format;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  index.toString().padLeft(2, '0'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      vocalist,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
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
                    if (hasLocalMv)
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
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    if (format != null) ...[
                      if (hasLocalMv) const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Text(
                          format!,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    duration,
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
    );
  }
}
