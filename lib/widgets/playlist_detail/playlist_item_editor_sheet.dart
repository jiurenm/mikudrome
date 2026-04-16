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
  });

  final PlaylistItem item;
  final List<PlaylistGroup> groups;
  final Future<void> Function(PlaylistItemUpdateRequest request) onSave;

  @override
  State<PlaylistItemEditorSheet> createState() =>
      _PlaylistItemEditorSheetState();
}

class _PlaylistItemEditorSheetState extends State<PlaylistItemEditorSheet> {
  late final TextEditingController _noteController;
  late int _selectedGroupId;
  late String _selectedCoverMode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.item.note);
    _selectedGroupId = widget.item.groupId;
    _selectedCoverMode = widget.item.coverMode;
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
          libraryCoverId: widget.item.libraryCoverId,
          cachedCoverUrl: widget.item.cachedCoverUrl,
          customCoverPath: widget.item.customCoverPath,
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
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
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
