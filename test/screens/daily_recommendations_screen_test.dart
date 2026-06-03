import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/api/api_client.dart';
import 'package:mikudrome/models/daily_recommendations.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/screens/daily_recommendations_screen.dart';

void main() {
  testWidgets(
    'mobile layout uses one in-page title with compact back control',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var backCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: DailyRecommendationsScreen(
            client: _DailyRecommendationsClient(_daily),
            onBack: () => backCount += 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('每日推荐'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      expect(backCount, 1);
    },
  );

  testWidgets('renders populated daily recommendations and play all', (
    tester,
  ) async {
    List<Track>? playedQueue;
    int? playedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: DailyRecommendationsScreen(
          client: _DailyRecommendationsClient(_daily),
          onPlayTrack: (track, queue, index) {
            playedQueue = queue;
            playedIndex = index;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('每日推荐'), findsWidgets);
    expect(find.text('2026-05-22'), findsOneWidget);
    expect(find.text('Daily One'), findsOneWidget);
    expect(find.text('Daily Two'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '播放全部'));
    expect(playedQueue?.map((track) => track.id), [301, 302]);
    expect(playedIndex, 0);

    await tester.tap(find.text('Daily Two'));
    expect(playedQueue?.map((track) => track.id), [301, 302]);
    expect(playedIndex, 1);
  });

  testWidgets('renders empty daily recommendations state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DailyRecommendationsScreen(
          client: _DailyRecommendationsClient(
            const DailyRecommendations(date: '2026-05-22', tracks: []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无推荐歌曲'), findsOneWidget);
  });

  testWidgets('renders retry state after load failure', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DailyRecommendationsScreen(
          client: _FailingDailyRecommendationsClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('每日推荐加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('keeps mobile back navigation during loading and error states', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var backCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DailyRecommendationsScreen(
          client: _LoadingDailyRecommendationsClient(),
          onBack: () => backCount += 1,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    expect(backCount, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: DailyRecommendationsScreen(
          key: UniqueKey(),
          client: _FailingDailyRecommendationsClient(),
          onBack: () => backCount += 1,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    expect(backCount, 2);
    expect(find.text('每日推荐加载失败'), findsOneWidget);
  });

  testWidgets('pull to refresh requests and renders updated recommendations', (
    tester,
  ) async {
    final client = _SequencedDailyRecommendationsClient([
      _daily,
      _refreshedDaily,
    ]);

    await tester.pumpWidget(
      MaterialApp(home: DailyRecommendationsScreen(client: client)),
    );
    await tester.pumpAndSettle();

    expect(client.requestCount, 1);
    expect(find.text('Daily One'), findsOneWidget);
    expect(find.text('Daily Refreshed'), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(client.requestCount, 2);
    expect(find.text('Daily One'), findsNothing);
    expect(find.text('Daily Refreshed'), findsOneWidget);
    expect(find.text('2026-05-23'), findsOneWidget);
  });

  testWidgets('retry requests again and recovers into populated content', (
    tester,
  ) async {
    final client = _RecoveringDailyRecommendationsClient();

    await tester.pumpWidget(
      MaterialApp(home: DailyRecommendationsScreen(client: client)),
    );
    await tester.pumpAndSettle();

    expect(client.requestCount, 1);
    expect(find.text('每日推荐加载失败'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '重试'));
    await tester.pumpAndSettle();

    expect(client.requestCount, 2);
    expect(find.text('每日推荐加载失败'), findsNothing);
    expect(find.text('Daily One'), findsOneWidget);
  });
}

const _daily = DailyRecommendations(
  date: '2026-05-22',
  tracks: [
    Track(
      id: 301,
      title: 'Daily One',
      audioPath: 'daily-one.flac',
      videoPath: '',
      durationSeconds: 180,
      composer: 'kz',
      vocal: '初音ミク',
    ),
    Track(
      id: 302,
      title: 'Daily Two',
      audioPath: 'daily-two.flac',
      videoPath: 'daily-two.mp4',
      durationSeconds: 201,
      composer: 'ryo',
      vocal: '初音ミク',
    ),
  ],
);

const _refreshedDaily = DailyRecommendations(
  date: '2026-05-23',
  tracks: [
    Track(
      id: 303,
      title: 'Daily Refreshed',
      audioPath: 'daily-refreshed.flac',
      videoPath: '',
      durationSeconds: 222,
      composer: 'wowaka',
      vocal: '初音ミク',
    ),
  ],
);

class _DailyRecommendationsClient extends ApiClient {
  _DailyRecommendationsClient(this.recommendations)
    : super(baseUrl: 'http://127.0.0.1:8080');

  final DailyRecommendations recommendations;

  @override
  Future<DailyRecommendations> getDailyRecommendations() async {
    return recommendations;
  }
}

class _FailingDailyRecommendationsClient extends ApiClient {
  _FailingDailyRecommendationsClient()
    : super(baseUrl: 'http://127.0.0.1:8080');

  @override
  Future<DailyRecommendations> getDailyRecommendations() async {
    throw ApiException('failed', 500);
  }
}

class _LoadingDailyRecommendationsClient extends ApiClient {
  _LoadingDailyRecommendationsClient()
    : super(baseUrl: 'http://127.0.0.1:8080');

  final Completer<DailyRecommendations> _completer = Completer();

  @override
  Future<DailyRecommendations> getDailyRecommendations() {
    return _completer.future;
  }
}

class _SequencedDailyRecommendationsClient extends ApiClient {
  _SequencedDailyRecommendationsClient(this._recommendations)
    : super(baseUrl: 'http://127.0.0.1:8080');

  final List<DailyRecommendations> _recommendations;
  int requestCount = 0;

  @override
  Future<DailyRecommendations> getDailyRecommendations() async {
    final index = requestCount;
    requestCount += 1;
    return _recommendations[index.clamp(0, _recommendations.length - 1)];
  }
}

class _RecoveringDailyRecommendationsClient extends ApiClient {
  _RecoveringDailyRecommendationsClient()
    : super(baseUrl: 'http://127.0.0.1:8080');

  int requestCount = 0;

  @override
  Future<DailyRecommendations> getDailyRecommendations() async {
    requestCount += 1;
    if (requestCount == 1) {
      throw ApiException('failed', 500);
    }
    return _daily;
  }
}
