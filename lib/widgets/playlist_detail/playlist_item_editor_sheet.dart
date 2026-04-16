import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/playlist_group.dart';
import '../../models/playlist_item.dart';

class PlaylistItemEditorSheet extends StatefulWidget {
  const PlaylistItemEditorSheet({
    super.key,
    required this.item,
    required this.groups,
    required this.onSave,
    this.onUploadCustomCover,
    this.onClearCustomCover,
  });

  final PlaylistItem item;
  final List<PlaylistGroup> groups;
  final Future<void> Function(PlaylistItemUpdateRequest request) onSave;
  final Future<void> Function()? onUploadCustomCover;
  final Future<void> Function()? onClearCustomCover;

  @override
  State<PlaylistItemEditorSheet> createState() =>
      _PlaylistItemEditorSheetState();
}

class _PlaylistItemEditorSheetState extends State<PlaylistItemEditorSheet> {
  late final TextEditingController _noteController;
  late int _selectedGroupId;
  late String _selectedCoverMode;
  late bool _hasCustomCover;
  bool _saving = false;
  bool _coverActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.item.note);
    _selectedGroupId = widget.item.groupId;
    _selectedCoverMode = widget.item.coverMode;
    _hasCustomCover = widget.item.customCoverPath.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
    });
    try {
      await widget.onSave(
        PlaylistItemUpdateRequest(
          note: _noteController.text.trim(),
          groupId: _selectedGroupId,
          coverMode: _selectedCoverMode,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _uploadCustomCover() async {
    final onUploadCustomCover = widget.onUploadCustomCover;
    if (onUploadCustomCover == null || _coverActionInProgress) return;
    setState(() {
      _coverActionInProgress = true;
    });
    try {
      await onUploadCustomCover();
      if (mounted) {
        setState(() {
          _hasCustomCover = true;
          _selectedCoverMode = 'custom';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _coverActionInProgress = false;
        });
      }
    }
  }

  Future<void> _clearCustomCover() async {
    final onClearCustomCover = widget.onClearCustomCover;
    if (onClearCustomCover == null || _coverActionInProgress) return;
    setState(() {
      _coverActionInProgress = true;
    });
    try {
      await onClearCustomCover();
      if (mounted) {
        setState(() {
          _hasCustomCover = false;
          if (_selectedCoverMode == 'custom') {
            _selectedCoverMode = 'default';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _coverActionInProgress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Edit Playlist Item',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              Text(
                'Group',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              RadioGroup<int>(
                groupValue: _selectedGroupId,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedGroupId = value;
                  });
                },
                child: Column(
                  children: [
                    for (final group in widget.groups)
                      RadioListTile<int>(
                        value: group.id,
                        selected: group.id == _selectedGroupId,
                        title: Text(group.title),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cover',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _selectedCoverMode,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedCoverMode = value;
                  });
                },
                child: const Column(
                  children: [
                    RadioListTile<String>(
                      value: 'default',
                      title: Text('Default Cover'),
                    ),
                    RadioListTile<String>(
                      value: 'library',
                      title: Text('Library Cover'),
                    ),
                    RadioListTile<String>(
                      value: 'custom',
                      title: Text('Custom Cover'),
                    ),
                  ],
                ),
              ),
              if (_selectedCoverMode == 'custom') ...[
                const SizedBox(height: 8),
                Text(
                  _hasCustomCover
                      ? 'A custom cover is attached to this playlist item.'
                      : 'No custom cover uploaded yet.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed:
                          _coverActionInProgress ? null : _uploadCustomCover,
                      child: const Text('Upload Cover'),
                    ),
                    if (_hasCustomCover)
                      TextButton(
                        onPressed:
                            _coverActionInProgress ? null : _clearCustomCover,
                        child: const Text('Remove Cover'),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _saving || _coverActionInProgress ? null : _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
