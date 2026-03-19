import 'package:flutter/material.dart';

import '../../models/album.dart';
import '../../theme/app_theme.dart';

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
