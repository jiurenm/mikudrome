import 'package:shared_preferences/shared_preferences.dart';

import 'server_url.dart';

class ServerConfigStore {
  static const _serverUrlKey = 'mikudrome_server_url';

  Future<String?> loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_serverUrlKey);
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    try {
      final normalized = normalizeServerUrl(value);
      if (normalized != value) {
        await prefs.setString(_serverUrlKey, normalized);
      }
      return normalized;
    } on ServerUrlException {
      await prefs.remove(_serverUrlKey);
      return null;
    }
  }

  Future<void> saveServerUrl(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, normalizeServerUrl(serverUrl));
  }

  Future<void> clearServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serverUrlKey);
  }
}
