import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/producer.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'producer_detail_screen.dart';

/// Producers index: grid of circular avatars + stats, alphabet scroller (miku_produce.html).
class ProducersScreen extends StatefulWidget {
  ProducersScreen({super.key, this.baseUrl = '', this.onProducerTap});

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
                Row(
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
                onTap: () {
                  if (widget.onProducerTap != null) {
                    widget.onProducerTap!(p);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => ProducerDetailScreen(
                          producer: p,
                          baseUrl: widget._effectiveBaseUrl,
                        ),
                      ),
                    );
                  }
                },
              );
            }, childCount: list.length),
          ),
        ),
      ],
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
