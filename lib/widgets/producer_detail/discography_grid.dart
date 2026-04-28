import 'package:flutter/material.dart';

import '../../api/config.dart';
import '../../models/album.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

class DiscographyGrid extends StatelessWidget {
  const DiscographyGrid({
    super.key,
    required this.albums,
    required this.onAlbumTap,
  });

  final List<Album> albums;
  final ValueChanged<Album> onAlbumTap;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return Text(
        'No albums',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: isMobile(context) ? 16 : 32,
        crossAxisSpacing: isMobile(context) ? 16 : 32,
        childAspectRatio: 0.85,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final a = albums[index];
        return _AlbumTile(
          coverUrl: a.coverUrl,
          title: a.title,
          subtitle: '${a.trackCount} Tracks',
          onTap: () => onAlbumTap(a),
        );
      },
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
                headers: ApiConfig.defaultHeaders,
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
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
