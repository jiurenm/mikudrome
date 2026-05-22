import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/album.dart';
import 'package:mikudrome/models/producer.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/screens/producer_detail_screen.dart';
import 'package:mikudrome/widgets/producer_detail/producer_detail_data_cache.dart';
import 'package:mikudrome/widgets/producer_detail/producer_track_list.dart';

const _producer = Producer(
  id: 27,
  name: 'DECO*27',
  trackCount: 27,
  albumCount: 3,
);

Widget _harness({required Size size, required Widget child}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: child,
    ),
  );
}

void main() {
  setUp(ProducerDetailDataCache.clearAll);

  test('ProducerDetailDataCache stores, overwrites, and clears by key', () {
    const first = ProducerDetailData(
      producer: Producer(id: 27, name: 'DECO*27', trackCount: 1, albumCount: 1),
      albums: [
        Album(id: '1', title: 'First Album', trackCount: 1, coverUrl: ''),
      ],
      tracks: [
        Track(
          id: 1,
          title: 'First Track',
          audioPath: '/audio/first.flac',
          videoPath: '',
        ),
      ],
    );
    const second = ProducerDetailData(
      producer: Producer(id: 27, name: 'DECO*27', trackCount: 2, albumCount: 1),
      albums: [
        Album(id: '2', title: 'Second Album', trackCount: 2, coverUrl: ''),
      ],
      tracks: [
        Track(
          id: 2,
          title: 'Second Track',
          audioPath: '/audio/second.flac',
          videoPath: '',
        ),
      ],
    );
    const third = ProducerDetailData(
      producer: Producer(id: 27, name: 'DECO*27', trackCount: 3, albumCount: 1),
      albums: [
        Album(id: '3', title: 'Third Album', trackCount: 3, coverUrl: ''),
      ],
      tracks: [
        Track(
          id: 3,
          title: 'Third Track',
          audioPath: '/audio/third.flac',
          videoPath: '',
        ),
      ],
    );
    const empty = ProducerDetailData(
      producer: Producer(id: 27, name: 'DECO*27', trackCount: 0, albumCount: 0),
      albums: [],
      tracks: [],
    );

    expect(empty.hasContent, isTrue);

    expect(
      ProducerDetailDataCache.read(baseUrl: 'http://a.test', producerId: 27),
      isNull,
    );

    ProducerDetailDataCache.write(
      baseUrl: 'http://a.test',
      producerId: 27,
      data: first,
    );
    ProducerDetailDataCache.write(
      baseUrl: 'http://b.test',
      producerId: 27,
      data: second,
    );

    expect(
      ProducerDetailDataCache.read(baseUrl: 'http://a.test', producerId: 27),
      same(first),
    );
    expect(
      ProducerDetailDataCache.read(baseUrl: 'http://b.test', producerId: 27),
      same(second),
    );

    ProducerDetailDataCache.write(
      baseUrl: 'http://a.test',
      producerId: 27,
      data: third,
    );

    expect(
      ProducerDetailDataCache.read(baseUrl: 'http://a.test', producerId: 27),
      same(third),
    );
    expect(
      ProducerDetailDataCache.read(baseUrl: 'http://b.test', producerId: 27),
      same(second),
    );

    ProducerDetailDataCache.clear(baseUrl: 'http://a.test', producerId: 27);

    expect(
      ProducerDetailDataCache.read(baseUrl: 'http://a.test', producerId: 27),
      isNull,
    );
    expect(
      ProducerDetailDataCache.read(baseUrl: 'http://b.test', producerId: 27),
      same(second),
    );

    ProducerDetailDataCache.clearAll();

    expect(
      ProducerDetailDataCache.read(baseUrl: 'http://b.test', producerId: 27),
      isNull,
    );
  });

  testWidgets(
    'producer detail renders cached data without requesting network',
    (tester) async {
      ProducerDetailDataCache.write(
        baseUrl: 'http://example.test',
        producerId: 27,
        data: const ProducerDetailData(
          producer: Producer(
            id: 27,
            name: 'Cached P',
            trackCount: 1,
            albumCount: 1,
          ),
          albums: [
            Album(id: '9', title: 'Cached Album', trackCount: 1, coverUrl: ''),
          ],
          tracks: [
            Track(
              id: 91,
              title: 'Cached Track',
              audioPath: '/audio/cached.flac',
              videoPath: '',
              durationSeconds: 91,
              composer: 'Cached P',
            ),
          ],
        ),
      );
      final client = _NeverCompletingCountingProducerHttpClient();

      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(
          _harness(
            size: const Size(390, 844),
            child: ProducerDetailScreen(
              producer: _producer,
              baseUrl: 'http://example.test',
              onBack: () {},
            ),
          ),
        );
        await tester.pump();
      }, createHttpClient: (_) => client);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Cached P'), findsWidgets);
      expect(find.text('Cached Album'), findsOneWidget);
      expect(find.text('1 首歌曲 · 1 张专辑 · 0 个MV'), findsOneWidget);
      expect(client.requestCount, 0);
    },
  );

  testWidgets('producer detail writes successful loads to cache', (
    tester,
  ) async {
    await HttpOverrides.runZoned(
      () async {
        await tester.pumpWidget(
          _harness(
            size: const Size(390, 844),
            child: ProducerDetailScreen(
              producer: _producer,
              baseUrl: 'http://example.test',
              onBack: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
      },
      createHttpClient: (_) => _SingleProducerDetailHttpClient(
        const _ProducerDetailResponseSet(
          producerName: 'Loaded P',
          albumTitle: 'Loaded Album',
          trackTitle: 'Loaded Track',
        ),
      ),
    );

    final cached = ProducerDetailDataCache.read(
      baseUrl: 'http://example.test',
      producerId: 27,
    );

    expect(cached?.producer.name, 'Loaded P');
    expect(cached?.albums.single.title, 'Loaded Album');
    expect(cached?.tracks.single.title, 'Loaded Track');
  });

  testWidgets('mobile producer detail uses initial counts while loading', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          child: ProducerDetailScreen(
            producer: _producer,
            baseUrl: 'http://example.test',
            onBack: () {},
          ),
        ),
      );
      await tester.pump();
    }, createHttpClient: (_) => _DelayedProducerDetailFakeHttpClient());

    expect(find.text('27 首歌曲 · 3 张专辑 · 0 个MV'), findsOneWidget);
    expect(find.text('专辑 3'), findsOneWidget);
    expect(find.text('歌曲 27'), findsOneWidget);
  });

  testWidgets('mobile producer detail renders creator dashboard and sections', (
    tester,
  ) async {
    var backCount = 0;
    var playedTitle = '';

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          child: ProducerDetailScreen(
            producer: _producer,
            baseUrl: 'http://example.test',
            onBack: () => backCount++,
            onPlayTrack: (track, queue, index) {
              playedTitle = track.title;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _ProducerDetailFakeHttpClient());

    expect(
      find.byKey(const ValueKey('producer-detail-mobile-app-bar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('producer-detail-mobile-hero')),
      findsOneWidget,
    );
    expect(find.text('DECO*27'), findsWidgets);
    expect(find.text('2 首歌曲 · 1 张专辑 · 1 个MV'), findsOneWidget);
    expect(find.text('播放全部'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('producer-detail-mobile-shuffle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('producer-detail-mobile-tabs')),
      findsOneWidget,
    );
    expect(find.text('专辑 1'), findsOneWidget);
    expect(find.text('歌曲 2'), findsOneWidget);
    expect(find.text('MV 1'), findsOneWidget);
    expect(find.text('GHOST'), findsOneWidget);
    expect(find.text('2 首歌曲'), findsWidgets);

    await tester.tap(find.text('播放全部'));
    expect(playedTitle, 'Track A');

    await tester.tap(find.byIcon(Icons.chevron_left));
    expect(backCount, 1);
  });

  testWidgets('mobile tracks tab uses mobile rows instead of desktop table', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          child: ProducerDetailScreen(
            producer: _producer,
            baseUrl: 'http://example.test',
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _ProducerDetailFakeHttpClient());

    await tester.tap(find.text('歌曲 2'));
    await tester.pumpAndSettle();

    expect(find.text('Title / Vocalists'), findsNothing);
    expect(find.text('Tags / MV'), findsNothing);
    expect(
      find.byKey(const ValueKey('producer-track-mobile-row-1')),
      findsOneWidget,
    );
    expect(find.text('Track A'), findsOneWidget);
    expect(find.text('DECO*27 feat. 初音ミク'), findsOneWidget);
    expect(find.text('03:45'), findsOneWidget);
    expect(find.text('MV'), findsOneWidget);
    expect(find.text('FLAC'), findsOneWidget);
  });

  testWidgets('mobile MV tab uses populated local MV state', (tester) async {
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          child: ProducerDetailScreen(
            producer: _producer,
            baseUrl: 'http://example.test',
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _ProducerDetailFakeHttpClient());

    await tester.tap(find.text('MV 1'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('producer-mv-mobile-grid')),
      findsOneWidget,
    );
    expect(find.text('Track A'), findsOneWidget);
    expect(find.text('本地MV'), findsOneWidget);
  });

  testWidgets('desktop producer detail keeps desktop tab labels', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        _harness(
          size: const Size(1024, 768),
          child: ProducerDetailScreen(
            producer: _producer,
            baseUrl: 'http://example.test',
          ),
        ),
      );
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _ProducerDetailFakeHttpClient());

    expect(find.text('ALBUMS'), findsOneWidget);
    expect(find.text('ALL TRACKS'), findsOneWidget);
    expect(find.text('LOCAL MVs'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('producer-detail-mobile-hero')),
      findsNothing,
    );
  });

  testWidgets('producer track list mobile layout is opt-in', (tester) async {
    await tester.pumpWidget(
      _harness(
        size: const Size(390, 844),
        child: Scaffold(
          body: ProducerTrackList(
            tracks: const [
              Track(
                id: 1,
                title: 'Track A',
                audioPath: '/audio/a.flac',
                videoPath: '',
              ),
            ],
            baseUrl: 'http://example.test',
            onPlay: (_, __) {},
          ),
        ),
      ),
    );

    expect(find.text('Title / Vocalists'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('producer-track-mobile-row-1')),
      findsNothing,
    );
  });

  testWidgets(
    'producer detail pull-to-refresh updates visible data and cache',
    (tester) async {
      final client = _SequencedProducerDetailHttpClient([
        const _ProducerDetailResponseSet(
          producerName: 'Initial P',
          albumTitle: 'Initial Album',
          trackTitle: 'Initial Track',
        ),
        const _ProducerDetailResponseSet(
          producerName: 'Refreshed P',
          albumTitle: 'Refreshed Album',
          trackTitle: 'Refreshed Track',
          trackId: 2,
          trackCount: 2,
        ),
      ]);

      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(
          _harness(
            size: const Size(390, 844),
            child: ProducerDetailScreen(
              producer: _producer,
              baseUrl: 'http://example.test',
              onBack: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Initial Album'), findsOneWidget);

        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, 500),
          1000,
        );
        await tester.pump();
        await tester.pumpAndSettle();
      }, createHttpClient: (_) => client);

      expect(find.text('Refreshed P'), findsWidgets);
      expect(find.text('Refreshed Album'), findsOneWidget);
      expect(
        ProducerDetailDataCache.read(
          baseUrl: 'http://example.test',
          producerId: 27,
        )?.tracks.single.title,
        'Refreshed Track',
      );
      expect(client.completedResponses, 2);
    },
  );

  testWidgets('producer detail refresh failure keeps visible data', (
    tester,
  ) async {
    final client = _FailingAfterFirstProducerHttpClient(
      const _ProducerDetailResponseSet(
        producerName: 'Stable P',
        albumTitle: 'Stable Album',
        trackTitle: 'Stable Track',
      ),
    );

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          child: ProducerDetailScreen(
            producer: _producer,
            baseUrl: 'http://example.test',
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Stable Album'), findsOneWidget);

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 500),
        1000,
      );
      await tester.pump();
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => client);

    expect(find.text('Stable Album'), findsOneWidget);
    expect(find.text('刷新失败，请稍后再试'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('producer detail initial failure without cache shows retry', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          child: ProducerDetailScreen(
            producer: _producer,
            baseUrl: 'http://example.test',
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _AlwaysFailingProducerHttpClient());

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('刷新失败，请稍后再试'), findsNothing);
  });

  testWidgets('producer detail initial null response shows retry', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          child: ProducerDetailScreen(
            producer: _producer,
            baseUrl: 'http://example.test',
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _ProducerNotFoundHttpClient());

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('刷新失败，请稍后再试'), findsNothing);
  });

  testWidgets('producer detail refresh failure keeps empty producer page', (
    tester,
  ) async {
    final client = _NullAfterFirstProducerHttpClient(
      const _ProducerDetailResponseSet(
        producerName: 'Empty P',
        albumTitle: '',
        trackTitle: '',
        trackCount: 0,
        albumCount: 0,
        includeAlbum: false,
        includeTrack: false,
      ),
    );

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          child: ProducerDetailScreen(
            producer: _producer,
            baseUrl: 'http://example.test',
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Empty P'), findsWidgets);
      expect(find.text('0 首歌曲 · 0 张专辑 · 0 个MV'), findsOneWidget);

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 500),
        1000,
      );
      await tester.pump();
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => client);

    expect(find.text('Empty P'), findsWidgets);
    expect(find.text('0 首歌曲 · 0 张专辑 · 0 个MV'), findsOneWidget);
    expect(find.text('刷新失败，请稍后再试'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
}

class _ProducerDetailResponseSet {
  const _ProducerDetailResponseSet({
    required this.producerName,
    required this.albumTitle,
    required this.trackTitle,
    this.trackCount = 1,
    this.albumCount = 1,
    this.trackId = 1,
    this.includeAlbum = true,
    this.includeTrack = true,
  });

  final String producerName;
  final String albumTitle;
  final String trackTitle;
  final int trackCount;
  final int albumCount;
  final int trackId;
  final bool includeAlbum;
  final bool includeTrack;

  Map<String, dynamic> toJson() {
    return {
      'producer': {
        'id': 27,
        'name': producerName,
        'track_count': trackCount,
        'album_count': albumCount,
      },
      'albums': includeAlbum
          ? [
              {
                'id': 39,
                'title': albumTitle,
                'producer_id': 27,
                'producer_name': producerName,
                'year': 2021,
                'track_count': trackCount,
              },
            ]
          : [],
      'tracks': includeTrack
          ? [
              {
                'id': trackId,
                'title': trackTitle,
                'audio_path': '/audio/$trackId.flac',
                'video_path': '',
                'video_thumb_path': '',
                'duration_seconds': 225,
                'format': 'FLAC',
                'composer': producerName,
                'vocal': '初音ミク',
              },
            ]
          : [],
    };
  }
}

class _NeverCompletingCountingProducerHttpClient implements HttpClient {
  int requestCount = 0;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requestCount++;
    return _NeverCompletingProducerRequest();
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    requestCount++;
    return _NeverCompletingProducerRequest();
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NeverCompletingProducerRequest implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() => Completer<HttpClientResponse>().future;

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding _) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SingleProducerDetailHttpClient implements HttpClient {
  _SingleProducerDetailHttpClient(this.responseSet);

  final _ProducerDetailResponseSet responseSet;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _SingleProducerDetailRequest(url, responseSet);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _SingleProducerDetailRequest(url, responseSet);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SingleProducerDetailRequest implements HttpClientRequest {
  _SingleProducerDetailRequest(this.url, this.responseSet);

  final Uri url;
  final _ProducerDetailResponseSet responseSet;
  bool _followRedirects = true;
  int _maxRedirects = 5;
  int _contentLength = 0;
  bool _persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async =>
      _ProducerDetailResponse(url, responseSet);

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding _) {}

  @override
  bool get followRedirects => _followRedirects;

  @override
  set followRedirects(bool value) {
    _followRedirects = value;
  }

  @override
  int get maxRedirects => _maxRedirects;

  @override
  set maxRedirects(int value) {
    _maxRedirects = value;
  }

  @override
  int get contentLength => _contentLength;

  @override
  set contentLength(int value) {
    _contentLength = value;
  }

  @override
  bool get persistentConnection => _persistentConnection;

  @override
  set persistentConnection(bool value) {
    _persistentConnection = value;
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SequencedProducerDetailHttpClient implements HttpClient {
  _SequencedProducerDetailHttpClient(this.responseSets);

  final List<_ProducerDetailResponseSet> responseSets;
  int completedResponses = 0;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _SequencedProducerDetailRequest(url, this);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _SequencedProducerDetailRequest(url, this);

  _ProducerDetailResponseSet nextResponse() {
    final index = completedResponses.clamp(0, responseSets.length - 1);
    completedResponses++;
    return responseSets[index];
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SequencedProducerDetailRequest implements HttpClientRequest {
  _SequencedProducerDetailRequest(this.url, this.client);

  final Uri url;
  final _SequencedProducerDetailHttpClient client;
  bool _followRedirects = true;
  int _maxRedirects = 5;
  int _contentLength = 0;
  bool _persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async {
    if (url.path == '/api/producers/27') {
      return _ProducerDetailResponse(url, client.nextResponse());
    }
    return _ProducerDetailResponse(url, client.responseSets.first);
  }

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding _) {}

  @override
  bool get followRedirects => _followRedirects;

  @override
  set followRedirects(bool value) {
    _followRedirects = value;
  }

  @override
  int get maxRedirects => _maxRedirects;

  @override
  set maxRedirects(int value) {
    _maxRedirects = value;
  }

  @override
  int get contentLength => _contentLength;

  @override
  set contentLength(int value) {
    _contentLength = value;
  }

  @override
  bool get persistentConnection => _persistentConnection;

  @override
  set persistentConnection(bool value) {
    _persistentConnection = value;
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingAfterFirstProducerHttpClient implements HttpClient {
  _FailingAfterFirstProducerHttpClient(this.firstResponse);

  final _ProducerDetailResponseSet firstResponse;
  int requestCount = 0;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _FailingAfterFirstProducerRequest(url, this);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FailingAfterFirstProducerRequest(url, this);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingAfterFirstProducerRequest implements HttpClientRequest {
  _FailingAfterFirstProducerRequest(this.url, this.client);

  final Uri url;
  final _FailingAfterFirstProducerHttpClient client;
  bool _followRedirects = true;
  int _maxRedirects = 5;
  int _contentLength = 0;
  bool _persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async {
    if (url.path == '/api/producers/27') {
      client.requestCount++;
    }
    if (client.requestCount <= 1) {
      return _ProducerDetailResponse(url, client.firstResponse);
    }
    throw const SocketException('refresh failed');
  }

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding _) {}

  @override
  bool get followRedirects => _followRedirects;

  @override
  set followRedirects(bool value) {
    _followRedirects = value;
  }

  @override
  int get maxRedirects => _maxRedirects;

  @override
  set maxRedirects(int value) {
    _maxRedirects = value;
  }

  @override
  int get contentLength => _contentLength;

  @override
  set contentLength(int value) {
    _contentLength = value;
  }

  @override
  bool get persistentConnection => _persistentConnection;

  @override
  set persistentConnection(bool value) {
    _persistentConnection = value;
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AlwaysFailingProducerHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _AlwaysFailingProducerRequest();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _AlwaysFailingProducerRequest();

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AlwaysFailingProducerRequest implements HttpClientRequest {
  bool _followRedirects = true;
  int _maxRedirects = 5;
  int _contentLength = 0;
  bool _persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async {
    throw const SocketException('initial failed');
  }

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding _) {}

  @override
  bool get followRedirects => _followRedirects;

  @override
  set followRedirects(bool value) {
    _followRedirects = value;
  }

  @override
  int get maxRedirects => _maxRedirects;

  @override
  set maxRedirects(int value) {
    _maxRedirects = value;
  }

  @override
  int get contentLength => _contentLength;

  @override
  set contentLength(int value) {
    _contentLength = value;
  }

  @override
  bool get persistentConnection => _persistentConnection;

  @override
  set persistentConnection(bool value) {
    _persistentConnection = value;
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProducerNotFoundHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _ProducerNotFoundRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _ProducerNotFoundRequest(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProducerNotFoundRequest implements HttpClientRequest {
  _ProducerNotFoundRequest(this.url);

  final Uri url;
  bool _followRedirects = true;
  int _maxRedirects = 5;
  int _contentLength = 0;
  bool _persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async {
    return _ProducerNotFoundResponse(url);
  }

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding _) {}

  @override
  bool get followRedirects => _followRedirects;

  @override
  set followRedirects(bool value) {
    _followRedirects = value;
  }

  @override
  int get maxRedirects => _maxRedirects;

  @override
  set maxRedirects(int value) {
    _maxRedirects = value;
  }

  @override
  int get contentLength => _contentLength;

  @override
  set contentLength(int value) {
    _contentLength = value;
  }

  @override
  bool get persistentConnection => _persistentConnection;

  @override
  set persistentConnection(bool value) {
    _persistentConnection = value;
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NullAfterFirstProducerHttpClient implements HttpClient {
  _NullAfterFirstProducerHttpClient(this.firstResponse);

  final _ProducerDetailResponseSet firstResponse;
  int requestCount = 0;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _NullAfterFirstProducerRequest(url, this);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _NullAfterFirstProducerRequest(url, this);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NullAfterFirstProducerRequest implements HttpClientRequest {
  _NullAfterFirstProducerRequest(this.url, this.client);

  final Uri url;
  final _NullAfterFirstProducerHttpClient client;
  bool _followRedirects = true;
  int _maxRedirects = 5;
  int _contentLength = 0;
  bool _persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async {
    if (url.path == '/api/producers/27') {
      client.requestCount++;
    }
    if (client.requestCount <= 1) {
      return _ProducerDetailResponse(url, client.firstResponse);
    }
    return _ProducerNotFoundResponse(url);
  }

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding _) {}

  @override
  bool get followRedirects => _followRedirects;

  @override
  set followRedirects(bool value) {
    _followRedirects = value;
  }

  @override
  int get maxRedirects => _maxRedirects;

  @override
  set maxRedirects(int value) {
    _maxRedirects = value;
  }

  @override
  int get contentLength => _contentLength;

  @override
  set contentLength(int value) {
    _contentLength = value;
  }

  @override
  bool get persistentConnection => _persistentConnection;

  @override
  set persistentConnection(bool value) {
    _persistentConnection = value;
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProducerDetailResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _ProducerDetailResponse(Uri url, _ProducerDetailResponseSet responseSet)
    : _bytes = utf8.encode(_bodyFor(url, responseSet));

  final List<int> _bytes;

  static String _bodyFor(Uri url, _ProducerDetailResponseSet responseSet) {
    if (url.path == '/api/producers/27') {
      return jsonEncode(responseSet.toJson());
    }
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"></svg>';
  }

  @override
  int get contentLength => _bytes.length;

  @override
  int get statusCode => HttpStatus.ok;

  @override
  HttpHeaders get headers => _ProducerDetailFakeHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<Cookie> get cookies => const [];

  @override
  Future<Socket> detachSocket() {
    throw UnimplementedError();
  }

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  String get reasonPhrase => 'OK';

  @override
  bool get persistentConnection => false;

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) {
    throw UnimplementedError();
  }

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> data)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProducerNotFoundResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _ProducerNotFoundResponse(Uri url)
    : _bytes = utf8.encode(
        url.path == '/api/producers/27'
            ? '{}'
            : '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"></svg>',
      );

  final List<int> _bytes;

  @override
  int get contentLength => _bytes.length;

  @override
  int get statusCode => HttpStatus.notFound;

  @override
  HttpHeaders get headers => _ProducerDetailFakeHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<Cookie> get cookies => const [];

  @override
  Future<Socket> detachSocket() {
    throw UnimplementedError();
  }

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  String get reasonPhrase => 'Not Found';

  @override
  bool get persistentConnection => false;

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) {
    throw UnimplementedError();
  }

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> data)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProducerDetailFakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _ProducerDetailFakeHttpClientRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _ProducerDetailFakeHttpClientRequest(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedProducerDetailFakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _DelayedProducerDetailFakeHttpClientRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _DelayedProducerDetailFakeHttpClientRequest(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedProducerDetailFakeHttpClientRequest implements HttpClientRequest {
  _DelayedProducerDetailFakeHttpClientRequest(this.url);

  final Uri url;

  @override
  Future<HttpClientResponse> close() async {
    await Completer<void>().future;
    return _ProducerDetailFakeHttpClientResponse(url);
  }

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding _) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProducerDetailFakeHttpClientRequest implements HttpClientRequest {
  _ProducerDetailFakeHttpClientRequest(this.url);

  final Uri url;
  bool _followRedirects = true;
  int _maxRedirects = 5;
  int _contentLength = 0;
  bool _persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async =>
      _ProducerDetailFakeHttpClientResponse(url);

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding _) {}

  @override
  bool get followRedirects => _followRedirects;

  @override
  set followRedirects(bool value) {
    _followRedirects = value;
  }

  @override
  int get maxRedirects => _maxRedirects;

  @override
  set maxRedirects(int value) {
    _maxRedirects = value;
  }

  @override
  int get contentLength => _contentLength;

  @override
  set contentLength(int value) {
    _contentLength = value;
  }

  @override
  bool get persistentConnection => _persistentConnection;

  @override
  set persistentConnection(bool value) {
    _persistentConnection = value;
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProducerDetailFakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _ProducerDetailFakeHttpClientResponse(Uri url)
    : _bytes = utf8.encode(_bodyFor(url));

  final List<int> _bytes;

  static String _bodyFor(Uri url) {
    return switch (url.path) {
      '/api/producers/27' => jsonEncode({
        'producer': {
          'id': 27,
          'name': 'DECO*27',
          'track_count': 2,
          'album_count': 1,
        },
        'albums': [
          {
            'id': 39,
            'title': 'GHOST',
            'producer_id': 27,
            'producer_name': 'DECO*27',
            'year': 2021,
            'track_count': 2,
          },
        ],
        'tracks': [
          {
            'id': 1,
            'title': 'Track A',
            'audio_path': '/audio/a.flac',
            'video_path': '/video/a.mp4',
            'video_thumb_path': '/thumb/a.jpg',
            'duration_seconds': 225,
            'format': 'FLAC',
            'composer': 'DECO*27',
            'vocal': '初音ミク',
          },
          {
            'id': 2,
            'title': 'Track B',
            'audio_path': '/audio/b.flac',
            'video_path': '',
            'duration_seconds': 180,
          },
        ],
      }),
      _ => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"></svg>',
    };
  }

  @override
  int get contentLength => _bytes.length;

  @override
  int get statusCode => HttpStatus.ok;

  @override
  HttpHeaders get headers => _ProducerDetailFakeHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<Cookie> get cookies => const [];

  @override
  Future<Socket> detachSocket() {
    throw UnimplementedError();
  }

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  String get reasonPhrase => 'OK';

  @override
  bool get persistentConnection => false;

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) {
    throw UnimplementedError();
  }

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> data)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProducerDetailFakeHttpHeaders implements HttpHeaders {
  static const Map<String, List<String>> _values = {
    HttpHeaders.contentTypeHeader: ['application/json'],
  };

  @override
  List<String>? operator [](String name) {
    return _values[name.toLowerCase()];
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
