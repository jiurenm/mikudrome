import '../../models/album.dart';
import '../../models/producer.dart';
import '../../models/video.dart';
import '../../models/vocalist.dart';

class DiscoverData {
  const DiscoverData({
    required this.albums,
    required this.producers,
    required this.vocalists,
    required this.videos,
  });

  final List<Album> albums;
  final List<Producer> producers;
  final List<Vocalist> vocalists;
  final List<Video> videos;

  bool get isEmpty =>
      albums.isEmpty &&
      producers.isEmpty &&
      vocalists.isEmpty &&
      videos.isEmpty;
}

class DiscoverDataCache {
  DiscoverDataCache._();

  static DiscoverData? _current;

  static DiscoverData? get current => _current;

  static void write(DiscoverData data) {
    _current = data;
  }

  static void clear() {
    _current = null;
  }
}
