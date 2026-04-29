import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
    await tester.pumpAndSettle();

    expect(find.text('虚拟歌手'), findsOneWidget);
    expect(find.text('推荐MV'), findsOneWidget);
    expect(find.text('初音ミク'), findsWidgets);
    expect(find.text('愛言葉V'), findsWidgets);
  });
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
