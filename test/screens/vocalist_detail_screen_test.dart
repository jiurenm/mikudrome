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

    testWidgets('hero action controls wrap on narrow mobile widths', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          size: const Size(320, 568),
          child: VocalistHeroSection(
            name: '初音ミク',
            avatarUrl: 'http://example.test/avatar.svg',
            color: AppTheme.mikuGreen,
            trackCount: 39,
            albumCount: 4,
            mvCount: 7,
            hasTracks: true,
            onPlayAll: () {},
            onShuffle: () {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('播放全部'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('vocalist-detail-mobile-shuffle')),
        findsOneWidget,
      );
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

    testWidgets('mobile empty detail load shows loaded zero counts', (
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
      }, createHttpClient: (_) => _EmptyVocalistDetailHttpClient());

      expect(find.text('0 首歌曲 · 0 张专辑 · 0 个MV'), findsOneWidget);
      expect(find.text('专辑 0'), findsOneWidget);
      expect(find.text('歌曲 0'), findsOneWidget);
      expect(find.text('MV 0'), findsOneWidget);
      expect(find.text('39 首歌曲 · 4 张专辑 · 0 个MV'), findsNothing);
    });

    testWidgets('mobile tracks tab uses mobile rows instead of desktop table', (
      tester,
    ) async {
      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(
          _harness(
            size: const Size(390, 844),
            child: VocalistDetailScreen(
              vocalist: const Vocalist(name: '初音ミク'),
              onBack: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
      }, createHttpClient: (_) => _VocalistDetailFakeHttpClient());

      await tester.tap(find.text('歌曲 2'));
      await tester.pumpAndSettle();

      expect(find.text('Title / Vocalists'), findsNothing);
      expect(find.text('Tags / MV'), findsNothing);
      expect(
        find.byKey(const ValueKey('producer-track-mobile-row-1')),
        findsOneWidget,
      );
      expect(find.text('Tell Your World'), findsOneWidget);
      expect(find.text('kz feat. 初音ミク'), findsOneWidget);
      expect(find.text('03:45'), findsOneWidget);
      expect(find.text('FLAC'), findsOneWidget);
    });

    testWidgets('mobile MV tab only shows local MV tracks', (tester) async {
      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(
          _harness(
            size: const Size(390, 844),
            child: VocalistDetailScreen(
              vocalist: const Vocalist(name: '初音ミク'),
              onBack: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
      }, createHttpClient: (_) => _VocalistDetailFakeHttpClient());

      await tester.tap(find.text('MV 1'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('producer-mv-mobile-grid')),
        findsOneWidget,
      );
      expect(find.text('Tell Your World'), findsOneWidget);
      expect(find.text('Unknown Mother-Goose'), findsNothing);
      expect(find.text('本地MV'), findsOneWidget);
    });

    testWidgets('mobile tabs render localized empty states', (tester) async {
      await HttpOverrides.runZoned(
        () async {
          await tester.pumpWidget(
            _harness(
              size: const Size(390, 844),
              child: VocalistDetailScreen(
                vocalist: const Vocalist(name: '初音ミク'),
                onBack: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();
        },
        createHttpClient: (_) => _VocalistDetailFakeHttpClient(
          responseSet: const _VocalistDetailResponseSet(
            name: '初音ミク',
            albumTitle: '',
            firstTrackTitle: '',
            secondTrackTitle: '',
            includeAlbum: false,
            includeTracks: false,
          ),
        ),
      );

      expect(find.text('还没有专辑'), findsOneWidget);

      await tester.tap(find.text('歌曲 0'));
      await tester.pumpAndSettle();

      expect(find.text('还没有歌曲'), findsOneWidget);

      await tester.tap(find.text('MV 0'));
      await tester.pumpAndSettle();

      expect(find.text('还没有本地MV'), findsOneWidget);
    });

    testWidgets('mobile refresh failure preserves empty detail page', (
      tester,
    ) async {
      final client = _FailingAfterEmptyVocalistDetailHttpClient();

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

        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, 500),
          1000,
        );
        await tester.pump();
        await tester.pumpAndSettle();
      }, createHttpClient: (_) => client);

      expect(find.text('0 首歌曲 · 0 张专辑 · 0 个MV'), findsOneWidget);
      expect(find.text('刷新失败，请稍后再试'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('mobile detail uses initial counts while loading', (
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
        await tester.pump();
      }, createHttpClient: (_) => _NeverCompletingVocalistHttpClient());

      expect(find.text('39 首歌曲 · 4 张专辑 · 0 个MV'), findsOneWidget);
      expect(find.text('专辑 4'), findsOneWidget);
      expect(find.text('歌曲 39'), findsOneWidget);
      expect(find.text('MV 0'), findsOneWidget);
    });

    testWidgets('mobile pull-to-refresh updates visible data', (tester) async {
      final client = _SequencedVocalistHttpClient([
        const _VocalistDetailResponseSet(
          name: '初音ミク',
          albumTitle: 'Initial Album',
          firstTrackTitle: 'Initial Track',
          secondTrackTitle: 'Initial B-side',
        ),
        const _VocalistDetailResponseSet(
          name: '初音ミク',
          albumTitle: 'Refreshed Album',
          firstTrackTitle: 'Refreshed Track',
          secondTrackTitle: 'Refreshed B-side',
          firstTrackId: 3,
          secondTrackId: 4,
        ),
      ]);

      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(
          _harness(
            size: const Size(390, 844),
            child: VocalistDetailScreen(
              vocalist: const Vocalist(name: '初音ミク'),
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

      expect(find.text('Refreshed Album'), findsOneWidget);
      expect(client.completedResponses, 2);
    });

    testWidgets('mobile refresh failure keeps visible data', (tester) async {
      final client = _FailingAfterFirstVocalistHttpClient(
        const _VocalistDetailResponseSet(
          name: '初音ミク',
          albumTitle: 'Stable Album',
          firstTrackTitle: 'Stable Track',
          secondTrackTitle: 'Stable B-side',
        ),
      );

      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(
          _harness(
            size: const Size(390, 844),
            child: VocalistDetailScreen(
              vocalist: const Vocalist(name: '初音ミク'),
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

    testWidgets('mobile initial failure shows retry', (tester) async {
      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(
          _harness(
            size: const Size(390, 844),
            child: VocalistDetailScreen(
              vocalist: const Vocalist(name: '初音ミク'),
              onBack: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
      }, createHttpClient: (_) => _AlwaysFailingVocalistHttpClient());

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('刷新失败，请稍后再试'), findsNothing);
    });

    testWidgets('desktop detail does not render mobile hero or tabs', (
      tester,
    ) async {
      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(
          _harness(
            size: const Size(1024, 768),
            child: const VocalistDetailScreen(vocalist: Vocalist(name: '初音ミク')),
          ),
        );
        await tester.pumpAndSettle();
      }, createHttpClient: (_) => _VocalistDetailFakeHttpClient());

      expect(
        find.byKey(const ValueKey('vocalist-detail-mobile-hero')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('vocalist-detail-mobile-tabs')),
        findsNothing,
      );
      expect(find.text('All Tracks'), findsOneWidget);
    });

    testWidgets('desktop shuffle keeps original queue order', (tester) async {
      Track? playedTrack;
      List<Track> playedQueue = const [];
      var playedIndex = -1;

      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(
          _harness(
            size: const Size(1024, 768),
            child: VocalistDetailScreen(
              vocalist: const Vocalist(name: '初音ミク'),
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

      await tester.tap(find.text('Shuffle Play'));

      expect(playedQueue.map((track) => track.title), [
        'Tell Your World',
        'Unknown Mother-Goose',
      ]);
      expect(playedQueue.contains(playedTrack), isTrue);
      expect(playedIndex, 0);
    });

    testWidgets('not found detail displays stable not found message', (
      tester,
    ) async {
      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(
          _harness(
            size: const Size(390, 844),
            child: VocalistDetailScreen(
              vocalist: const Vocalist(name: '初音ミク'),
              onBack: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
      }, createHttpClient: (_) => _VocalistNotFoundHttpClient());

      expect(find.text('Vocalist not found'), findsOneWidget);
      expect(find.text('Bad state: Vocalist not found'), findsNothing);
    });
  });
}

class _VocalistDetailFakeHttpClient implements HttpClient {
  _VocalistDetailFakeHttpClient({
    this.responseSet = const _VocalistDetailResponseSet(),
  });

  final _VocalistDetailResponseSet responseSet;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _VocalistDetailFakeHttpClientRequest(url, responseSet: responseSet);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _VocalistDetailFakeHttpClientRequest(url, responseSet: responseSet);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyVocalistDetailHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _EmptyVocalistDetailHttpClientRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _EmptyVocalistDetailHttpClientRequest(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingAfterEmptyVocalistDetailHttpClient implements HttpClient {
  int _requestCount = 0;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => openUrl('GET', url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    _requestCount++;
    if (_requestCount == 1) return _EmptyVocalistDetailHttpClientRequest(url);
    return _FailingVocalistDetailHttpClientRequest(url);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NeverCompletingVocalistHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _NeverCompletingVocalistRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _NeverCompletingVocalistRequest(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SequencedVocalistHttpClient implements HttpClient {
  _SequencedVocalistHttpClient(this._responses);

  final List<_VocalistDetailResponseSet> _responses;
  int _requestCount = 0;
  int completedResponses = 0;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => openUrl('GET', url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (_isVocalistTracksUrl(url)) {
      final index = _requestCount.clamp(0, _responses.length - 1);
      _requestCount++;
      return _SequencedVocalistRequest(
        url,
        this,
        responseSet: _responses[index],
      );
    }
    return _VocalistDetailFakeHttpClientRequest(url);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingAfterFirstVocalistHttpClient implements HttpClient {
  _FailingAfterFirstVocalistHttpClient(this._firstResponse);

  final _VocalistDetailResponseSet _firstResponse;
  int _requestCount = 0;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => openUrl('GET', url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (_isVocalistTracksUrl(url)) {
      _requestCount++;
      if (_requestCount == 1) {
        return _FailingAfterFirstVocalistRequest(
          url,
          responseSet: _firstResponse,
        );
      }
      return _FailingVocalistDetailHttpClientRequest(url);
    }
    return _VocalistDetailFakeHttpClientRequest(url);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AlwaysFailingVocalistHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => openUrl('GET', url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (_isVocalistTracksUrl(url)) {
      return _AlwaysFailingVocalistRequest(url);
    }
    return _VocalistDetailFakeHttpClientRequest(url);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _VocalistNotFoundHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => openUrl('GET', url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (_isVocalistTracksUrl(url)) {
      return _VocalistNotFoundRequest(url);
    }
    return _VocalistDetailFakeHttpClientRequest(url);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _VocalistDetailFakeHttpClientRequest implements HttpClientRequest {
  _VocalistDetailFakeHttpClientRequest(
    this.url, {
    this.responseSet = const _VocalistDetailResponseSet(),
  });

  final Uri url;
  final _VocalistDetailResponseSet responseSet;
  bool _followRedirects = true;
  int _maxRedirects = 5;
  int _contentLength = 0;
  bool _persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async =>
      _VocalistDetailFakeHttpClientResponse(url, responseSet: responseSet);

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

class _EmptyVocalistDetailHttpClientRequest
    extends _VocalistDetailFakeHttpClientRequest {
  _EmptyVocalistDetailHttpClientRequest(super.url);

  @override
  Future<HttpClientResponse> close() async =>
      _EmptyVocalistDetailHttpClientResponse(url);
}

class _FailingVocalistDetailHttpClientRequest
    extends _VocalistDetailFakeHttpClientRequest {
  _FailingVocalistDetailHttpClientRequest(super.url);

  @override
  Future<HttpClientResponse> close() async =>
      _FailingVocalistDetailHttpClientResponse(url);
}

class _NeverCompletingVocalistRequest
    extends _VocalistDetailFakeHttpClientRequest {
  _NeverCompletingVocalistRequest(super.url);

  @override
  Future<HttpClientResponse> close() => Completer<HttpClientResponse>().future;
}

class _SequencedVocalistRequest extends _VocalistDetailFakeHttpClientRequest {
  _SequencedVocalistRequest(super.url, this._client, {super.responseSet});

  final _SequencedVocalistHttpClient _client;

  @override
  Future<HttpClientResponse> close() async {
    _client.completedResponses++;
    return _VocalistDetailFakeHttpClientResponse(url, responseSet: responseSet);
  }
}

class _FailingAfterFirstVocalistRequest
    extends _VocalistDetailFakeHttpClientRequest {
  _FailingAfterFirstVocalistRequest(super.url, {super.responseSet});

  @override
  Future<HttpClientResponse> close() async =>
      _VocalistDetailFakeHttpClientResponse(url, responseSet: responseSet);
}

class _AlwaysFailingVocalistRequest
    extends _VocalistDetailFakeHttpClientRequest {
  _AlwaysFailingVocalistRequest(super.url);

  @override
  Future<HttpClientResponse> close() async =>
      _FailingVocalistDetailHttpClientResponse(url);
}

class _VocalistNotFoundRequest extends _VocalistDetailFakeHttpClientRequest {
  _VocalistNotFoundRequest(super.url);

  @override
  Future<HttpClientResponse> close() async => _VocalistNotFoundResponse(url);
}

class _VocalistDetailFakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _VocalistDetailFakeHttpClientResponse(
    Uri url, {
    _VocalistDetailResponseSet responseSet = const _VocalistDetailResponseSet(),
  }) : _bytes = utf8.encode(_bodyFor(url, responseSet));

  final List<int> _bytes;

  static String _bodyFor(Uri url, _VocalistDetailResponseSet responseSet) {
    if (url.path.contains('/api/vocalists/') && url.path.endsWith('/tracks')) {
      return jsonEncode({
        'name': responseSet.name,
        'albums': [
          if (responseSet.includeAlbum)
            {
              'id': 39,
              'title': responseSet.albumTitle,
              'producer_name': 'kz',
              'track_count': 2,
            },
        ],
        'tracks': [
          if (responseSet.includeTracks)
            {
              'id': responseSet.firstTrackId,
              'title': responseSet.firstTrackTitle,
              'audio_path': '/audio/1.flac',
              'video_path': '/video/1.mp4',
              'video_thumb_path': '/thumb/1.jpg',
              'duration_seconds': 225,
              'format': 'FLAC',
              'composer': 'kz',
              'vocal': '初音ミク',
            },
          if (responseSet.includeTracks)
            {
              'id': responseSet.secondTrackId,
              'title': responseSet.secondTrackTitle,
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

class _EmptyVocalistDetailHttpClientResponse
    extends _VocalistDetailFakeHttpClientResponse {
  _EmptyVocalistDetailHttpClientResponse(super.url);

  @override
  int get statusCode => HttpStatus.ok;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> data)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final body = utf8.encode(
      jsonEncode({'name': '初音ミク', 'albums': [], 'tracks': []}),
    );
    return Stream<List<int>>.fromIterable([body]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _FailingVocalistDetailHttpClientResponse
    extends _VocalistDetailFakeHttpClientResponse {
  _FailingVocalistDetailHttpClientResponse(super.url);

  @override
  int get statusCode => HttpStatus.internalServerError;

  @override
  String get reasonPhrase => 'Internal Server Error';
}

class _VocalistNotFoundResponse extends _VocalistDetailFakeHttpClientResponse {
  _VocalistNotFoundResponse(super.url);

  @override
  int get statusCode => HttpStatus.notFound;

  @override
  String get reasonPhrase => 'Not Found';
}

class _VocalistDetailResponseSet {
  const _VocalistDetailResponseSet({
    this.name = '初音ミク',
    this.albumTitle = 'Miku Expo',
    this.firstTrackTitle = 'Tell Your World',
    this.secondTrackTitle = 'Unknown Mother-Goose',
    this.firstTrackId = 1,
    this.secondTrackId = 2,
    this.includeAlbum = true,
    this.includeTracks = true,
  });

  final String name;
  final String albumTitle;
  final String firstTrackTitle;
  final String secondTrackTitle;
  final int firstTrackId;
  final int secondTrackId;
  final bool includeAlbum;
  final bool includeTracks;
}

bool _isVocalistTracksUrl(Uri url) =>
    url.path.contains('/api/vocalists/') && url.path.endsWith('/tracks');

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
