import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/playlist.dart';
import '../models/playlist_detail_data.dart';
import '../models/playlist_group.dart';
import '../models/playlist_item.dart';
import '../models/track.dart';
import '../services/playlist_repository.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/playlist_detail/group_title_dialog.dart';
import '../widgets/playlist_detail/playlist_cover_grid.dart';
import '../widgets/playlist_detail/playlist_display_mode_switch.dart';
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
  static const double _desktopTitleColumnMinWidth = 220;
  static const double _desktopTitleColumnMaxWidth = 420;

  bool _loading = true;
  String? _error;
  bool _isEditMode = false;
  bool _isLoading = false; // Prevents concurrent _loadPlaylistAndTracks calls
  bool _isPersistingOrder = false;
  bool _showCoverTitles = true;
  int? _draggingItemId;
  int? _draggingGroupId;
  int? _hoveredGroupId;
  int? _activeGroupMenuId;
  int? _selectedItemId;
  PlaylistDisplayMode _displayMode = PlaylistDisplayMode.list;

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
        _selectedItemId = _resolvedSelectedItemId(
          items: detail.groups.expand((group) => group.items).toList(),
          preferredItemId: _selectedItemId,
        );
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
      if (_isEditMode) {
        _displayMode = PlaylistDisplayMode.list;
      }
    });
  }

  void _setDisplayMode(PlaylistDisplayMode mode) {
    setState(() {
      _displayMode = mode;
      if (mode == PlaylistDisplayMode.cover) {
        _selectedItemId = _resolvedSelectedItemId(
          items: _items,
          preferredItemId: _selectedItemId,
        );
      }
    });
  }

  void _selectItem(PlaylistItem item) {
    setState(() {
      _selectedItemId = item.id;
    });
  }

  int? _resolvedSelectedItemId({
    required List<PlaylistItem> items,
    int? preferredItemId,
  }) {
    if (items.isEmpty) return null;

    if (preferredItemId != null &&
        items.any((item) => item.id == preferredItemId)) {
      return preferredItemId;
    }

    final currentPlayingTrackId = widget.currentPlayingTrackId;
    if (currentPlayingTrackId != null) {
      final currentItem = items
          .where((item) => item.track.id == currentPlayingTrackId)
          .firstOrNull;
      if (currentItem != null) {
        return currentItem.id;
      }
    }

    return items.first.id;
  }

  Future<void> _createGroup() async {
    final title = await _showGroupTitleDialog();
    if (title == null || title.trim().isEmpty) return;
    await _client.createPlaylistGroup(widget.playlistId, title.trim());
    await _loadPlaylistAndTracks();
  }

  Future<String?> _showGroupTitleDialog({
    String initialTitle = '',
    String titleText = 'Create Group',
    String confirmText = 'Create',
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => GroupTitleDialog(
        initialTitle: initialTitle,
        titleText: titleText,
        confirmText: confirmText,
      ),
    );
  }

  Future<void> _renameGroup(PlaylistGroup group) async {
    final title = await _showGroupTitleDialog(
      initialTitle: group.title,
      titleText: 'Rename Group',
      confirmText: 'Save',
    );
    if (title == null || title.trim().isEmpty) return;
    await _client.renamePlaylistGroup(
        widget.playlistId, group.id, title.trim());
    await _loadPlaylistAndTracks();
  }

  Future<void> _deleteGroup(PlaylistGroup group) async {
    final systemGroup =
        _detail?.groups.where((candidate) => candidate.isSystem).firstOrNull;
    final fallbackTitle = systemGroup?.title.trim().isNotEmpty == true
        ? systemGroup!.title
        : 'Ungrouped';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete group “${group.title}”?'),
        content: Text('Tracks in this group will move to $fallbackTitle.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _client.deletePlaylistGroup(widget.playlistId, group.id);
    await _loadPlaylistAndTracks();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Group deleted')),
    );
  }

  Future<void> _moveGroup(PlaylistGroup group, int targetIndex) async {
    final detail = _detail;
    if (detail == null || _isPersistingOrder) return;

    final sourceIndex =
        detail.groups.indexWhere((candidate) => candidate.id == group.id);
    if (sourceIndex < 0) return;

    var normalizedTargetIndex = targetIndex.clamp(0, detail.groups.length);
    if (sourceIndex < normalizedTargetIndex) {
      normalizedTargetIndex -= 1;
    }

    if (sourceIndex == normalizedTargetIndex) {
      if (!mounted) return;
      setState(() {
        _draggingGroupId = null;
      });
      return;
    }

    final previousGroups = _cloneGroups(detail.groups);
    final nextGroups = _cloneGroups(detail.groups);
    final movingGroup = nextGroups.removeAt(sourceIndex);
    nextGroups.insert(normalizedTargetIndex, movingGroup);

    final normalizedGroups = [
      for (var groupIndex = 0; groupIndex < nextGroups.length; groupIndex++)
        _copyGroup(
          nextGroups[groupIndex],
          position: groupIndex,
          items: [
            for (var itemIndex = 0;
                itemIndex < nextGroups[groupIndex].items.length;
                itemIndex++)
              _copyItem(
                nextGroups[groupIndex].items[itemIndex],
                groupId: nextGroups[groupIndex].id,
                position: itemIndex,
              ),
          ],
        ),
    ];

    setState(() {
      _detail = PlaylistDetailData(
        playlist: detail.playlist,
        groups: normalizedGroups,
      );
      _draggingGroupId = null;
      _isPersistingOrder = true;
    });

    try {
      await _persistGroupedOrder();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detail = PlaylistDetailData(
          playlist: detail.playlist,
          groups: previousGroups,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_sanitizeError(e))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPersistingOrder = false;
        });
      }
    }
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

  Future<void> _removeItem(PlaylistItem item) async {
    await _client.removeTracksFromPlaylist(widget.playlistId, [item.trackId]);
    await _loadPlaylistAndTracks();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Removed from playlist')),
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
    if (!mounted) return;
    setState(() {
      _isEditMode = false;
      _draggingItemId = null;
    });
  }

  Future<void> _moveItem(
    PlaylistItem item,
    int targetGroupId,
    int targetIndex,
  ) async {
    final detail = _detail;
    if (detail == null || _isPersistingOrder) return;

    final sourceGroupIndex =
        detail.groups.indexWhere((group) => group.id == item.groupId);
    if (sourceGroupIndex < 0) return;

    final sourceGroup = detail.groups[sourceGroupIndex];
    final sourceIndex =
        sourceGroup.items.indexWhere((candidate) => candidate.id == item.id);
    if (sourceIndex < 0) return;

    final targetGroupIndex =
        detail.groups.indexWhere((group) => group.id == targetGroupId);
    if (targetGroupIndex < 0) return;

    var normalizedTargetIndex = targetIndex;
    if (sourceGroupIndex == targetGroupIndex && sourceIndex < targetIndex) {
      normalizedTargetIndex -= 1;
    }

    if (sourceGroupIndex == targetGroupIndex &&
        sourceIndex == normalizedTargetIndex) {
      if (!mounted) return;
      setState(() {
        _draggingItemId = null;
      });
      return;
    }

    final previousGroups = _cloneGroups(detail.groups);
    final nextGroups = _cloneGroups(detail.groups);
    final movingItem = nextGroups[sourceGroupIndex].items.removeAt(sourceIndex);
    final destinationItems = nextGroups[targetGroupIndex].items;
    final insertionIndex =
        normalizedTargetIndex.clamp(0, destinationItems.length);
    destinationItems.insert(
      insertionIndex,
      _copyItem(movingItem, groupId: targetGroupId, position: insertionIndex),
    );

    final normalizedGroups = [
      for (var groupIndex = 0; groupIndex < nextGroups.length; groupIndex++)
        _copyGroup(
          nextGroups[groupIndex],
          position: groupIndex,
          items: [
            for (var itemIndex = 0;
                itemIndex < nextGroups[groupIndex].items.length;
                itemIndex++)
              _copyItem(
                nextGroups[groupIndex].items[itemIndex],
                groupId: nextGroups[groupIndex].id,
                position: itemIndex,
              ),
          ],
        ),
    ];

    setState(() {
      _detail = PlaylistDetailData(
        playlist: detail.playlist,
        groups: normalizedGroups,
      );
      _draggingItemId = null;
      _isPersistingOrder = true;
    });

    try {
      await _persistGroupedOrder();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detail = PlaylistDetailData(
          playlist: detail.playlist,
          groups: previousGroups,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_sanitizeError(e))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPersistingOrder = false;
        });
      }
    }
  }

  List<PlaylistGroup> _cloneGroups(List<PlaylistGroup> groups) {
    return groups
        .map((group) => _copyGroup(group, items: [...group.items]))
        .toList();
  }

  PlaylistGroup _copyGroup(
    PlaylistGroup group, {
    int? position,
    List<PlaylistItem>? items,
  }) {
    return PlaylistGroup(
      id: group.id,
      playlistId: group.playlistId,
      title: group.title,
      position: position ?? group.position,
      isSystem: group.isSystem,
      createdAt: group.createdAt,
      updatedAt: group.updatedAt,
      items: items ?? group.items,
    );
  }

  PlaylistItem _copyItem(
    PlaylistItem item, {
    int? groupId,
    int? position,
  }) {
    return PlaylistItem(
      id: item.id,
      playlistId: item.playlistId,
      trackId: item.trackId,
      groupId: groupId ?? item.groupId,
      position: position ?? item.position,
      note: item.note,
      coverMode: item.coverMode,
      libraryCoverId: item.libraryCoverId,
      cachedCoverUrl: item.cachedCoverUrl,
      customCoverPath: item.customCoverPath,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      track: item.track,
    );
  }

  Widget _buildDropSlot(
    PlaylistGroup group,
    int itemIndex,
  ) {
    return DragTarget<_PlaylistDragData>(
      key: ValueKey('playlist-group-${group.id}-slot-$itemIndex'),
      onWillAcceptWithDetails: (details) => !_isPersistingOrder,
      onAcceptWithDetails: (details) {
        final draggedItem = _items
            .where((candidate) => candidate.id == details.data.itemId)
            .firstOrNull;
        if (draggedItem == null) return;
        _moveItem(draggedItem, group.id, itemIndex);
      },
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          height: active ? 20 : 8,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.mikuGreen.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: active
                ? Border.all(
                    color: AppTheme.mikuGreen.withValues(alpha: 0.75),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildGroupDropSlot(int index) {
    return DragTarget<_PlaylistGroupDragData>(
      key: ValueKey('playlist-group-drop-slot-$index'),
      onWillAcceptWithDetails: (details) => !_isPersistingOrder,
      onAcceptWithDetails: (details) {
        final draggedGroup = (_detail?.groups ?? const <PlaylistGroup>[])
            .where((group) => group.id == details.data.groupId)
            .firstOrNull;
        if (draggedGroup == null) return;
        _moveGroup(draggedGroup, index);
      },
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          height: active ? 18 : 4,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.mikuGreen.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: active
                ? Border.all(
                    color: AppTheme.mikuGreen.withValues(alpha: 0.75),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildGroupDragHandle(PlaylistGroup group) {
    final dragging = _draggingGroupId == group.id;
    final icon = Semantics(
      label: 'Drag to reorder groups',
      child: Icon(
        Icons.drag_indicator,
        key: ValueKey('playlist-group-${group.id}-drag-handle'),
        size: 18,
        color: dragging || _isPersistingOrder
            ? AppTheme.textMuted.withValues(alpha: 0.45)
            : AppTheme.textMuted,
      ),
    );

    if (_isPersistingOrder) return icon;

    return Draggable<_PlaylistGroupDragData>(
      data: _PlaylistGroupDragData(groupId: group.id),
      onDragStarted: () {
        setState(() {
          _draggingGroupId = group.id;
        });
      },
      onDragEnd: (_) {
        if (!mounted) return;
        setState(() {
          _draggingGroupId = null;
        });
      },
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            group.title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ),
      childWhenDragging: icon,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: icon,
      ),
    );
  }

  Widget _buildDragHandle(PlaylistItem item) {
    final dragging = _draggingItemId == item.id;
    final icon = Semantics(
      label: 'Drag to reorder',
      child: Icon(
        Icons.drag_handle,
        key: ValueKey('playlist-item-${item.id}-drag-handle'),
        size: 20,
        color: dragging || _isPersistingOrder
            ? AppTheme.textMuted.withValues(alpha: 0.45)
            : AppTheme.textMuted,
      ),
    );

    if (_isPersistingOrder) return icon;

    return Draggable<_PlaylistDragData>(
      data: _PlaylistDragData(itemId: item.id),
      onDragStarted: () {
        setState(() {
          _draggingItemId = item.id;
        });
      },
      onDragEnd: (_) {
        if (!mounted) return;
        setState(() {
          _draggingItemId = null;
        });
      },
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            item.track.title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ),
      childWhenDragging: icon,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: icon,
      ),
    );
  }

  double _desktopTitleColumnWidth(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        );
    if (textStyle == null || _items.isEmpty) {
      return _desktopTitleColumnMinWidth;
    }

    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    var longestWidth = 0.0;

    for (final item in _items) {
      final painter = TextPainter(
        text: TextSpan(
          text: item.track.title,
          style: textStyle,
        ),
        maxLines: 1,
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout();
      if (painter.width > longestWidth) {
        longestWidth = painter.width;
      }
    }

    return (longestWidth.ceilToDouble() + 8).clamp(
      _desktopTitleColumnMinWidth,
      _desktopTitleColumnMaxWidth,
    );
  }

  List<Widget> _buildGroupChildren(
    PlaylistGroup group, {
    required double? desktopTitleWidth,
  }) {
    final children = <Widget>[];
    if (_isEditMode) {
      children.add(_buildDropSlot(group, 0));
    }
    for (var index = 0; index < group.items.length; index++) {
      final item = group.items[index];
      children.add(
        Opacity(
          opacity: _draggingItemId == item.id ? 0.5 : 1,
          child: PlaylistTrackRow(
            key: ValueKey(item.id),
            item: item,
            baseUrl: widget._effectiveBaseUrl,
            onTap: () => _playItem(item),
            onEdit: _isEditMode ? () => _editItem(item) : null,
            onRemove: _isEditMode ? () => _removeItem(item) : null,
            showDragHandle: _isEditMode,
            dragHandle: _isEditMode ? _buildDragHandle(item) : null,
            desktopTitleWidth: desktopTitleWidth,
            isCurrentlyPlaying: widget.currentPlayingTrackId == item.track.id &&
                widget.isPlaying,
          ),
        ),
      );
      if (_isEditMode) {
        children.add(_buildDropSlot(group, index + 1));
      }
    }
    return children;
  }

  Widget _buildGroupHeader(PlaylistGroup group, {required bool interactive}) {
    final isHovered = _hoveredGroupId == group.id;
    final showQuickActions = interactive &&
        (isHovered ||
            _draggingGroupId == group.id ||
            _activeGroupMenuId == group.id);

    return MouseRegion(
      key: ValueKey('playlist-group-header-${group.id}'),
      onEnter: (_) {
        if (!interactive) return;
        setState(() {
          _hoveredGroupId = group.id;
        });
      },
      onExit: (_) {
        if (!interactive) return;
        setState(() {
          if (_hoveredGroupId == group.id) {
            _hoveredGroupId = null;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: interactive ? 10 : 0,
          vertical: interactive ? 8 : 0,
        ),
        decoration: interactive && (isHovered || _draggingGroupId == group.id)
            ? BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.mikuGreen.withValues(alpha: 0.28),
                ),
              )
            : null,
        child: Row(
          children: [
            if (showQuickActions) ...[
              _buildGroupDragHandle(group),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                group.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (showQuickActions) ...[
              IconButton(
                key: ValueKey('playlist-group-${group.id}-rename-button'),
                onPressed: () => _renameGroup(group),
                tooltip: 'Rename group',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                icon: const Icon(Icons.edit_outlined),
              ),
              if (!group.isSystem)
                PopupMenuButton<String>(
                  key: ValueKey('playlist-group-${group.id}-more-button'),
                  tooltip: 'More actions',
                  icon: const Icon(Icons.more_horiz, size: 18),
                  onOpened: () {
                    setState(() {
                      _activeGroupMenuId = group.id;
                    });
                  },
                  onCanceled: () {
                    setState(() {
                      if (_activeGroupMenuId == group.id) {
                        _activeGroupMenuId = null;
                      }
                    });
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'delete',
                      onTap: () {
                        Future<void>.delayed(
                          Duration.zero,
                          () => _deleteGroup(group),
                        );
                      },
                      child: Text(
                        'Delete group',
                        key: ValueKey(
                            'playlist-group-${group.id}-delete-action'),
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    setState(() {
                      if (_activeGroupMenuId == group.id) {
                        _activeGroupMenuId = null;
                      }
                    });
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  bool _canQuickEditGroups(bool mobile) {
    return !mobile &&
        !_isEditMode &&
        _displayMode == PlaylistDisplayMode.list &&
        !_loading &&
        _error == null;
  }

  Widget _buildDesktopDisplayModeSwitch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
      child: Row(
        children: [
          PlaylistDisplayModeSwitch(
            value: _displayMode,
            onChanged: _setDisplayMode,
          ),
          if (_displayMode == PlaylistDisplayMode.cover) ...[
            const SizedBox(width: 20),
            Container(
              key: const ValueKey('playlist-cover-title-control'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: InkWell(
                key: const ValueKey('playlist-cover-title-toggle'),
                onTap: () {
                  setState(() {
                    _showCoverTitles = !_showCoverTitles;
                  });
                },
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showCoverTitles
                            ? Icons.subtitles_outlined
                            : Icons.subtitles_off_outlined,
                        size: 14,
                        color: _showCoverTitles
                            ? AppTheme.textPrimary.withValues(alpha: 0.88)
                            : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '显示标题',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _showCoverTitles
                                  ? AppTheme.textPrimary.withValues(alpha: 0.88)
                                  : AppTheme.textMuted,
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListModeContent(double? desktopTitleWidth) {
    final mobile = isMobile(context);
    final canQuickEditGroups = _canQuickEditGroups(mobile);
    final groups = _detail?.groups ?? const <PlaylistGroup>[];
    final children = <Widget>[];

    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      if (canQuickEditGroups) {
        children.add(_buildGroupDropSlot(groupIndex));
      }

      final group = groups[groupIndex];
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Opacity(
            opacity: _draggingGroupId == group.id ? 0.55 : 1,
            child: PlaylistGroupSection(
              header: _buildGroupHeader(
                group,
                interactive: canQuickEditGroups,
              ),
              children: _buildGroupChildren(
                group,
                desktopTitleWidth: desktopTitleWidth,
              ),
            ),
          ),
        ),
      );
    }

    if (canQuickEditGroups) {
      children.add(_buildGroupDropSlot(groups.length));
    }

    return SliverList(
      delegate: SliverChildListDelegate(children),
    );
  }

  Widget _buildContentSliver({
    required bool mobile,
    required double? desktopTitleWidth,
  }) {
    if (!mobile && _displayMode == PlaylistDisplayMode.cover) {
      return SliverToBoxAdapter(
        child: _buildCoverModeContent(),
      );
    }

    return _buildListModeContent(desktopTitleWidth);
  }

  Widget _buildContentState({
    required BuildContext context,
    required bool mobile,
    required double? desktopTitleWidth,
  }) {
    if (_loading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return SliverFillRemaining(
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
      );
    }

    if (_items.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.music_note,
                  size: 64,
                  color: AppTheme.textMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No tracks in this playlist',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 8 : 32,
        vertical: 16,
      ),
      sliver: _buildContentSliver(
        mobile: mobile,
        desktopTitleWidth: desktopTitleWidth,
      ),
    );
  }

  Widget _buildCoverModeContent() {
    return Column(
      key: const ValueKey('playlist-cover-grid'),
      children: [
        for (final group in _detail?.groups ?? const <PlaylistGroup>[])
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: PlaylistGroupSection(
              header: _buildGroupHeader(group, interactive: false),
              spacing: 16,
              children: [
                PlaylistCoverGrid(
                  items: group.items,
                  selectedItemId: _selectedItemId,
                  baseUrl: widget._effectiveBaseUrl,
                  showTitles: _showCoverTitles,
                  onSelect: _selectItem,
                  onPlay: (item) {
                    _selectItem(item);
                    _playItem(item);
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final desktopTitleWidth = mobile ? null : _desktopTitleColumnWidth(context);

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
                    if (!mobile &&
                        !_loading &&
                        _error == null &&
                        _items.isNotEmpty &&
                        !_isEditMode)
                      SliverToBoxAdapter(
                        child: _buildDesktopDisplayModeSwitch(),
                      ),
                    _buildContentState(
                      context: context,
                      mobile: mobile,
                      desktopTitleWidth: desktopTitleWidth,
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

class _PlaylistDragData {
  const _PlaylistDragData({
    required this.itemId,
  });

  final int itemId;
}

class _PlaylistGroupDragData {
  const _PlaylistGroupDragData({
    required this.groupId,
  });

  final int groupId;
}
