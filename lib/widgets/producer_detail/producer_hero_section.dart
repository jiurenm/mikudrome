import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../models/producer.dart';
import '../../theme/app_theme.dart';

class ProducerHeroSection extends StatelessWidget {
  const ProducerHeroSection({
    super.key,
    required this.producer,
    required this.baseUrl,
    required this.onShuffle,
    required this.hasTracks,
  });

  final Producer producer;
  final String baseUrl;
  final VoidCallback onShuffle;
  final bool hasTracks;

  @override
  Widget build(BuildContext context) {
    final avatarUrl =
        ApiClient(baseUrl: baseUrl).producerAvatarUrl(producer.id);
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
                  border: Border.all(
                    color: AppTheme.mikuGreen.withValues(alpha: 0.2),
                    width: 4,
                  ),
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
                      child: const Icon(Icons.person,
                          color: AppTheme.textMuted, size: 64),
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
                onPressed: hasTracks ? onShuffle : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.mikuGreen,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
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
