import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/screens/library_home_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

void main() {
  testWidgets('initial mobile discover tab uses recommendation home', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester);
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _LibraryFakeHttpClient());

    expect(find.text('发现'), findsWidgets);
    expect(find.text('专辑推荐'), findsOneWidget);
    expect(find.text('热门P主'), findsOneWidget);
    expect(find.text('GHOST'), findsWidgets);
  });

  testWidgets('system back returns to the previous mobile tab', (tester) async {
    late bool handled;
    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(find.text('服务器'), findsOneWidget);

      handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _LibraryFakeHttpClient());

    expect(handled, isTrue);
    expect(find.text('专辑推荐'), findsOneWidget);
    expect(find.text('服务器'), findsNothing);
  });

  testWidgets(
    'discover more opens the full mobile section and back restores home',
    (tester) async {
      late bool handled;
      await HttpOverrides.runZoned(() async {
        await _pumpMobileLibrary(tester);
        await tester.pumpAndSettle();

        await tester.tap(find.text('更多 >').first);
        await tester.pumpAndSettle();

        expect(find.text('Albums'), findsOneWidget);
        expect(find.text('专辑推荐'), findsNothing);

        handled = await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }, createHttpClient: (_) => _LibraryFakeHttpClient());

      expect(handled, isTrue);
      expect(find.text('专辑推荐'), findsOneWidget);
      expect(find.text('Albums'), findsNothing);
    },
  );

  testWidgets('system back returns from a mobile destination to My Music', (
    tester,
  ) async {
    await _pumpMobileLibrary(tester);

    await tester.tap(find.text('我的音乐'));
    await tester.pumpAndSettle();
    expect(find.text('收藏'), findsOneWidget);

    await tester.tap(find.text('歌单'));
    await tester.pumpAndSettle();
    expect(find.text('收藏'), findsNothing);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('歌单'), findsOneWidget);
  });
}

class _LibraryFakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _LibraryFakeHttpClientRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _LibraryFakeHttpClientRequest(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LibraryFakeHttpClientRequest implements HttpClientRequest {
  _LibraryFakeHttpClientRequest(this.url);

  final Uri url;
  bool _followRedirects = true;
  int _maxRedirects = 5;
  int _contentLength = 0;
  bool _persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async =>
      _LibraryFakeHttpClientResponse(url);

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

class _LibraryFakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _LibraryFakeHttpClientResponse(Uri url) : _bytes = utf8.encode(_bodyFor(url));

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
        ],
      }),
      '/api/producers' => jsonEncode({
        'producers': [
          {'id': 1, 'name': 'DECO*27', 'track_count': 27, 'album_count': 3},
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
  HttpHeaders get headers => _LibraryFakeHttpHeaders();

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

class _LibraryFakeHttpHeaders implements HttpHeaders {
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

Future<void> _pumpMobileLibrary(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  return tester.pumpWidget(const MaterialApp(home: LibraryHomeScreen()));
}
