import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/api/api_client.dart';
import 'package:mikudrome/models/daily_recommendations.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/screens/daily_recommendations_screen.dart';

void main() {
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
