import 'package:flutter/material.dart';

class RenamePlaylistDialog extends StatefulWidget {
  const RenamePlaylistDialog({super.key, required this.initialName});

  final String initialName;

  @override
  State<RenamePlaylistDialog> createState() => _RenamePlaylistDialogState();
}

class _RenamePlaylistDialogState extends State<RenamePlaylistDialog> {
  late final _controller = TextEditingController(text: widget.initialName);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name cannot be empty');
      return;
    }
    if (name.length > 200) {
      setState(() => _error = 'Name too long (max 200 chars)');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Playlist'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Playlist name',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
