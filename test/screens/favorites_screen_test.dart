import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/screens/favorites_screen.dart';
import 'package:mikudrome/services/playlist_repository.dart';

void main() {
  setUp(() {
    PlaylistRepository.instance.favoriteTrackIds.clear();
  });

  tearDown(() {
    PlaylistRepository.instance.favoriteTrackIds.clear();
  });

  testWidgets('removes favorites through the favorites endpoint', (
    tester,
  ) async {
    final httpClient = _FavoritesRecordingHttpClient();

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FavoritesScreen(baseUrl: 'http://127.0.0.1:8080'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Favorite Song'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      expect(find.text('Remove from favorites'), findsOneWidget);

      await tester.tap(find.text('Remove from favorites'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }, createHttpClient: (_) => httpClient);

    expect(httpClient.requests, contains('DELETE /api/favorites/7'));
    expect(httpClient.requests, isNot(contains('POST /api/favorites/7')));
    expect(PlaylistRepository.instance.isFavorite(7), isFalse);
  });
}

class _FavoritesRecordingHttpClient implements HttpClient {
  final requests = <String>[];
  bool favoriteRemoved = false;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => openUrl('GET', url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    requests.add('$method ${url.path}');
    return _FavoritesRecordingHttpClientRequest(this, method, url);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FavoritesRecordingHttpClientRequest implements HttpClientRequest {
  _FavoritesRecordingHttpClientRequest(this.client, this.method, this.url);

  final _FavoritesRecordingHttpClient client;
  @override
  final String method;
  final Uri url;
  bool _followRedirects = true;
  int _maxRedirects = 5;
  int _contentLength = 0;
  bool _persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async {
    if (method == 'DELETE' && url.path == '/api/favorites/7') {
      client.favoriteRemoved = true;
    }
    return _FavoritesRecordingHttpClientResponse(
      method: method,
      url: url,
      favoriteRemoved: client.favoriteRemoved,
    );
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

class _FavoritesRecordingHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FavoritesRecordingHttpClientResponse({
    required String method,
    required Uri url,
    required bool favoriteRemoved,
  }) : statusCode = _statusCodeFor(method, url),
       _bytes = utf8.encode(_bodyFor(method, url, favoriteRemoved));

  final List<int> _bytes;

  @override
  final int statusCode;

  static int _statusCodeFor(String method, Uri url) {
    if ((method == 'DELETE' || method == 'POST') &&
        url.path == '/api/favorites/7') {
      return HttpStatus.noContent;
    }
    return HttpStatus.ok;
  }

  static String _bodyFor(String method, Uri url, bool favoriteRemoved) {
    if (url.path == '/api/favorites') {
      return jsonEncode({
        'tracks': favoriteRemoved
            ? []
            : [
                {
                  'id': 7,
                  'title': 'Favorite Song',
                  'audio_path': 'favorite.flac',
                  'video_path': '',
                  'album_id': 1,
                  'duration_seconds': 210,
                  'composer': 'DECO*27',
                  'vocal': '初音ミク',
                  'is_favorite': true,
                },
              ],
      });
    }
    return '<svg xmlns="http://www.w3.org/2000/svg" />';
  }

  @override
  int get contentLength => _bytes.length;

  @override
  HttpHeaders get headers => _FavoritesRecordingHttpHeaders();

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
  String get reasonPhrase =>
      statusCode == HttpStatus.noContent ? 'No Content' : 'OK';

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

class _FavoritesRecordingHttpHeaders implements HttpHeaders {
  static const Map<String, List<String>> _values = {
    HttpHeaders.contentTypeHeader: ['application/json'],
  };

  @override
  List<String>? operator [](String name) => _values[name.toLowerCase()];

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
