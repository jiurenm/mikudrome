import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/producer.dart';
import 'package:mikudrome/screens/producer_detail_screen.dart';

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
