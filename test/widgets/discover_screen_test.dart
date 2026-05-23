import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/album.dart';
import 'package:mikudrome/models/daily_recommendations.dart';
import 'package:mikudrome/models/producer.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/models/video.dart';
import 'package:mikudrome/models/vocalist.dart';
import 'package:mikudrome/widgets/discover/discover_data_cache.dart';
import 'package:mikudrome/widgets/discover_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Widget _harness(Widget child) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  setUp(DiscoverDataCache.clear);

  test('DiscoverDataCache stores and clears process-local data', () {
    DiscoverDataCache.clear();

    const data = DiscoverData(
      albums: [],
      producers: [],
      vocalists: [],
      videos: [],
    );

    DiscoverDataCache.write(data);

    expect(DiscoverDataCache.current, same(data));

    DiscoverDataCache.clear();

    expect(DiscoverDataCache.current, isNull);
  });

  testWidgets('DiscoverScreen shows section tabs by default', (tester) async {
    await tester.pumpWidget(_harness(const DiscoverScreen(child: Text('内容'))));

    expect(find.text('专辑'), findsOneWidget);
    expect(find.text('P主'), findsOneWidget);
    expect(find.text('歌手'), findsOneWidget);
    expect(find.text('内容'), findsOneWidget);
  });

  testWidgets('DiscoverScreen can hide section tabs for detail pages', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        const DiscoverScreen(showSectionTabs: false, child: Text('详情内容')),
      ),
    );

    expect(find.text('专辑'), findsNothing);
    expect(find.text('P主'), findsNothing);
    expect(find.text('歌手'), findsNothing);
    expect(find.text('详情内容'), findsOneWidget);
  });

  testWidgets('DiscoverScreen shows a mobile recommendation home', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(_harness(const DiscoverScreen()));
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _DiscoverFakeHttpClient());

    expect(find.text('发现'), findsOneWidget);
    expect(find.text('搜索歌曲、专辑、P主、MV...'), findsOneWidget);
    expect(find.text('专辑推荐'), findsOneWidget);
    expect(find.text('热门P主'), findsOneWidget);
    expect(find.text('GHOST'), findsWidgets);
    expect(find.text('DECO*27'), findsWidgets);
    expect(find.text('专辑'), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -360));
    await tester.pumpAndSettle();

    expect(find.text('虚拟歌手'), findsOneWidget);
    expect(find.text('推荐MV'), findsOneWidget);
    expect(find.text('初音ミク'), findsWidgets);
    expect(find.text('愛言葉V'), findsWidgets);
  });

  testWidgets('mobile recommendation home renders cached data immediately', (
    tester,
  ) async {
    DiscoverDataCache.write(
      const DiscoverData(
        albums: [
          Album(
            id: 'cached-album',
            title: 'Cached Album',
            coverUrl: '',
            producerId: 1,
            producerName: 'Cached Producer',
            trackCount: 1,
          ),
        ],
        producers: [
          Producer(id: 9, name: 'Cached P', trackCount: 1, albumCount: 1),
        ],
        vocalists: [
          Vocalist(name: 'Cached Vocal', trackCount: 1, albumCount: 1),
        ],
        videos: [
          Video(
            id: 9,
            title: 'Cached MV',
            durationSeconds: 60,
            composer: 'Cached Producer',
            vocal: 'Cached Vocal',
          ),
        ],
        dailyRecommendations: null,
      ),
    );

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(_harness(const DiscoverScreen()));
      await tester.pump();
    }, createHttpClient: (_) => _NeverCompletingDiscoverHttpClient());

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Cached Album'), findsWidgets);
    expect(find.text('Cached Producer'), findsWidgets);
    expect(find.text('Cached P'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -360));
    await tester.pump();

    expect(find.text('Cached Vocal'), findsWidgets);
    expect(find.text('Cached MV'), findsOneWidget);
  });

  testWidgets(
    'mobile recommendation home does not reload cached data on open',
    (tester) async {
      DiscoverDataCache.write(
        const DiscoverData(
          albums: [
            Album(
              id: 'cached-album',
              title: 'Cached Album',
              coverUrl: '',
              producerName: 'Cached Producer',
              trackCount: 1,
            ),
          ],
          producers: [],
          vocalists: [],
          videos: [],
          dailyRecommendations: null,
        ),
      );
      final client = _NeverCompletingCountingDiscoverHttpClient();

      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(_harness(const DiscoverScreen()));
        await tester.pump();
      }, createHttpClient: (_) => client);

      expect(find.text('Cached Album'), findsWidgets);
      expect(client.requestCount, 0);
    },
  );

  testWidgets('mobile recommendation home reopens from cache without loading', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(_harness(const DiscoverScreen()));
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _DiscoverFakeHttpClient());

    expect(find.text('GHOST'), findsWidgets);
    expect(DiscoverDataCache.current?.albums.first.title, 'GHOST');

    final client = _NeverCompletingCountingDiscoverHttpClient();

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(_harness(const SizedBox.shrink()));
      await tester.pump();
      await tester.pumpWidget(_harness(const DiscoverScreen()));
      await tester.pump();
    }, createHttpClient: (_) => client);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('GHOST'), findsWidgets);
    expect(client.requestCount, 0);
  });

  testWidgets('mobile recommendation home refreshes and updates cached data', (
    tester,
  ) async {
    final client = _SequencedDiscoverFakeHttpClient([
      const _DiscoverResponseSet(
        albumTitle: 'Initial Album',
        producerName: 'Initial P',
      ),
      const _DiscoverResponseSet(
        albumTitle: 'Refreshed Album',
        producerName: 'Refreshed P',
      ),
    ]);

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(_harness(const DiscoverScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Initial Album'), findsWidgets);

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 500),
        1000,
      );
      await tester.pump();
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => client);

    expect(find.text('Refreshed Album'), findsWidgets);
    expect(find.text('Refreshed P'), findsWidgets);
    expect(DiscoverDataCache.current?.albums.first.title, 'Refreshed Album');
    expect(client.completedResponseSets, 2);
  });

  testWidgets('mobile recommendation home shows daily recommendations module', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(_harness(const DiscoverScreen()));
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _DiscoverFakeHttpClient());

    expect(find.text('每日推荐'), findsOneWidget);
    expect(find.text('2026-05-22'), findsOneWidget);
    expect(find.textContaining('Daily One'), findsOneWidget);
    expect(find.textContaining('Daily Two'), findsOneWidget);
  });

  testWidgets(
    'mobile recommendation home renders cached daily recommendations',
    (tester) async {
      DiscoverDataCache.write(
        const DiscoverData(
          albums: [],
          producers: [],
          vocalists: [],
          videos: [],
          dailyRecommendations: DailyRecommendations(
            date: '2026-05-22',
            tracks: [
              Track(
                id: 301,
                title: 'Cached Daily',
                audioPath: 'cached-daily.flac',
                videoPath: '',
              ),
            ],
          ),
        ),
      );

      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(_harness(const DiscoverScreen()));
        await tester.pump();
      }, createHttpClient: (_) => _NeverCompletingDiscoverHttpClient());

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('每日推荐'), findsOneWidget);
      expect(find.text('2026-05-22'), findsOneWidget);
      expect(find.textContaining('Cached Daily'), findsOneWidget);
    },
  );

  testWidgets(
    'mobile recommendation home keeps discover content when daily recommendations fail',
    (tester) async {
      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(_harness(const DiscoverScreen()));
        await tester.pumpAndSettle();
      }, createHttpClient: (_) => _FailingDailyDiscoverHttpClient());

      expect(find.text('专辑推荐'), findsOneWidget);
      expect(find.text('热门P主'), findsOneWidget);
      expect(find.text('GHOST'), findsWidgets);
      expect(find.text('DECO*27'), findsWidgets);
      expect(find.text('每日推荐'), findsOneWidget);
      expect(find.text('加载失败，重试'), findsOneWidget);
    },
  );

  testWidgets(
    'mobile recommendation home renders core content while daily recommendations are still loading',
    (tester) async {
      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(_harness(const DiscoverScreen()));
        await tester.pump();
        await tester.pump();
      }, createHttpClient: (_) => _LoadingDailyDiscoverHttpClient());

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('专辑推荐'), findsOneWidget);
      expect(find.text('热门P主'), findsOneWidget);
      expect(find.text('GHOST'), findsWidgets);
      expect(find.text('暂无推荐歌曲'), findsOneWidget);
    },
  );

  testWidgets(
    'mobile recommendation home preserves cached daily recommendations when refresh daily fails',
    (tester) async {
      final client = _FailingDailyRefreshDiscoverHttpClient([
        const _DiscoverResponseSet(
          albumTitle: 'Initial Album',
          producerName: 'Initial P',
          dailyTitle: 'Daily One',
        ),
        const _DiscoverResponseSet(
          albumTitle: 'Refreshed Album',
          producerName: 'Refreshed P',
          dailyTitle: 'Daily Two',
        ),
      ]);

      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(_harness(const DiscoverScreen()));
        await tester.pumpAndSettle();

        expect(
          DiscoverDataCache.current?.dailyRecommendations?.tracks.first.title,
          'Daily One',
        );

        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, 500),
          1000,
        );
        await tester.pump();
        await tester.pumpAndSettle();
      }, createHttpClient: (_) => client);

      expect(find.text('Refreshed Album'), findsWidgets);
      expect(find.text('加载失败，重试'), findsOneWidget);
      expect(
        DiscoverDataCache.current?.dailyRecommendations?.tracks.first.title,
        'Daily One',
      );
    },
  );

  testWidgets(
    'mobile recommendation home keeps visible data when refresh fails',
    (tester) async {
      final client = _FailingAfterFirstDiscoverHttpClient(
        const _DiscoverResponseSet(
          albumTitle: 'Stable Album',
          producerName: 'Stable P',
        ),
      );

      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(_harness(const DiscoverScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Stable Album'), findsWidgets);

        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, 500),
          1000,
        );
        await tester.pump();
        await tester.pumpAndSettle();
      }, createHttpClient: (_) => client);

      expect(find.text('Stable Album'), findsWidgets);
      expect(find.text('Failed to refresh discover data'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    },
  );
}

class _DiscoverFakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _DiscoverFakeHttpClientRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _DiscoverFakeHttpClientRequest(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingDailyDiscoverHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    if (url.path == '/api/recommendations/daily') {
      throw const SocketException('daily failed');
    }
    return _DiscoverFakeHttpClientRequest(url);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => getUrl(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LoadingDailyDiscoverHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    if (url.path == '/api/recommendations/daily') {
      return Completer<HttpClientRequest>().future;
    }
    return Future.value(_DiscoverFakeHttpClientRequest(url));
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => getUrl(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NeverCompletingDiscoverHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) =>
      Completer<HttpClientRequest>().future;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      Completer<HttpClientRequest>().future;

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NeverCompletingCountingDiscoverHttpClient implements HttpClient {
  int requestCount = 0;

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    requestCount++;
    return Completer<HttpClientRequest>().future;
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => getUrl(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DiscoverFakeHttpClientRequest implements HttpClientRequest {
  _DiscoverFakeHttpClientRequest(this.url);

  final Uri url;
  bool _followRedirects = true;
  int _maxRedirects = 5;
  int _contentLength = 0;
  bool _persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async =>
      _DiscoverFakeHttpClientResponse(url);

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

class _DiscoverFakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _DiscoverFakeHttpClientResponse(Uri url)
    : _bytes = utf8.encode(_bodyFor(url));

  final List<int> _bytes;

  static String _bodyFor(Uri url) {
    return switch (url.path) {
      '/api/albums' => jsonEncode({
        'albums': [
          {
            'id': 1,
            'title': 'GHOST',
            'producer_name': 'DECO*27',
            'track_count': 12,
          },
          {
            'id': 2,
            'title': '25時、ナイトコードで。',
            'producer_name': 'Neru',
            'track_count': 8,
          },
        ],
      }),
      '/api/producers' => jsonEncode({
        'producers': [
          {'id': 1, 'name': 'DECO*27', 'track_count': 27, 'album_count': 3},
          {'id': 2, 'name': 'ryo', 'track_count': 12, 'album_count': 1},
        ],
      }),
      '/api/vocalists' => jsonEncode({
        'vocalists': [
          {'name': '初音ミク', 'track_count': 30, 'album_count': 4},
          {'name': '鏡音リン', 'track_count': 10, 'album_count': 2},
        ],
      }),
      '/api/videos' => jsonEncode({
        'videos': [
          {
            'id': 1,
            'title': '愛言葉V - DECO*27 feat. 初音ミク',
            'duration_seconds': 240,
            'composer': 'DECO*27',
            'vocal': '初音ミク',
          },
        ],
      }),
      '/api/recommendations/daily' => jsonEncode({
        'date': '2026-05-22',
        'tracks': [
          {
            'id': 101,
            'title': 'Daily One',
            'audio_path': 'daily-one.flac',
            'video_path': '',
            'duration_seconds': 180,
            'composer': 'Daily Composer',
            'vocal': '初音ミク',
          },
          {
            'id': 102,
            'title': 'Daily Two',
            'audio_path': 'daily-two.flac',
            'video_path': '',
            'duration_seconds': 200,
            'composer': 'Daily Composer',
            'vocal': '鏡音リン',
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
  HttpHeaders get headers => _DiscoverFakeHttpHeaders();

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

class _DiscoverResponseSet {
  const _DiscoverResponseSet({
    required this.albumTitle,
    required this.producerName,
    this.dailyTitle = 'Daily One',
  });

  final String albumTitle;
  final String producerName;
  final String dailyTitle;
}

class _SequencedDiscoverFakeHttpClient implements HttpClient {
  _SequencedDiscoverFakeHttpClient(this._responses);

  final List<_DiscoverResponseSet> _responses;
  int _requestCount = 0;

  int get completedResponseSets => _requestCount ~/ 5;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _SequencedDiscoverFakeHttpClientRequest(url, _responseForNextRequest());

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _SequencedDiscoverFakeHttpClientRequest(url, _responseForNextRequest());

  _DiscoverResponseSet _responseForNextRequest() {
    final index = (_requestCount ~/ 5).clamp(0, _responses.length - 1);
    _requestCount++;
    return _responses[index];
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingAfterFirstDiscoverHttpClient
    extends _SequencedDiscoverFakeHttpClient {
  _FailingAfterFirstDiscoverHttpClient(_DiscoverResponseSet first)
    : super([first]);

  int _failingClientRequestCount = 0;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    _failingClientRequestCount++;
    if (_failingClientRequestCount > 5) {
      throw const SocketException('refresh failed');
    }
    return _SequencedDiscoverFakeHttpClientRequest(
      url,
      _responseForNextRequest(),
    );
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => getUrl(url);
}

class _FailingDailyRefreshDiscoverHttpClient
    extends _SequencedDiscoverFakeHttpClient {
  _FailingDailyRefreshDiscoverHttpClient(super.responses);

  int _dailyRequestCount = 0;

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    if (url.path == '/api/recommendations/daily') {
      _dailyRequestCount++;
      if (_dailyRequestCount > 1) {
        throw const SocketException('daily failed');
      }
    }
    return super.getUrl(url);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => getUrl(url);
}

class _SequencedDiscoverFakeHttpClientRequest implements HttpClientRequest {
  _SequencedDiscoverFakeHttpClientRequest(this.url, this.response);

  final Uri url;
  final _DiscoverResponseSet response;
  bool _followRedirects = true;
  int _maxRedirects = 5;
  int _contentLength = 0;
  bool _persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async =>
      _SequencedDiscoverFakeHttpClientResponse(url, response);

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

class _SequencedDiscoverFakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _SequencedDiscoverFakeHttpClientResponse(
    Uri url,
    _DiscoverResponseSet response,
  ) : _bytes = utf8.encode(_bodyFor(url, response));

  final List<int> _bytes;

  static String _bodyFor(Uri url, _DiscoverResponseSet response) {
    return switch (url.path) {
      '/api/albums' => jsonEncode({
        'albums': [
          {
            'id': 1,
            'title': response.albumTitle,
            'producer_name': response.producerName,
            'track_count': 12,
          },
        ],
      }),
      '/api/producers' => jsonEncode({
        'producers': [
          {
            'id': 1,
            'name': response.producerName,
            'track_count': 27,
            'album_count': 3,
          },
        ],
      }),
      '/api/vocalists' => jsonEncode({
        'vocalists': [
          {'name': '初音ミク', 'track_count': 30, 'album_count': 4},
        ],
      }),
      '/api/videos' => jsonEncode({
        'videos': [
          {
            'id': 1,
            'title': '${response.albumTitle} MV',
            'duration_seconds': 240,
            'composer': response.producerName,
            'vocal': '初音ミク',
          },
        ],
      }),
      '/api/recommendations/daily' => jsonEncode({
        'date': '2026-05-22',
        'tracks': [
          {
            'id': 101,
            'title': response.dailyTitle,
            'audio_path': '${response.dailyTitle}.flac',
            'video_path': '',
            'duration_seconds': 180,
            'composer': response.producerName,
            'vocal': '初音ミク',
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
  HttpHeaders get headers => _DiscoverFakeHttpHeaders();

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

class _DiscoverFakeHttpHeaders implements HttpHeaders {
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
