import 'package:flutter/material.dart';

import '../models/album.dart';
import '../models/producer.dart';
import '../models/track.dart';
import '../api/api.dart';
import '../theme/app_theme.dart';

/// Shows a brief message at the top of the screen (overlay).
void _showTopMessage(BuildContext context, String message, {required bool isError}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      top: MediaQuery.paddingOf(ctx).top + 16,
      left: 24,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isError ? Colors.red.shade800 : AppTheme.mikuGreen,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? Colors.white : Colors.black,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: isError ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 3), () {
    entry.remove();
  });
}

/// Album detail: hero + PLAY ALL + track list from API.
class AlbumDetailScreen extends StatefulWidget {
  AlbumDetailScreen({
    super.key,
    required this.album,
    this.baseUrl = '',
    this.onProducerTap,
  });

  final Album album;
  final String baseUrl;
  String get _effectiveBaseUrl => baseUrl.isEmpty ? ApiConfig.defaultBaseUrl : baseUrl;
  final ValueChanged<Producer>? onProducerTap;

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  List<Track> _tracks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAlbum();
  }

  Future<void> _loadAlbum() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiClient(baseUrl: widget._effectiveBaseUrl).getAlbum(widget.album.id);
      if (result == null || !mounted) return;
      setState(() {
        _tracks = result.tracks;
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
    return Scaffold(
      backgroundColor: AppTheme.mikuDark,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _HeroSection(
                    album: widget.album,
                    tracks: _tracks,
                    baseUrl: widget._effectiveBaseUrl,
                    onProducerTap: widget.onProducerTap,
                  ),
                ),
                if (_loading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton(onPressed: _loadAlbum, child: const Text('Retry')),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                      child: Row(
                        children: [
                          // PLAY ALL: 绿色实心圆角按钮
                          FilledButton.icon(
                            onPressed: () {},
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.mikuGreen,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow, size: 20),
                            label: const Text('PLAY ALL'),
                          ),
                          const SizedBox(width: 24),
                          // Shuffle: 描边圆角，hover 时边框变绿
                          OutlinedButton(
                            onPressed: () {},
                            style: ButtonStyle(
                              side: MaterialStateProperty.resolveWith<BorderSide>((states) {
                                if (states.contains(MaterialState.hovered)) {
                                  return const BorderSide(color: AppTheme.mikuGreen);
                                }
                                return const BorderSide(color: AppTheme.textMuted);
                              }),
                              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
                                const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              ),
                              foregroundColor: MaterialStateProperty.all<Color>(AppTheme.textPrimary),
                            ),
                            child: const Icon(Icons.shuffle, size: 22),
                          ),
                          const SizedBox(width: 24),
                          // Heart: 图标按钮，hover 变绿
                          IconButton(
                            onPressed: () {},
                            style: IconButton.styleFrom(
                              iconSize: 28,
                            ).copyWith(
                              overlayColor: MaterialStateProperty.resolveWith<Color?>((states) {
                                if (states.contains(MaterialState.hovered)) {
                                  return AppTheme.mikuGreen.withValues(alpha: 0.12);
                                }
                                return null;
                              }),
                              foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                                if (states.contains(MaterialState.hovered)) {
                                  return AppTheme.mikuGreen;
                                }
                                return AppTheme.textMuted;
                              }),
                            ),
                            icon: const Icon(Icons.favorite_border),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(40, 0, 40, 80),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _TrackListHeader(),
                        ..._tracks.asMap().entries.map((e) => _TrackRow(
                              index: e.key + 1,
                              track: e.value,
                              baseUrl: widget._effectiveBaseUrl,
                              onDownloadComplete: _loadAlbum,
                            )),
                      ]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.album,
    this.tracks = const [],
    required this.baseUrl,
    this.onProducerTap,
  });

  final Album album;
  final List<Track> tracks;
  final String baseUrl;
  final ValueChanged<Producer>? onProducerTap;

  static int _earliestYear(List<Track> tracks) {
    int minYear = 0;
    for (final t in tracks) {
      if (t.year > 0 && (minYear == 0 || t.year < minYear)) {
        minYear = t.year;
      }
    }
    return minYear;
  }

  static int _totalDurationSeconds(List<Track> tracks) {
    return tracks.fold(0, (s, t) => s + t.durationSeconds);
  }

  static String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '';
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h > 0) {
      return '${h} h ${m} min';
    }
    return '$m min';
  }

  @override
  Widget build(BuildContext context) {
    final year = tracks.isNotEmpty ? _earliestYear(tracks) : album.year;
    final totalSec = _totalDurationSeconds(tracks);
    final durationStr = _formatDuration(totalSec);

    return Container(
      height: 320,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.mikuGreen.withValues(alpha: 0.2),
            AppTheme.mikuDark,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              album.coverUrl,
              width: 224,
              height: 224,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 224,
                height: 224,
                color: AppTheme.cardBg,
                child: const Icon(Icons.album, color: AppTheme.textMuted, size: 64),
              ),
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ALBUM',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.mikuGreen,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    album.title,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (album.producerName.isNotEmpty) ...[
                        MouseRegion(
                          cursor: album.producerId > 0 && onProducerTap != null
                              ? SystemMouseCursors.click
                              : SystemMouseCursors.basic,
                          child: GestureDetector(
                            onTap: album.producerId > 0 && onProducerTap != null
                                ? () => onProducerTap!(Producer(
                                      id: album.producerId,
                                      name: album.producerName,
                                      trackCount: 0,
                                      albumCount: 0,
                                    ))
                                : null,
                            child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipOval(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: album.producerId == 0
                                      ? const ColoredBox(
                                          color: AppTheme.cardBg,
                                          child: Icon(Icons.person, size: 16, color: AppTheme.textMuted),
                                        )
                                      : Image.network(
                                          ApiClient(baseUrl: baseUrl).producerAvatarUrl(album.producerId),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const ColoredBox(
                                            color: AppTheme.cardBg,
                                            child: Icon(Icons.person, size: 16, color: AppTheme.textMuted),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                album.producerName,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: album.producerId > 0 && onProducerTap != null
                                          ? AppTheme.mikuGreen
                                          : AppTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      decoration: album.producerId > 0 && onProducerTap != null
                                          ? TextDecoration.underline
                                          : null,
                                      decorationColor: AppTheme.mikuGreen,
                                    ),
                              ),
                            ],
                          ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (year > 0) ...[
                        Text(
                          '• $year',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        durationStr.isNotEmpty
                            ? '• ${album.trackCount} Songs, $durationStr'
                            : '• ${album.trackCount} Songs',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackListHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text('#', style: _headerStyle(context))),
          const SizedBox(width: 16),
          Expanded(
            flex: 6,
            child: Text('Title / Vocalists', style: _headerStyle(context)),
          ),
          Expanded(
            flex: 3,
            child: Center(child: Text('Tags / MV', style: _headerStyle(context))),
          ),
          const SizedBox(width: 16),
          SizedBox(width: 48, child: Align(
            alignment: Alignment.centerRight,
            child: Icon(Icons.access_time, size: 12, color: AppTheme.textMuted),
          )),
        ],
      ),
    );
  }

  TextStyle? _headerStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.textMuted,
        );
  }
}

class _TrackRow extends StatefulWidget {
  const _TrackRow({
    required this.index,
    required this.track,
    required this.baseUrl,
    required this.onDownloadComplete,
  });

  final int index;
  final Track track;
  final String baseUrl;
  final VoidCallback onDownloadComplete;

  @override
  State<_TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<_TrackRow> {
  bool _hovering = false;

  void _openDownloadMvDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _DownloadMvDialog(
        trackTitle: widget.track.title,
        trackId: widget.track.id,
        baseUrl: widget.baseUrl,
        onSuccess: () {
          widget.onDownloadComplete();
          if (context.mounted) {
            _showTopMessage(context, 'MV 已下载并关联到曲目', isError: false);
          }
        },
        onError: (message) {
          if (context.mounted) {
            _showTopMessage(context, message, isError: true);
          }
        },
      ),
    );
  }

  String get _vocalLine {
    final p = widget.track.producer.trim();
    final v = widget.track.vocal.trim();
    if (p.isNotEmpty && v.isNotEmpty) return '$p feat. $v';
    if (p.isNotEmpty) return p;
    if (v.isNotEmpty) return 'feat. $v';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final index = widget.index;
    final numberColor = _hovering ? AppTheme.mikuGreen : AppTheme.textMuted;
    final titleColor = _hovering ? AppTheme.mikuGreen : AppTheme.textPrimary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white.withValues(alpha: 0.03),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    track.displayNumber(index),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: numberColor,
                        ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        track.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (_vocalLine.isNotEmpty)
                        Text(
                          _vocalLine,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (track.hasVideo)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.mikuGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.mikuGreen.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.movie, size: 10, color: AppTheme.mikuGreen),
                              const SizedBox(width: 4),
                              Text(
                                'LOCAL MV',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppTheme.mikuGreen,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      if (track.hasVideo && track.format.isNotEmpty) const SizedBox(width: 12),
                      if (track.format.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937), // gray-800
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Text(
                            track.format,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: const Color(0xFF9CA3AF), // gray-400
                                  fontSize: 8,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                        ),
                      if (!track.hasVideo && _hovering) ...[
                        if (track.format.isNotEmpty) const SizedBox(width: 12),
                        IconButton(
                          onPressed: () => _openDownloadMvDialog(context),
                          style: IconButton.styleFrom(
                            foregroundColor: AppTheme.textMuted,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.all(8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ).copyWith(
                            overlayColor: MaterialStateProperty.resolveWith<Color?>((states) {
                              if (states.contains(MaterialState.hovered)) {
                                return AppTheme.textPrimary.withValues(alpha: 0.08);
                              }
                              return null;
                            }),
                            foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                              if (states.contains(MaterialState.hovered)) {
                                return AppTheme.textPrimary;
                              }
                              return AppTheme.textMuted;
                            }),
                          ),
                          icon: const Icon(Icons.download, size: 20),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 48,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      track.durationFormatted,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadMvDialog extends StatefulWidget {
  const _DownloadMvDialog({
    required this.trackTitle,
    required this.trackId,
    required this.baseUrl,
    required this.onSuccess,
    required this.onError,
  });

  final String trackTitle;
  final int trackId;
  final String baseUrl;
  final VoidCallback onSuccess;
  final void Function(String message) onError;

  @override
  State<_DownloadMvDialog> createState() => _DownloadMvDialogState();
}

class _DownloadMvDialogState extends State<_DownloadMvDialog> {
  final _urlController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      widget.onError('请输入视频链接（如 YouTube）');
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiClient(baseUrl: widget.baseUrl).downloadTrackMv(widget.trackId, url);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      widget.onError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: Text(
        '下载 MV',
        style: TextStyle(color: AppTheme.textPrimary),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.trackTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              enabled: !_loading,
              decoration: InputDecoration(
                labelText: '视频链接（YouTube / Bilibili 等）',
                hintText: 'https://...',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: AppTheme.mikuDark,
              ),
              style: TextStyle(color: AppTheme.textPrimary),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text('取消', style: TextStyle(color: AppTheme.textMuted)),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.mikuGreen, foregroundColor: Colors.black),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('下载'),
        ),
      ],
    );
  }
}
