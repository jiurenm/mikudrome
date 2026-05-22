import '../../models/album.dart';
import '../../models/producer.dart';
import '../../models/track.dart';

class ProducerDetailData {
  const ProducerDetailData({
    required this.producer,
    required this.albums,
    required this.tracks,
  });

  final Producer producer;
  final List<Album> albums;
  final List<Track> tracks;

  bool get hasContent => true;
}

class ProducerDetailDataCache {
  ProducerDetailDataCache._();

  static final Map<String, ProducerDetailData> _entries = {};

  static String _key({required String baseUrl, required int producerId}) {
    return '${baseUrl.trim()}::$producerId';
  }

  static ProducerDetailData? read({
    required String baseUrl,
    required int producerId,
  }) {
    return _entries[_key(baseUrl: baseUrl, producerId: producerId)];
  }

  static void write({
    required String baseUrl,
    required int producerId,
    required ProducerDetailData data,
  }) {
    _entries[_key(baseUrl: baseUrl, producerId: producerId)] = data;
  }

  static void clear({required String baseUrl, required int producerId}) {
    _entries.remove(_key(baseUrl: baseUrl, producerId: producerId));
  }

  static void clearAll() {
    _entries.clear();
  }
}
