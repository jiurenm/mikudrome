import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/vocalist.dart';
import 'package:mikudrome/screens/vocalists_screen.dart';

Widget _harness({required Size size, required Widget child}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('mobile vocalists page uses compact app list rows', (
    tester,
  ) async {
    Vocalist? selectedVocalist;

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          child: VocalistsScreen(
            onVocalistTap: (vocalist) {
              selectedVocalist = vocalist;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _VocalistsFakeHttpClient());

    expect(find.text('歌手'), findsOneWidget);
    expect(find.text('共 2 位歌手'), findsOneWidget);
    expect(find.text('Vocalists'), findsNothing);
    expect(find.byKey(const ValueKey('vocalist-mobile-list')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vocalist-mobile-row-Hatsune Miku')),
      findsOneWidget,
    );
    expect(find.text('Hatsune Miku'), findsOneWidget);
    expect(find.text('39 首歌曲'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('vocalist-mobile-row-Hatsune Miku')),
    );
    expect(selectedVocalist?.name, 'Hatsune Miku');
  });

  testWidgets('mobile vocalists search filters loaded vocalists by name', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        _harness(size: const Size(390, 844), child: const VocalistsScreen()),
      );
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _VocalistsFakeHttpClient());

    await tester.enterText(
      find.byKey(const ValueKey('vocalist-mobile-search')),
      'rin',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('vocalist-mobile-row-Kagamine Rin')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('vocalist-mobile-row-Hatsune Miku')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const ValueKey('vocalist-mobile-search')),
      'luka',
    );
    await tester.pumpAndSettle();

    expect(find.text('没有找到匹配的歌手'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vocalist-mobile-row-Kagamine Rin')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const ValueKey('vocalist-mobile-search')),
      '',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('vocalist-mobile-row-Kagamine Rin')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('vocalist-mobile-row-Hatsune Miku')),
      findsOneWidget,
    );
  });
}

class _VocalistsFakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _VocalistsFakeHttpClientRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _VocalistsFakeHttpClientRequest(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _VocalistsFakeHttpClientRequest implements HttpClientRequest {
  _VocalistsFakeHttpClientRequest(this.url);

  final Uri url;
  bool _followRedirects = true;
  int _maxRedirects = 5;
  int _contentLength = 0;
  bool _persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async =>
      _VocalistsFakeHttpClientResponse(url);

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

class _VocalistsFakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _VocalistsFakeHttpClientResponse(Uri url)
    : _bytes = utf8.encode(_bodyFor(url));

  final List<int> _bytes;

  static String _bodyFor(Uri url) {
    return switch (url.path) {
      '/api/vocalists' => jsonEncode({
        'vocalists': [
          {'name': 'Hatsune Miku', 'track_count': 39, 'album_count': 4},
          {'name': 'Kagamine Rin', 'track_count': 12, 'album_count': 2},
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
  HttpHeaders get headers => _VocalistsFakeHttpHeaders();

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

class _VocalistsFakeHttpHeaders implements HttpHeaders {
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
