import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../services/playlist_repository.dart';
import '../theme/app_theme.dart';

/// A reusable heart button for favoriting tracks.
///
/// Subscribes to [PlaylistRepository] and shows filled/outlined heart based on
/// favorite state. Performs optimistic toggle with scale animation.
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.trackId,
    this.size = 24.0,
  });

  final int trackId;
  final double size;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  final _client = ApiClient();
  bool _isAnimating = false;

  Future<void> _handleToggle() async {
    if (_isAnimating) return;

    setState(() => _isAnimating = true);

    try {
      await PlaylistRepository.instance.toggleFavorite(widget.trackId, _client);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update favorite: $e'),
          backgroundColor: Colors.red.shade900,
        ),
      );
    } finally {
      // Keep animation active for a brief moment
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        setState(() => _isAnimating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PlaylistRepository.instance,
      builder: (context, _) {
        final isFavorite =
            PlaylistRepository.instance.isFavorite(widget.trackId);

        return AnimatedScale(
          scale: _isAnimating ? 1.2 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? AppTheme.mikuGreen : AppTheme.textMuted,
              size: widget.size,
            ),
            onPressed: _handleToggle,
            tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: widget.size + 24,
              minHeight: widget.size + 24,
            ),
          ),
        );
      },
    );
  }
}
