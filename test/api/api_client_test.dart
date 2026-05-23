import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/api/api_client.dart';
import 'package:mikudrome/api/config.dart';
import 'package:mikudrome/models/daily_recommendations.dart';
import 'package:mikudrome/screens/library_home_screen.dart';

void main() {
  tearDown(ApiConfig.resetRuntimeConfigForTests);

  test('empty baseUrl falls back to runtime config', () async {
    ApiConfig.setRuntimeBaseUrl('http://192.168.1.10:8080');
    final client = ApiClient(baseUrl: '');
    final httpClient = _RecordingHttpClient();

    await HttpOverrides.runZoned(() async {
      await client.addFavorite(7);
    }, createHttpClient: (_) => httpClient);

    expect(httpClient.requests, [
      'POST http://192.168.1.10:8080/api/favorites/7',
    ]);
  });

  test('savePlaybackHistory posts expected JSON payload', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final requestBody = Completer<Map<String, dynamic>>();
    unawaited(
      server.listen((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/playback/history');
        expect(request.headers.contentType?.mimeType, 'application/json');
        requestBody.complete(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
      }).asFuture<void>(),
    );
    final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');

    await client.savePlaybackHistory(
      trackId: 7,
      positionMs: 12000,
      durationMs: 30000,
      mode: PlaybackMode.video,
      contextLabel: 'Album / Test',
    );

    expect(await requestBody.future, {
      'track_id': 7,
      'position_ms': 12000,
      'duration_ms': 30000,
      'playback_mode': 'video',
      'context_label': 'Album / Test',
    });
  });

  test('getPlaybackHistory decodes items', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(
      server.listen((request) async {
        expect(request.method, 'GET');
        expect(request.uri.path, '/api/playback/history');
        expect(request.uri.queryParameters['limit'], '1');
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'items': [
              {
                'track': {
                  'id': 7,
                  'title': 'Track',
                  'audio_path': '/track.flac',
                },
                'position_ms': 12000,
                'duration_ms': 30000,
                'playback_mode': 'audio',
                'context_label': 'Album / Test',
                'played_at': 1779072000,
              },
            ],
          }),
        );
        await request.response.close();
      }).asFuture<void>(),
    );
    final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');

    final items = await client.getPlaybackHistory(limit: 1);

    expect(items, hasLength(1));
    expect(items.single.track.id, 7);
    expect(items.single.positionMs, 12000);
    expect(items.single.durationMs, 30000);
    expect(items.single.mode, PlaybackMode.audio);
    expect(items.single.contextLabel, 'Album / Test');
    expect(items.single.playedAt, 1779072000);
  });

  test('getDailyRecommendations decodes date and tracks', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(
      server.listen((request) async {
        expect(request.method, 'GET');
        expect(request.uri.path, '/api/recommendations/daily');
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'date': '2026-05-22',
            'tracks': [
              {
                'id': 7,
                'title': 'Daily Track',
                'audio_path': '/daily.flac',
                'duration_seconds': 180,
                'composer': 'kz',
                'vocal': '初音ミク',
                'is_favorite': true,
              },
            ],
          }),
        );
        await request.response.close();
      }).asFuture<void>(),
    );
    final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');

    final recommendations = await client.getDailyRecommendations();

    expect(recommendations, isA<DailyRecommendations>());
    expect(recommendations.date, '2026-05-22');
    expect(recommendations.tracks, hasLength(1));
    expect(recommendations.tracks.single.id, 7);
    expect(recommendations.tracks.single.title, 'Daily Track');
    expect(recommendations.tracks.single.isFavorite, isTrue);
  });
}

class _RecordingHttpClient implements HttpClient {
  final requests = <String>[];

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => openUrl('GET', url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    requests.add('$method ${url.toString()}');
    return _RecordingHttpClientRequest();
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingHttpClientRequest implements HttpClientRequest {
  bool _followRedirects = true;
  int _maxRedirects = 5;
  int _contentLength = 0;
  bool _persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async => _RecordingHttpClientResponse();

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

class _RecordingHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.noContent;

  @override
  int get contentLength => 0;

  @override
  HttpHeaders get headers => _RecordingHttpHeaders();

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
  String get reasonPhrase => 'No Content';

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
    return const Stream<List<int>>.empty().listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingHttpHeaders implements HttpHeaders {
  @override
  List<String>? operator [](String name) => null;

  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
