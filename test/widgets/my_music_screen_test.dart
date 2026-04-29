import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/playlist.dart';
import 'package:mikudrome/models/track.dart';
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
}
