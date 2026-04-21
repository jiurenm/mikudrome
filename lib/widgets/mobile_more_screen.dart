import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/config.dart';
import '../models/library_task_status.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';

class MobileMoreScreen extends StatefulWidget {
  MobileMoreScreen({
    super.key,
    required this.onNavigate,
    ApiClient? client,
  }) : client = client ?? ApiClient(baseUrl: ApiConfig.defaultBaseUrl);

  final ValueChanged<ShellRoute> onNavigate;
  final ApiClient client;

  @override
  State<MobileMoreScreen> createState() => _MobileMoreScreenState();
}

class _MobileMoreScreenState extends State<MobileMoreScreen> {
  LibraryTaskStatus? _status;
  Timer? _pollTimer;
  bool _startingRescan = false;
  bool _statusRequestInFlight = false;
  String? _rescanError;

  @override
  void initState() {
    super.initState();
    _ensurePolling();
    _refreshStatus();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    if (_statusRequestInFlight) {
      return;
    }
    _statusRequestInFlight = true;
    try {
      final status = await widget.client.getLibraryRescanStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        if (!status.isRunning) {
          _startingRescan = false;
        }
      });
      if (status.isRunning) {
        _ensurePolling();
      } else {
        _stopPolling();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _startingRescan = false;
      });
      _ensurePolling();
    } finally {
      _statusRequestInFlight = false;
    }
  }

  void _ensurePolling() {
    _pollTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshStatus();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _startRescan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rescan media library?'),
        content: const Text(
          'This will reread metadata and covers for the full media library. Playlists will not be cleared. Incremental watcher scans will wait until the full rescan finishes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rescan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _startingRescan = true;
      _rescanError = null;
    });

    try {
      final status = await widget.client.startLibraryRescan();
      if (!mounted) return;
      setState(() {
        _status = status;
        _startingRescan = false;
      });
      if (status.isRunning) {
        _ensurePolling();
      } else {
        _stopPolling();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _startingRescan = false;
        _rescanError = error.toString();
      });
    }
  }

  double? get _progressValue {
    final status = _status;
    if (status == null || status.totalFiles <= 0) {
      return null;
    }
    final value = status.processedFiles / status.totalFiles;
    return value.clamp(0, 1).toDouble();
  }

  Widget _buildRescanStatusCard() {
    final status = _status;
    if (status == null || status.isIdle) {
      return const SizedBox.shrink();
    }

    String title;
    if (status.isRunning) {
      title = 'Scanning library...';
    } else if (status.isCompleted) {
      title = 'Library rescan completed';
    } else {
      title = 'Library rescan failed';
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: AppTheme.cardBg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (status.isRunning)
              LinearProgressIndicator(value: _progressValue),
            if (status.isRunning) const SizedBox(height: 12),
            Text(
              '${status.processedFiles} / ${status.totalFiles} files',
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'updated ${status.updatedFiles} · skipped ${status.skippedFiles} · deleted ${status.deletedFiles} · failed ${status.failedFiles}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            if (status.isFailed && status.lastError.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                status.lastError,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final running = _status?.isRunning ?? false;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        _MoreItem(
          icon: Icons.queue_music,
          label: 'Playlists',
          onTap: () => widget.onNavigate(ShellRoute.playlists),
        ),
        _MoreItem(
          icon: Icons.favorite_outline,
          label: 'Favorites',
          onTap: () => widget.onNavigate(ShellRoute.favorites),
        ),
        _MoreItem(
          icon: Icons.video_library_outlined,
          label: 'Local MV Gallery',
          onTap: () => widget.onNavigate(ShellRoute.localMv),
        ),
        _MoreItem(
          icon: Icons.sync,
          label: 'Rescan Media Library',
          enabled: !_startingRescan && !running,
          onTap: _startRescan,
        ),
        if (_rescanError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              _rescanError!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        _buildRescanStatusCard(),
      ],
    );
  }
}

class _MoreItem extends StatelessWidget {
  const _MoreItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      leading: Icon(
        icon,
        color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
          fontSize: 16,
        ),
      ),
      onTap: enabled ? onTap : null,
    );
  }
}
