import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/api/config.dart';
import 'package:mikudrome/screens/mv_gallery_screen.dart';

Widget _harness({required Size size, required Widget child}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  setUp(() {
    ApiConfig.setRuntimeBaseUrl('http://example.test');
  });

  tearDown(ApiConfig.resetRuntimeConfigForTests);

  testWidgets(
    'mobile MV gallery keeps header and search fixed while grid scrolls',
    (tester) async {
      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(
          _harness(size: const Size(390, 844), child: const MvGalleryScreen()),
        );
        await tester.pumpAndSettle();
      }, createHttpClient: (_) => _MvGalleryFakeHttpClient());

      final titleFinder = find.text('MV Gallery');
      final searchFinder = find.byKey(const ValueKey('mv-gallery-search'));
      final scrollFinder = find.byKey(const ValueKey('mv-gallery-scroll'));

      expect(titleFinder, findsOneWidget);
      expect(searchFinder, findsOneWidget);
      expect(scrollFinder, findsOneWidget);

      final initialTitleTop = tester.getTopLeft(titleFinder).dy;
      final initialSearchTop = tester.getTopLeft(searchFinder).dy;

      await tester.drag(scrollFinder, const Offset(0, -520));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(titleFinder).dy, initialTitleTop);
      expect(tester.getTopLeft(searchFinder).dy, initialSearchTop);
    },
  );

  testWidgets('mobile MV gallery reserves space for collapsed mini player', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        _harness(size: const Size(390, 844), child: const MvGalleryScreen()),
      );
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _MvGalleryFakeHttpClient());

    final gridPadding = tester.widget<SliverPadding>(
      find.byKey(const ValueKey('mv-gallery-grid-padding')),
    );

    expect(gridPadding.padding.resolve(TextDirection.ltr).bottom, 136);
  });
}

class _MvGalleryFakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _MvGalleryFakeHttpClientRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _MvGalleryFakeHttpClientRequest(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MvGalleryFakeHttpClientRequest implements HttpClientRequest {
  _MvGalleryFakeHttpClientRequest(this.url);

  final Uri url;
  bool _followRedirects = true;
  int _maxRedirects = 5;
  int _contentLength = 0;
  bool _persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async =>
      _MvGalleryFakeHttpClientResponse(url);

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

class _MvGalleryFakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _MvGalleryFakeHttpClientResponse(Uri url)
    : _bytes = utf8.encode(_bodyFor(url));

  final List<int> _bytes;

  static String _bodyFor(Uri url) {
    if (url.path == '/api/videos') {
      return jsonEncode({
        'videos': [
          for (var i = 1; i <= 18; i++)
            {
              'id': i,
              'title':
                  'Video ${i.toString().padLeft(2, '0')} - Producer feat. Miku',
              'artist': 'Producer feat. Miku',
              'duration_seconds': 180 + i,
              'composer': 'Producer',
              'vocal': 'Miku',
            },
        ],
      });
    }
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"></svg>';
  }

  @override
  int get contentLength => _bytes.length;

  @override
  int get statusCode => HttpStatus.ok;

  @override
  HttpHeaders get headers => _MvGalleryFakeHttpHeaders();

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

class _MvGalleryFakeHttpHeaders implements HttpHeaders {
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
