import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/playlist.dart';
import '../models/playlist_detail_data.dart';
import '../models/playlist_item.dart';
import '../models/track.dart';
import '../services/playlist_repository.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/playlist_detail/group_title_dialog.dart';
import '../widgets/playlist_detail/playlist_edit_bar.dart';
import '../widgets/playlist_detail/playlist_group_section.dart';
import '../widgets/playlist_detail/playlist_hero.dart';
import '../widgets/playlist_detail/playlist_item_editor_sheet.dart';
import '../widgets/playlist_detail/playlist_track_row.dart';

class PlaylistDetailScreen extends StatefulWidget {
  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    this.baseUrl = '',
    this.client,
    this.onBack,
    this.onPlayTrack,
    this.currentPlayingTrackId,
    this.isPlaying = false,
  });

  final int playlistId;
  final String baseUrl;
  final ApiClient? client;
  final VoidCallback? onBack;
  final void Function(Track track, List<Track> queue, int index)? onPlayTrack;
  final int? currentPlayingTrackId;
  final bool isPlaying;

  String get _effectiveBaseUrl =>
      baseUrl.isEmpty ? ApiConfig.defaultBaseUrl : baseUrl;

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  bool _loading = true;
  String? _error;
  bool _isEditMode = false;
  bool _isLoading = false; // Prevents concurrent _loadPlaylistAndTracks calls

  late final ApiClient _client;
  PlaylistDetailData? _detail;
  Playlist? _playlist;

  List<PlaylistItem> get _items => _detail == null
      ? const []
      : _detail!.groups.expand((group) => group.items).toList();

  List<Track> get _queue => _items.map((item) => item.track).toList();

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? ApiClient(baseUrl: widget._effectiveBaseUrl);
    _playlist = PlaylistRepository.instance.playlists
        .where((p) => p.id == widget.playlistId)
        .firstOrNull;
    _loadPlaylistAndTracks();
    PlaylistRepository.instance.addListener(_onRepositoryUpdate);
  }

  @override
  void dispose() {
    PlaylistRepository.instance.removeListener(_onRepositoryUpdate);
    super.dispose();
  }

  void _onRepositoryUpdate() {
    if (!mounted) return;
    if (_detail != null) return;
    final updated = PlaylistRepository.instance.playlists
        .where((p) => p.id == widget.playlistId)
        .firstOrNull;
    // Compare by ID and relevant fields since Playlist doesn't override ==
    if (updated != null &&
        (updated.id != _playlist?.id ||
            updated.name != _playlist?.name ||
            updated.trackCount != _playlist?.trackCount ||
            updated.coverPath != _playlist?.coverPath)) {
      setState(() {
        _playlist = updated;
      });
    }
  }

  Future<void> _loadPlaylistAndTracks() async {
    // Prevent concurrent loads (race condition guard)
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _client.getPlaylistItems(widget.playlistId);
      if (!mounted) return;
      setState(() {
        _playlist = detail.playlist;
        _detail = detail;
        _loading = false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _sanitizeError(e);
        _loading = false;
        _isLoading = false;
      });
    }
  }

  /// Sanitizes error messages for user display
  String _sanitizeError(Object error) {
    final errorStr = error.toString();
    // Remove technical stack traces and internal details
    if (errorStr.contains('Exception:')) {
      return errorStr.split('Exception:').last.trim();
    }
    if (errorStr.contains('Error:')) {
      return errorStr.split('Error:').last.trim();
    }
    // Generic fallback for unknown errors
    if (errorStr.length > 200) {
      return 'An error occurred. Please try again.';
    }
    return errorStr;
  }

  String _getMimeType(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  void _playItem(PlaylistItem item) {
    final queue = _queue;
    final index = _items.indexWhere((candidate) => candidate.id == item.id);
    if (index < 0 || index >= queue.length) return;
    widget.onPlayTrack?.call(item.track, queue, index);
  }

  void _playAll() {
    if (_items.isEmpty) return;
    _playItem(_items.first);
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
  }

  Future<void> _createGroup() async {
    final title = await showDialog<String>(
      context: context,
      builder: (context) => const GroupTitleDialog(),
    );
    if (title == null || title.trim().isEmpty) return;
    await _client.createPlaylistGroup(widget.playlistId, title.trim());
    await _loadPlaylistAndTracks();
  }

  Future<void> _editItem(PlaylistItem item) async {
    final detail = _detail;
    if (detail == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => PlaylistItemEditorSheet(
        item: item,
        groups: detail.groups,
        onSave: (request) =>
            _client.updatePlaylistItem(widget.playlistId, item.id, request),
        onUploadCustomCover: () => _uploadItemCover(item),
        onClearCustomCover: () => _clearItemCover(item),
      ),
    );
    await _loadPlaylistAndTracks();
  }

  Future<void> _uploadItemCover(PlaylistItem item) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to read file')),
      );
      return;
    }

    await _client.uploadPlaylistItemCover(
      widget.playlistId,
      item.id,
      bytes,
      file.name,
      _getMimeType(file.name),
    );
    await _loadPlaylistAndTracks();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Custom cover uploaded')),
    );
  }

  Future<void> _clearItemCover(PlaylistItem item) async {
    await _client.clearPlaylistItemCover(widget.playlistId, item.id);
    await _loadPlaylistAndTracks();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Custom cover removed')),
    );
  }

  Future<void> _persistGroupedOrder() async {
    final detail = _detail;
    if (detail == null) return;
    final payload = detail.groups
        .map(
          (group) => PlaylistGroupReorderInput(
            id: group.id,
            itemIds: group.items.map((item) => item.id).toList(),
          ),
        )
        .toList();
    await _client.reorderPlaylistItems(widget.playlistId, payload);
  }

  Future<void> _finishEditMode() async {
    await _persistGroupedOrder();
    if (!mounted) return;
    setState(() {
      _isEditMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_playlist == null && !_loading && _error == null) {
      return Scaffold(
        backgroundColor: AppTheme.mikuDark,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Playlist not found'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.mikuDark,
      body: Stack(
        children: [
          Column(
            children: [
              if (_isEditMode)
                PlaylistEditBar(
                  onDone: _finishEditMode,
                  onAddGroup: _createGroup,
                ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    if (isMobile(context) && widget.onBack != null)
                      SliverAppBar(
                        backgroundColor: Colors.transparent,
                        pinned: false,
                        floating: true,
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: widget.onBack,
                        ),
                        title: Text(
                          _playlist?.name ?? '',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    if (_playlist != null)
                      SliverToBoxAdapter(
                        child: PlaylistHero(
                          playlist: _playlist!,
                          client: _client,
                          onPlay: _playAll,
                          canPlay: _items.isNotEmpty,
                          onEdit: _toggleEditMode,
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
                                FilledButton(
                                  onPressed: _loadPlaylistAndTracks,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (_items.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.music_note,
                                  size: 64,
                                  color:
                                      AppTheme.textMuted.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No tracks in this playlist',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: AppTheme.textMuted,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile(context) ? 8 : 32,
                          vertical: 16,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            for (final group in _detail?.groups ?? const [])
                              Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: PlaylistGroupSection(
                                  title: group.title,
                                  children: [
                                    for (final item in group.items)
                                      PlaylistTrackRow(
                                        key: ValueKey(item.id),
                                        item: item,
                                        baseUrl: widget._effectiveBaseUrl,
                                        onTap: () => _playItem(item),
                                        onEdit: _isEditMode
                                            ? () => _editItem(item)
                                            : null,
                                        isCurrentlyPlaying:
                                            widget.currentPlayingTrackId ==
                                                    item.track.id &&
                                                widget.isPlaying,
                                      ),
                                  ],
                                ),
                              ),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
