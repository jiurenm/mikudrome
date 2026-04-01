import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../models/producer.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

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
    final mobile = isMobile(context);
    final avatarSize = mobile ? 120.0 : 192.0;

    Widget avatarWidget = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.mikuGreen.withValues(alpha: 0.2),
          width: mobile ? 3 : 4,
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
            child: Icon(Icons.person,
                color: AppTheme.textMuted, size: mobile ? 40 : 64),
          ),
        ),
      ),
    );

    Widget nameWidget = SelectableText(
      producer.name,
      style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            fontSize: mobile ? 24 : null,
          ),
      textAlign: mobile ? TextAlign.center : TextAlign.start,
    );

    Widget statsWidget = Text(
      '${producer.trackCount} Tracks across ${producer.albumCount} Albums in your NAS.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
          ),
      textAlign: mobile ? TextAlign.center : TextAlign.start,
    );

    Widget shuffleButton = FilledButton.icon(
      onPressed: hasTracks ? onShuffle : null,
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.mikuGreen,
        foregroundColor: Colors.black,
        padding: EdgeInsets.symmetric(
            horizontal: mobile ? 24 : 32, vertical: mobile ? 14 : 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      icon: const Icon(Icons.shuffle),
      label: const Text('SHUFFLE CREATOR'),
    );

    if (mobile) {
      return Stack(
        children: [
          SizedBox(
            width: double.infinity,
            child: Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              height: 200,
              errorBuilder: (_, __, ___) =>
                  Container(height: 200, color: AppTheme.cardBg),
            ),
          ),
          Container(
            height: 200,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              children: [
                avatarWidget,
                const SizedBox(height: 16),
                nameWidget,
                const SizedBox(height: 8),
                statsWidget,
                const SizedBox(height: 16),
                shuffleButton,
              ],
            ),
          ),
        ],
      );
    }

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
              avatarWidget,
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    nameWidget,
                    const SizedBox(height: 16),
                    statsWidget,
                  ],
                ),
              ),
              shuffleButton,
            ],
          ),
        ),
      ],
    );
  }
}
