import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/models/vocalist.dart';
import 'package:mikudrome/screens/vocalist_detail_screen.dart';
import 'package:mikudrome/theme/app_theme.dart';
import 'package:mikudrome/widgets/vocalist_detail/vocalist_hero_section.dart';
import 'package:mikudrome/widgets/vocalist_detail/vocalist_tab_bar.dart';

Widget _harness({required Size size, required Widget child}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('vocalist detail mobile widgets', () {
    testWidgets('hero renders vocalist atmosphere actions and counts', (
      tester,
    ) async {
      var playAllCount = 0;
      var shuffleCount = 0;

      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          child: VocalistHeroSection(
            name: '初音ミク',
            avatarUrl: 'http://example.test/avatar.svg',
            color: AppTheme.mikuGreen,
            trackCount: 39,
            albumCount: 4,
            mvCount: 7,
            hasTracks: true,
            onPlayAll: () => playAllCount++,
            onShuffle: () => shuffleCount++,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('vocalist-detail-mobile-hero')),
        findsOneWidget,
      );
      expect(find.text('初音ミク'), findsOneWidget);
      expect(find.text('39 首歌曲 · 4 张专辑 · 7 个MV'), findsOneWidget);
      expect(find.text('播放全部'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('vocalist-detail-mobile-shuffle')),
        findsOneWidget,
      );

      await tester.tap(find.text('播放全部'));
      await tester.tap(
        find.byKey(const ValueKey('vocalist-detail-mobile-shuffle')),
      );

      expect(playAllCount, 1);
      expect(shuffleCount, 1);
    });

    testWidgets('tab bar renders stable mobile segments and changes index', (
      tester,
    ) async {
      var selected = 0;

      await tester.pumpWidget(
        _harness(
          size: const Size(390, 844),
          child: StatefulBuilder(
            builder: (context, setState) {
              return VocalistTabBar(
                index: selected,
                albumCount: 4,
                trackCount: 39,
                mvCount: 7,
                color: AppTheme.mikuGreen,
                onTap: (value) => setState(() => selected = value),
              );
            },
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('vocalist-detail-mobile-tabs')),
        findsOneWidget,
      );
      expect(find.text('专辑 4'), findsOneWidget);
      expect(find.text('歌曲 39'), findsOneWidget);
      expect(find.text('MV 7'), findsOneWidget);

      await tester.tap(find.text('歌曲 39'));
      await tester.pump();

      expect(selected, 1);
    });
  });

  group('VocalistDetailScreen mobile redesign', () {
    testWidgets('mobile detail renders atmosphere hero and tabbed albums', (
      tester,
    ) async {
      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(
          _harness(
            size: const Size(390, 844),
            child: VocalistDetailScreen(
              vocalist: const Vocalist(
                name: '初音ミク',
                trackCount: 39,
                albumCount: 4,
              ),
              onBack: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
      }, createHttpClient: (_) => _VocalistDetailFakeHttpClient());

      expect(
        find.byKey(const ValueKey('vocalist-detail-mobile-app-bar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('vocalist-detail-mobile-hero')),
        findsOneWidget,
      );
      expect(find.text('初音ミク'), findsWidgets);
      expect(find.text('2 首歌曲 · 1 张专辑 · 1 个MV'), findsOneWidget);
      expect(find.text('播放全部'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('vocalist-detail-mobile-shuffle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('vocalist-detail-mobile-tabs')),
        findsOneWidget,
      );
      expect(find.text('专辑 1'), findsOneWidget);
      expect(find.text('歌曲 2'), findsOneWidget);
      expect(find.text('MV 1'), findsOneWidget);
      expect(find.text('Miku Expo'), findsOneWidget);
    });

    testWidgets('mobile play all starts first loaded vocalist track', (
      tester,
    ) async {
      Track? playedTrack;
      List<Track> playedQueue = const [];
      var playedIndex = -1;

      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(
          _harness(
            size: const Size(390, 844),
            child: VocalistDetailScreen(
              vocalist: const Vocalist(
                name: '初音ミク',
                trackCount: 39,
                albumCount: 4,
              ),
              onBack: () {},
              onPlayTrack: (track, queue, index) {
                playedTrack = track;
                playedQueue = queue;
                playedIndex = index;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
      }, createHttpClient: (_) => _VocalistDetailFakeHttpClient());

      await tester.tap(find.text('播放全部'));

      expect(playedTrack?.title, 'Tell Your World');
      expect(playedQueue.map((track) => track.title), [
        'Tell Your World',
        'Unknown Mother-Goose',
      ]);
      expect(playedIndex, 0);
    });

    testWidgets('mobile shuffle starts a shuffled vocalist queue', (
      tester,
    ) async {
      Track? playedTrack;
      List<Track> playedQueue = const [];
      var playedIndex = -1;

      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(
          _harness(
            size: const Size(390, 844),
            child: VocalistDetailScreen(
              vocalist: const Vocalist(
                name: '初音ミク',
                trackCount: 39,
                albumCount: 4,
              ),
              onBack: () {},
              onPlayTrack: (track, queue, index) {
                playedTrack = track;
                playedQueue = queue;
                playedIndex = index;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
      }, createHttpClient: (_) => _VocalistDetailFakeHttpClient());

      await tester.tap(
        find.byKey(const ValueKey('vocalist-detail-mobile-shuffle')),
      );

      expect(playedQueue, hasLength(2));
      expect(
        playedQueue.map((track) => track.title),
        containsAll(['Tell Your World', 'Unknown Mother-Goose']),
      );
      expect(playedTrack?.title, playedQueue.first.title);
      expect(playedIndex, 0);
    });
  });
}

class _VocalistDetailFakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _VocalistDetailFakeHttpClientRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _VocalistDetailFakeHttpClientRequest(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _VocalistDetailFakeHttpClientRequest implements HttpClientRequest {
  _VocalistDetailFakeHttpClientRequest(this.url);

  final Uri url;
  bool _followRedirects = true;
  int _maxRedirects = 5;
  int _contentLength = 0;
  bool _persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async =>
      _VocalistDetailFakeHttpClientResponse(url);

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

class _VocalistDetailFakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _VocalistDetailFakeHttpClientResponse(Uri url)
    : _bytes = utf8.encode(_bodyFor(url));

  final List<int> _bytes;

  static String _bodyFor(Uri url) {
    if (url.path.contains('/api/vocalists/') && url.path.endsWith('/tracks')) {
      return jsonEncode({
        'name': '初音ミク',
        'albums': [
          {
            'id': 39,
            'title': 'Miku Expo',
            'producer_name': 'kz',
            'track_count': 2,
          },
        ],
        'tracks': [
          {
            'id': 1,
            'title': 'Tell Your World',
            'audio_path': '/audio/1.flac',
            'video_path': '/video/1.mp4',
            'video_thumb_path': '/thumb/1.jpg',
            'duration_seconds': 225,
            'format': 'FLAC',
            'composer': 'kz',
            'vocal': '初音ミク',
          },
          {
            'id': 2,
            'title': 'Unknown Mother-Goose',
            'audio_path': '/audio/2.flac',
            'video_path': '',
            'duration_seconds': 180,
            'format': 'MP3',
            'composer': 'wowaka',
            'vocal': '初音ミク',
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
  HttpHeaders get headers => _VocalistDetailFakeHttpHeaders();

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

class _VocalistDetailFakeHttpHeaders implements HttpHeaders {
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
