import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/api/api_client.dart';
import 'package:mikudrome/api/config.dart';
import 'package:mikudrome/models/playlist.dart';
import 'package:mikudrome/screens/playlists_screen.dart';

void main() {
  tearDown(() {
    ApiConfig.resetRuntimeConfigForTests();
  });

  testWidgets('mobile playlist list uses bounded rows for long names', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: PlaylistsScreen(client: _PlaylistsClient()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('歌单'), findsOneWidget);
    expect(find.text('共 3 个歌单'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('mobile-playlist-row-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('mobile-playlist-menu-1')),
      findsOneWidget,
    );
    expect(find.text('工作时听的超长歌单标题应该被截断而不是撑破布局'), findsOneWidget);
  });
}

class _PlaylistsClient extends ApiClient {
  @override
  Future<List<Playlist>> listPlaylists() async {
    return const [
      Playlist(id: 1, name: '工作时听的超长歌单标题应该被截断而不是撑破布局', trackCount: 42),
      Playlist(id: 2, name: '喜欢的音乐', trackCount: 68),
      Playlist(id: 3, name: '睡前听', trackCount: 9),
    ];
  }
}
