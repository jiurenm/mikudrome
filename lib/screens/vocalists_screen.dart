import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/vocalist.dart';
import '../theme/app_theme.dart';
import '../theme/vocal_theme.dart';
import '../utils/responsive.dart';

class VocalistsScreen extends StatefulWidget {
  const VocalistsScreen({super.key, this.onVocalistTap});

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
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
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
    if (mobile) {
      return _MobileVocalistsList(
        vocalists: list,
        onVocalistTap: (vocalist) => widget.onVocalistTap?.call(vocalist),
      );
    }
    final edgePad = 40.0;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              edgePad,
              edgePad,
              edgePad,
              mobile ? 24 : 48,
            ),
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
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
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
            delegate: SliverChildBuilderDelegate((context, index) {
              final v = list[index];
              return _VocalistCard(
                vocalist: v,
                onTap: () => widget.onVocalistTap?.call(v),
              );
            }, childCount: list.length),
          ),
        ),
      ],
    );
  }
}

class _MobileVocalistsList extends StatefulWidget {
  const _MobileVocalistsList({
    required this.vocalists,
    required this.onVocalistTap,
  });

  final List<Vocalist> vocalists;
  final ValueChanged<Vocalist> onVocalistTap;

  @override
  State<_MobileVocalistsList> createState() => _MobileVocalistsListState();
}

class _MobileVocalistsListState extends State<_MobileVocalistsList> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<Vocalist> get _visibleVocalists {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.vocalists;
    }
    return widget.vocalists
        .where((vocalist) => vocalist.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleVocalists = _visibleVocalists;
    return CustomScrollView(
      key: const ValueKey('vocalist-mobile-list'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '歌手',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '共 ${widget.vocalists.length} 位歌手',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          sliver: SliverToBoxAdapter(
            child: SizedBox(
              height: 38,
              child: TextField(
                key: const ValueKey('vocalist-mobile-search'),
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: '搜索歌手',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppTheme.textMuted,
                    size: 18,
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _query = '';
                            });
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppTheme.textMuted,
                            size: 18,
                          ),
                          tooltip: '清空',
                        ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(19),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(19),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(19),
                    borderSide: BorderSide(
                      color: AppTheme.mikuGreen.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ),
        if (widget.vocalists.isEmpty || visibleVocalists.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                widget.vocalists.isEmpty ? '还没有歌手' : '没有找到匹配的歌手',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
            sliver: SliverList.separated(
              itemCount: visibleVocalists.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final vocalist = visibleVocalists[index];
                return _MobileVocalistRow(
                  key: ValueKey('vocalist-mobile-row-${vocalist.name}'),
                  vocalist: vocalist,
                  onTap: () => widget.onVocalistTap(vocalist),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _MobileVocalistRow extends StatelessWidget {
  const _MobileVocalistRow({
    super.key,
    required this.vocalist,
    required this.onTap,
  });

  final Vocalist vocalist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = VocalColors.colorForName(vocalist.name);
    return Material(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.18),
                foregroundImage: NetworkImage(
                  ApiClient().vocalistAvatarUrl(vocalist.name),
                  headers: ApiConfig.defaultHeaders,
                ),
                onForegroundImageError: (_, __) {},
                child: Icon(Icons.mic_rounded, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      vocalist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${vocalist.trackCount} 首歌曲',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VocalistCard extends StatelessWidget {
  const _VocalistCard({required this.vocalist, required this.onTap});

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
            border: Border(left: BorderSide(color: color, width: 3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.2),
                foregroundImage: NetworkImage(
                  avatarUrl,
                  headers: ApiConfig.defaultHeaders,
                ),
                onForegroundImageError: (_, __) {},
                child: Text(
                  vocalist.name.characters.first,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${vocalist.trackCount} tracks',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
