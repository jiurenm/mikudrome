import 'package:flutter/material.dart';

import '../models/producer.dart';
import '../theme/app_theme.dart';

/// Producer profile: hero with blurred avatar, tabs, Discography, Featured MVs (miku_produce_detail.html).
class ProducerDetailScreen extends StatefulWidget {
  const ProducerDetailScreen({super.key, required this.producer});

  final Producer producer;

  @override
  State<ProducerDetailScreen> createState() => _ProducerDetailScreenState();
}

class _ProducerDetailScreenState extends State<ProducerDetailScreen> {
  int _tabIndex = 0;

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
                  child: _HeroSection(producer: widget.producer),
                ),
                SliverToBoxAdapter(
                  child: _TabBar(
                    index: _tabIndex,
                    onTap: (i) => setState(() => _tabIndex = i),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(48),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _SectionTitle('Discography'),
                      const SizedBox(height: 32),
                      _DiscographyGrid(),
                      const SizedBox(height: 64),
                      _SectionTitle('Featured MVs'),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: Text(
                            'VIEW ALL VIDEO ASSETS',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppTheme.textMuted,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _FeaturedMVsGrid(),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NAVIGATING: PRODUCER_PROFILE // ${widget.producer.name}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
                Text(
                  'NAS ASSET SYNC: COMPLETED',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.mikuGreen,
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
  const _HeroSection({required this.producer});

  final Producer producer;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 384,
          width: double.infinity,
          child: Image.network(
            producer.avatarUrl,
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
                    producer.avatarUrl,
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
                    Row(
                      children: [
                        const Icon(Icons.verified, size: 14, color: AppTheme.mikuGreen),
                        const SizedBox(width: 8),
                        Text(
                          'VERIFIED PRODUCER',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppTheme.mikuGreen,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      producer.name,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${producer.trackCount} Tracks across ${producer.albumCount} Albums in your NAS. Most used Vocalist: Hatsune Miku.',
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
  const _TabBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

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
          final showBadge = i == 2;
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
                        '12',
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

class _DiscographyGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 5,
      mainAxisSpacing: 32,
      crossAxisSpacing: 32,
      childAspectRatio: 0.85,
      children: [
        _AlbumTile(
          coverUrl: 'https://api.dicebear.com/7.x/identicon/svg?seed=album1',
          title: 'HUMAN',
          subtitle: '2021 • 14 Tracks',
        ),
      ],
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({
    required this.coverUrl,
    required this.title,
    required this.subtitle,
  });

  final String coverUrl;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
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
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 24,
      crossAxisSpacing: 24,
      childAspectRatio: 16 / 9,
      children: [
        _MVCard(
          imageUrl: 'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?q=80&w=500',
          title: 'ノンブレス・オブリージュ',
          subtitle: 'Local 4K Source',
        ),
      ],
    );
  }
}

class _MVCard extends StatelessWidget {
  const _MVCard({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
  });

  final String imageUrl;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppTheme.cardBg,
                child: const Icon(Icons.movie, color: AppTheme.textMuted, size: 48),
              ),
            ),
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
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.mikuGreen,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
          const Center(
            child: Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 48,
            ),
          ),
        ],
      ),
    );
  }
}
