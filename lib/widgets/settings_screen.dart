import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.serverUrl,
    this.hasServerCookie = false,
    this.lowQualityAudio = false,
    this.onEditServer,
    this.onRescan,
    this.onLowQualityAudioChanged,
  });

  final String? serverUrl;
  final bool hasServerCookie;
  final bool lowQualityAudio;
  final VoidCallback? onEditServer;
  final VoidCallback? onRescan;
  final ValueChanged<bool>? onLowQualityAudioChanged;

  Widget _buildServerSection(BuildContext context) {
    return ListTile(
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
        color: onEditServer == null ? Colors.transparent : AppTheme.textMuted,
      ),
      onTap: onEditServer,
    );
  }

  Widget _buildLibrarySection(BuildContext context) {
    return ListTile(
      enabled: onRescan != null,
      leading: Icon(
        Icons.sync,
        color: onRescan == null ? AppTheme.textMuted : AppTheme.textPrimary,
      ),
      title: Text(
        '媒体库重扫',
        style: TextStyle(
          color: onRescan == null ? AppTheme.textMuted : AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: onRescan == null ? Colors.transparent : AppTheme.textMuted,
      ),
      onTap: onRescan,
    );
  }

  Widget _buildAudioQualitySection(BuildContext context) {
    return SwitchListTile(
      secondary: const Icon(Icons.network_check, color: AppTheme.textPrimary),
      title: const Text(
        '弱网省流量音质',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: const Text(
        '移动端音频优先使用低码率缓存流',
        style: TextStyle(color: AppTheme.textMuted),
      ),
      value: lowQualityAudio,
      onChanged: onLowQualityAudioChanged,
    );
  }

  Widget _buildMobileLandscape(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('settings-mobile-landscape'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildServerSection(context)),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAudioQualitySection(context),
                const SizedBox(height: 16),
                _buildLibrarySection(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isNativePhoneLandscapeSurface(context)) {
      return _buildMobileLandscape(context);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        _buildServerSection(context),
        _buildLibrarySection(context),
        _buildAudioQualitySection(context),
      ],
    );
  }
}
