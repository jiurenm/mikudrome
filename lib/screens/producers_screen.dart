import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/producer.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'producer_detail_screen.dart';

/// Producers index: grid of circular avatars + stats, alphabet scroller (miku_produce.html).
class ProducersScreen extends StatefulWidget {
  const ProducersScreen({super.key, this.baseUrl = '', this.onProducerTap});

  final String baseUrl;
  String get _effectiveBaseUrl =>
      baseUrl.isEmpty ? ApiConfig.defaultBaseUrl : baseUrl;
  final ValueChanged<Producer>? onProducerTap;

  @override
  State<ProducersScreen> createState() => _ProducersScreenState();
}

class _ProducersScreenState extends State<ProducersScreen> {
  List<Producer> _producers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducers();
  }

  Future<void> _loadProducers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiClient(
        baseUrl: widget._effectiveBaseUrl,
      ).getProducers();
      setState(() {
        _producers = list;
        _loading = false;
      });
    } catch (e) {
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
                onPressed: _loadProducers,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final list = _producers;
    final mobile = isMobile(context);
    if (mobile) {
      return _MobileProducersList(
        producers: list,
        baseUrl: widget._effectiveBaseUrl,
        onProducerTap: _openProducer,
      );
    }
    final edgePad = mobile ? 12.0 : 40.0;
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Producers',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(
                        text: 'Tracking ',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                        children: [
                          TextSpan(
                            text: '${list.length}',
                            style: const TextStyle(color: AppTheme.mikuGreen),
                          ),
                          const TextSpan(text: ' creators in your collection'),
                        ],
                      ),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    _IndexChar(label: 'ALL', active: true),
                    _IndexChar(label: 'A'),
                    _IndexChar(label: 'B'),
                    _IndexChar(label: 'C'),
                    Text(
                      '...',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                    ),
                    _IndexChar(label: 'P'),
                    Text(
                      '...',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                    ),
                    _IndexChar(label: 'Z'),
                    _IndexChar(label: '#'),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(edgePad, 0, edgePad, edgePad),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: mobile ? 140 : 180,
              mainAxisSpacing: mobile ? 16 : 40,
              crossAxisSpacing: mobile ? 12 : 40,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final p = list[index];
              return _ProducerCard(
                producer: p,
                baseUrl: widget._effectiveBaseUrl,
                onTap: () => _openProducer(p),
              );
            }, childCount: list.length),
          ),
        ),
      ],
    );
  }

  void _openProducer(Producer producer) {
    if (widget.onProducerTap != null) {
      widget.onProducerTap!(producer);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => ProducerDetailScreen(
            producer: producer,
            baseUrl: widget._effectiveBaseUrl,
          ),
        ),
      );
    }
  }
}

class _MobileProducersList extends StatefulWidget {
  const _MobileProducersList({
    required this.producers,
    required this.baseUrl,
    required this.onProducerTap,
  });

  final List<Producer> producers;
  final String baseUrl;
  final ValueChanged<Producer> onProducerTap;

  @override
  State<_MobileProducersList> createState() => _MobileProducersListState();
}

class _MobileProducersListState extends State<_MobileProducersList> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<Producer> get _visibleProducers {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.producers;
    }
    return widget.producers
        .where((producer) => producer.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleProducers = _visibleProducers;
    return Column(
      key: const ValueKey('producer-mobile-list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'P主',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '共 ${widget.producers.length} 位创作者',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            height: 38,
            child: TextField(
              key: const ValueKey('producer-mobile-search'),
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
              decoration: InputDecoration(
                hintText: '搜索P主',
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
        Expanded(
          child: CustomScrollView(
            key: const ValueKey('producer-mobile-scroll'),
            slivers: [
              if (widget.producers.isEmpty || visibleProducers.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      widget.producers.isEmpty ? '还没有P主' : '没有找到匹配的P主',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                  sliver: SliverList.separated(
                    itemCount: visibleProducers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final producer = visibleProducers[index];
                      return _MobileProducerRow(
                        key: ValueKey('producer-mobile-row-${producer.id}'),
                        producer: producer,
                        baseUrl: widget.baseUrl,
                        onTap: () => widget.onProducerTap(producer),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileProducerRow extends StatelessWidget {
  const _MobileProducerRow({
    super.key,
    required this.producer,
    required this.baseUrl,
    required this.onTap,
  });

  final Producer producer;
  final String baseUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              _MobileProducerAvatar(producer: producer, baseUrl: baseUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      producer.name,
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
                      '${producer.trackCount} 首歌曲 · ${producer.albumCount} 张专辑',
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

class _MobileProducerAvatar extends StatelessWidget {
  const _MobileProducerAvatar({required this.producer, required this.baseUrl});

  final Producer producer;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.network(
        ApiClient(baseUrl: baseUrl).producerAvatarUrl(producer.id),
        headers: ApiConfig.defaultHeaders,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 48,
          height: 48,
          color: AppTheme.cardBg,
          child: const Icon(
            Icons.person_rounded,
            color: AppTheme.textMuted,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _IndexChar extends StatelessWidget {
  const _IndexChar({required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () {},
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: active ? AppTheme.mikuGreen : AppTheme.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ProducerCard extends StatefulWidget {
  const _ProducerCard({
    required this.producer,
    required this.baseUrl,
    required this.onTap,
  });

  final Producer producer;
  final String baseUrl;
  final VoidCallback onTap;

  @override
  State<_ProducerCard> createState() => _ProducerCardState();
}

class _ProducerCardState extends State<_ProducerCard> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(999),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.transparent, width: 4),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.mikuGreen.withValues(alpha: 0),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                customBorder: const CircleBorder(),
                child: ClipOval(
                  child: Image.network(
                    ApiClient(
                      baseUrl: widget.baseUrl,
                    ).producerAvatarUrl(widget.producer.id),
                    headers: ApiConfig.defaultHeaders,
                    width: 128,
                    height: 128,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 128,
                      height: 128,
                      color: AppTheme.cardBg,
                      child: const Icon(
                        Icons.person,
                        color: AppTheme.textMuted,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.producer.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${widget.producer.trackCount} TRACKS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textMuted,
                  fontSize: 9,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppTheme.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${widget.producer.albumCount} ALBUMS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textMuted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
