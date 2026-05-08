import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/playlist.dart';
import '../models/track.dart';

/// Singleton ChangeNotifier that caches favorite track IDs and the playlists
/// list. Provides optimistic updates for favorite toggle.
class PlaylistRepository extends ChangeNotifier {
  PlaylistRepository._();
  static final PlaylistRepository instance = PlaylistRepository._();

  final Set<int> _favoriteTrackIds = <int>{};
  List<Playlist> _playlists = const [];
  bool _initialized = false;

  Set<int> get favoriteTrackIds => _favoriteTrackIds;
  List<Playlist> get playlists => _playlists;
  bool get initialized => _initialized;

  bool isFavorite(int trackId) => _favoriteTrackIds.contains(trackId);

  /// Fetch initial state from server. Safe to call multiple times; only first
  /// call does work.
  Future<void> initialize(ApiClient client) async {
    if (_initialized) return;
    try {
      final favs = await client.listFavorites();
      _favoriteTrackIds.addAll(favs.map((t) => t.id));
      _playlists = await client.listPlaylists();
      _initialized = true;
      notifyListeners();
    } catch (_) {
      // If initial load fails, leave state empty; UI will show empty states.
      // Repository can be re-initialized later by calling refresh methods.
    }
  }

  /// Refresh playlists from server.
  Future<void> refreshPlaylists(ApiClient client) async {
    _playlists = await client.listPlaylists();
    notifyListeners();
  }

  /// Seed favorite state from any Track response that includes is_favorite.
  /// Useful because all /api/tracks, /api/albums/:id, etc. responses now
  /// carry is_favorite, so we can avoid an extra /api/favorites round-trip
  /// during navigation.
  void syncFromTracks(Iterable<Track> tracks) {
    var changed = false;
    for (final t in tracks) {
      if (t.isFavorite) {
        if (_favoriteTrackIds.add(t.id)) changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Replace the cached favorite IDs with an authoritative favorites response.
  bool replaceFavoritesFromTracks(Iterable<Track> tracks) {
    final next = tracks.map((track) => track.id).toSet();
    if (setEquals(_favoriteTrackIds, next)) return false;
    _favoriteTrackIds
      ..clear()
      ..addAll(next);
    notifyListeners();
    return true;
  }

  /// Optimistic toggle. On failure, rolls back and rethrows.
  Future<void> toggleFavorite(int trackId, ApiClient client) async {
    await setFavorite(trackId, !_favoriteTrackIds.contains(trackId), client);
  }

  /// Optimistically set an absolute favorite state. On failure, rolls back and
  /// rethrows.
  Future<void> setFavorite(int trackId, bool favorite, ApiClient client) async {
    final wasFav = _favoriteTrackIds.contains(trackId);
    if (wasFav == favorite) return;

    if (favorite) {
      _favoriteTrackIds.add(trackId);
    } else {
      _favoriteTrackIds.remove(trackId);
    }
    notifyListeners();
    try {
      if (favorite) {
        await client.addFavorite(trackId);
      } else {
        await client.removeFavorite(trackId);
      }
    } catch (e) {
      // Rollback
      if (wasFav) {
        _favoriteTrackIds.add(trackId);
      } else {
        _favoriteTrackIds.remove(trackId);
      }
      notifyListeners();
      rethrow;
    }
  }

  /// Optimistic local mutation for playlists list (called after createPlaylist,
  /// renamePlaylist, deletePlaylist succeed on the server).
  void upsertPlaylist(Playlist p) {
    final idx = _playlists.indexWhere((x) => x.id == p.id);
    final next = List<Playlist>.from(_playlists);
    if (idx >= 0) {
      next[idx] = p;
    } else {
      next.insert(0, p);
    }
    _playlists = next;
    notifyListeners();
  }

  void removePlaylist(int id) {
    _playlists = _playlists.where((p) => p.id != id).toList();
    notifyListeners();
  }
}
