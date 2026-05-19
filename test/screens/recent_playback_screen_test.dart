import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/api/api_client.dart';
import 'package:mikudrome/models/playback_history_item.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/screens/library_home_screen.dart';
import 'package:mikudrome/screens/recent_playback_screen.dart';

void main() {
  testWidgets('plays one selected history track', (tester) async {
    Track? played;

    await tester.pumpWidget(
      MaterialApp(
        home: RecentPlaybackScreen(
          client: _RecentPlaybackClient(_items),
          onPlayTrack: (track) => played = track,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recent Two'));

    expect(played?.id, 202);
  });

  testWidgets('add to queue menu invokes queue callback', (tester) async {
    Track? queued;

    await tester.pumpWidget(
      MaterialApp(
        home: RecentPlaybackScreen(
          client: _RecentPlaybackClient(_items),
          onAddToQueue: (track) => queued = track,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('加入当前队列'));

    expect(queued?.id, 201);
  });
}

const _items = [
  PlaybackHistoryItem(
    track: Track(
      id: 201,
      title: 'Recent One',
      audioPath: 'recent-one.flac',
      videoPath: '',
      albumId: 1,
      durationSeconds: 180,
      composer: 'PinocchioP',
      vocal: '初音ミク',
    ),
    positionMs: 12000,
    durationMs: 180000,
    mode: PlaybackMode.audio,
    contextLabel: 'Album / Recent',
    playedAt: 1779072000,
  ),
  PlaybackHistoryItem(
    track: Track(
      id: 202,
      title: 'Recent Two',
      audioPath: 'recent-two.flac',
      videoPath: '',
      albumId: 1,
      durationSeconds: 200,
      composer: 'ryo',
      vocal: '初音ミク',
    ),
    positionMs: 30000,
    durationMs: 200000,
    mode: PlaybackMode.audio,
    contextLabel: 'Album / Recent',
    playedAt: 1779071000,
  ),
];

class _RecentPlaybackClient extends ApiClient {
  _RecentPlaybackClient(this.items) : super(baseUrl: 'http://127.0.0.1:8080');

  final List<PlaybackHistoryItem> items;

  @override
  Future<List<PlaybackHistoryItem>> getPlaybackHistory({int limit = 50}) async {
    return items.take(limit).toList();
  }
}
