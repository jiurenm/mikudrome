import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../models/track.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

class FeaturedMvsGrid extends StatelessWidget {
  const FeaturedMvsGrid({
    super.key,
    required this.tracks,
    required this.baseUrl,
    required this.onPlay,
  });

  final List<Track> tracks;
  final String baseUrl;
  final void Function(Track track, int index) onPlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${tracks.length} tracks with local MV',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted),
          ),
        ),
        const SizedBox(height: 24),
        if (tracks.isEmpty)
          Text(
            'No tracks with local MV',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              mainAxisSpacing: isMobile(context) ? 12 : 24,
              crossAxisSpacing: isMobile(context) ? 12 : 24,
              childAspectRatio: 16 / 9,
            ),
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              return _MvCard(
                imageUrl: track.videoThumbPath.isNotEmpty
                    ? ApiClient(baseUrl: baseUrl).streamThumbUrl(track.id)
                    : '',
                title: track.title,
                subtitle: 'Local MV',
                onTap: () => onPlay(track, index),
              );
            },
          ),
      ],
    );
  }
}

class _MvCard extends StatefulWidget {
  const _MvCard({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_MvCard> createState() => _MvCardState();
}

class _MvCardState extends State<_MvCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: widget.imageUrl.isNotEmpty
                  ? Image.network(
                      widget.imageUrl,
                      headers: ApiConfig.defaultHeaders,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
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

  Widget _placeholder() => Container(
    color: AppTheme.cardBg,
    child: const Icon(Icons.movie, color: AppTheme.textMuted, size: 48),
  );
}
