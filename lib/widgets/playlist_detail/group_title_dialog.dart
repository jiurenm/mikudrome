import 'package:flutter/material.dart';

class GroupTitleDialog extends StatefulWidget {
  const GroupTitleDialog({
    super.key,
    this.initialTitle = '',
    this.titleText = 'Create Group',
    this.confirmText = 'Create',
    this.fieldLabelText = 'Title',
  });

  final String initialTitle;
  final String titleText;
  final String confirmText;
  final String fieldLabelText;

  @override
  State<GroupTitleDialog> createState() => _GroupTitleDialogState();
}

class _GroupTitleDialogState extends State<GroupTitleDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titleText),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.fieldLabelText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}
