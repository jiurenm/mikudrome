import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/vocalist.dart';
import '../theme/app_theme.dart';
import '../theme/vocal_theme.dart';
import '../utils/responsive.dart';

class VocalistsScreen extends StatefulWidget {
  const VocalistsScreen({
    super.key,
    this.onVocalistTap,
  });

  final ValueChanged<Vocalist>? onVocalistTap;

  @override
  State<VocalistsScreen> createState() => _VocalistsScreenState();
}

class _VocalistsScreenState extends State<VocalistsScreen> {
  List<Vocalist> _vocalists = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVocalists();
  }

  Future<void> _loadVocalists() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiClient().getVocalists();
      if (!mounted) return;
      setState(() {
        _vocalists = list;
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadVocalists,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final list = _vocalists;
    final mobile = isMobile(context);
    final edgePad = mobile ? 12.0 : 40.0;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                edgePad, edgePad, edgePad, mobile ? 24 : 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vocalists',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(
                    text: 'Featuring ',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                    children: [
                      TextSpan(
                        text: '${list.length}',
                        style: const TextStyle(color: AppTheme.mikuGreen),
                      ),
                      const TextSpan(text: ' vocalists in your collection'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(edgePad, 0, edgePad, edgePad),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: mobile ? 160 : 220,
              mainAxisSpacing: mobile ? 12 : 24,
              crossAxisSpacing: mobile ? 12 : 24,
              childAspectRatio: mobile ? 1.6 : 1.8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final v = list[index];
                return _VocalistCard(
                  vocalist: v,
                  onTap: () => widget.onVocalistTap?.call(v),
                );
              },
              childCount: list.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _VocalistCard extends StatelessWidget {
  const _VocalistCard({
    required this.vocalist,
    required this.onTap,
  });

  final Vocalist vocalist;
  final VoidCallback onTap;

  Color _colorForName(String name) {
    return VocalColors.colorForName(name);
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForName(vocalist.name);
    final avatarUrl = ApiClient().vocalistAvatarUrl(vocalist.name);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: color.withValues(alpha: 0.08),
            border: Border(
              left: BorderSide(color: color, width: 3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.2),
                foregroundImage: NetworkImage(avatarUrl),
                onForegroundImageError: (_, __) {},
                child: Text(
                  vocalist.name.characters.first,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      vocalist.name,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${vocalist.trackCount} tracks',
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
