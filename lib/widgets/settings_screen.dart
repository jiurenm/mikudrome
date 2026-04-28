import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.serverUrl,
    this.hasServerCookie = false,
    this.onEditServer,
    this.onRescan,
  });

  final String? serverUrl;
  final bool hasServerCookie;
  final VoidCallback? onEditServer;
  final VoidCallback? onRescan;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        ListTile(
          isThreeLine: true,
          leading: const Icon(Icons.dns_outlined, color: AppTheme.textPrimary),
          title: const Text(
            '服务器',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                serverUrl ?? '未配置',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                hasServerCookie ? 'Cookie 已配置' : 'Cookie 未配置',
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ],
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: onEditServer == null
                ? Colors.transparent
                : AppTheme.textMuted,
          ),
          onTap: onEditServer,
        ),
        ListTile(
          enabled: onRescan != null,
          leading: Icon(
            Icons.sync,
            color: onRescan == null ? AppTheme.textMuted : AppTheme.textPrimary,
          ),
          title: Text(
            '媒体库重扫',
            style: TextStyle(
              color: onRescan == null
                  ? AppTheme.textMuted
                  : AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: onRescan == null ? Colors.transparent : AppTheme.textMuted,
          ),
          onTap: onRescan,
        ),
      ],
    );
  }
}
