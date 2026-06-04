import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/api/api_client.dart';
import 'package:mikudrome/models/playback_history_item.dart';
import 'package:mikudrome/models/playlist.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/screens/library_home_screen.dart';
import 'package:mikudrome/widgets/app_shell.dart';
import 'package:mikudrome/widgets/my_music_screen.dart';

void main() {
  testWidgets('renders mobile library layout without profile chrome', (
    tester,
  ) async {
    final navigated = <ShellRoute>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyMusicScreen(
            playlists: const [
              Playlist(id: 1, name: '喜欢的音乐', trackCount: 68),
              Playlist(id: 2, name: '工作时听', trackCount: 42),
            ],
            onNavigate: navigated.add,
          ),
        ),
      ),
    );

    expect(find.text('我的音乐'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('歌单'), findsOneWidget);
    expect(find.text('最近播放'), findsWidgets);
    expect(find.text('下载管理'), findsOneWidget);
    expect(find.text('创建的歌单'), findsOneWidget);
    expect(find.text('喜欢的音乐'), findsOneWidget);

    expect(find.text('关注'), findsNothing);
    expect(find.text('粉丝'), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);

    await tester.tap(find.text('收藏').first);
    expect(navigated, [ShellRoute.favorites]);
  });

  testWidgets('shows current track in recent section when available', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MyMusicScreen(
            currentTrack: Track(
              id: 7,
              title: '爱言葉',
              audioPath: '/music/a.mp3',
              videoPath: '',
              albumId: 3,
              composer: 'DECO*27',
              vocal: '初音ミク',
            ),
          ),
        ),
      ),
    );

    expect(find.text('爱言葉'), findsOneWidget);
    expect(find.text('DECO*27 feat. 初音ミク'), findsOneWidget);
    expect(find.text('暂无最近播放记录'), findsNothing);
  });

  testWidgets('shows latest cloud playback history in recent section', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyMusicScreen(
            client: _PlaybackHistoryClient([
              const PlaybackHistoryItem(
                track: Track(
                  id: 9,
                  title: 'メルト',
                  audioPath: '/music/melt.mp3',
                  videoPath: '',
                  composer: 'ryo',
                  vocal: '初音ミク',
                ),
                positionMs: 12000,
                durationMs: 240000,
                mode: PlaybackMode.audio,
                contextLabel: 'Album',
                playedAt: 1779072000,
              ),
            ]),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('メルト'), findsOneWidget);
    expect(find.text('ryo feat. 初音ミク'), findsOneWidget);
    expect(find.text('暂无最近播放记录'), findsNothing);
  });

  testWidgets('opens playlist detail from created playlist card', (
    tester,
  ) async {
    int? openedPlaylistId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyMusicScreen(
            playlists: const [Playlist(id: 42, name: '工作时听', trackCount: 12)],
            onPlaylistTap: (playlistId) => openedPlaylistId = playlistId,
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('工作时听'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('工作时听'));

    expect(openedPlaylistId, 42);
  });

  testWidgets('created playlists use fixed cards distributed across the row', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(390, 844)),
          child: Scaffold(
            body: MyMusicScreen(
              playlists: [
                Playlist(id: 1, name: '喜欢的音乐', trackCount: 68),
                Playlist(id: 2, name: '工作时听', trackCount: 42),
                Playlist(id: 3, name: '睡前听', trackCount: 9),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -240));
    await tester.pumpAndSettle();

    final firstPosition = tester.getTopLeft(find.text('喜欢的音乐'));
    final secondPosition = tester.getTopLeft(find.text('工作时听'));
    final thirdPosition = tester.getTopLeft(find.text('睡前听'));
    final firstCardSize = tester.getSize(
      find
          .ancestor(of: find.text('喜欢的音乐'), matching: find.byType(InkWell))
          .first,
    );

    expect((secondPosition.dy - firstPosition.dy).abs(), lessThan(1));
    expect(secondPosition.dx, greaterThan(firstPosition.dx));
    expect((thirdPosition.dy - firstPosition.dy).abs(), lessThan(1));
    expect(thirdPosition.dx, greaterThan(secondPosition.dx));
    expect(firstCardSize.width, lessThanOrEqualTo(116));
    expect(firstCardSize.height, firstCardSize.width);
  });

  testWidgets('MyMusicScreen uses landscape grouped layout', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(844, 390)),
            child: Scaffold(
              body: MyMusicScreen(
                onNavigate: (_) {},
                onPlaylistTap: (_) {},
                onQueue: () {},
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('my-music-mobile-landscape')),
        findsOneWidget,
      );
      expect(find.text('收藏'), findsOneWidget);
      expect(find.text('歌单'), findsOneWidget);
      expect(find.text('最近播放'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

class _PlaybackHistoryClient extends ApiClient {
  _PlaybackHistoryClient(this.items);

  final List<PlaybackHistoryItem> items;

  @override
  Future<List<PlaybackHistoryItem>> getPlaybackHistory({int limit = 50}) async {
    return items.take(limit).toList();
  }
}
