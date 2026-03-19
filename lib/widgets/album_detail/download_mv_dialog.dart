import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../theme/app_theme.dart';

class DownloadMvDialog extends StatefulWidget {
  const DownloadMvDialog({
    super.key,
    required this.trackTitle,
    required this.trackId,
    required this.baseUrl,
    this.initialUrl = '',
    required this.onSuccess,
    required this.onError,
  });

  final String trackTitle;
  final int trackId;
  final String baseUrl;
  final String initialUrl;
  final VoidCallback onSuccess;
  final void Function(String message) onError;

  @override
  State<DownloadMvDialog> createState() => _DownloadMvDialogState();
}

class _DownloadMvDialogState extends State<DownloadMvDialog> {
  final _urlController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl.isNotEmpty) {
      _urlController.text = widget.initialUrl;
    }
  }

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
      await ApiClient(baseUrl: widget.baseUrl)
          .downloadTrackMv(widget.trackId, url);
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
      title: const Text(
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
              decoration: const InputDecoration(
                labelText: '视频链接（YouTube / Bilibili 等）',
                hintText: 'https://...',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: AppTheme.mikuDark,
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('取消', style: TextStyle(color: AppTheme.textMuted)),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.mikuGreen,
            foregroundColor: Colors.black,
          ),
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
