import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/album.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/widgets/album_detail/album_action_bar.dart';
import 'package:mikudrome/widgets/album_detail/album_hero_section.dart';

const _album = Album(
  id: '39',
  title: 'GHOST',
  producerId: 27,
  producerName: 'DECO*27',
  year: 2021,
  trackCount: 12,
  coverUrl: 'http://example.test/albums/39/cover',
);

const _tracks = [
  Track(
    id: 1,
    title: '妄想感傷代償連盟',
    audioPath: '/audio/1.flac',
    videoPath: '',
    durationSeconds: 270,
  ),
];

Widget _harness({required Size size, required Widget child}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('mobile album hero uses compact horizontal app layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        size: const Size(390, 844),
        child: const AlbumHeroSection(
          album: _album,
          tracks: _tracks,
          baseUrl: 'http://example.test',
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('album-detail-mobile-hero-row')),
      findsOneWidget,
    );
    expect(find.text('GHOST'), findsOneWidget);
    expect(find.text('DECO*27'), findsOneWidget);
    expect(find.text('12 首歌曲'), findsOneWidget);
    expect(find.textContaining('2021'), findsNothing);
  });

  testWidgets('mobile album actions match the app screenshot controls', (
    tester,
  ) async {
    var playAllCount = 0;

    await tester.pumpWidget(
      _harness(
        size: const Size(390, 844),
        child: AlbumActionBar(
          tracks: _tracks,
          onPlayAll: () => playAllCount++,
          onShuffle: () {},
        ),
      ),
    );

    expect(find.text('已喜欢'), findsOneWidget);
    expect(find.text('下载'), findsOneWidget);
    expect(find.text('更多'), findsOneWidget);
    expect(find.text('播放全部'), findsOneWidget);

    await tester.tap(find.text('播放全部'));
    expect(playAllCount, 1);
  });

  testWidgets('desktop album actions keep the existing desktop play label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        size: const Size(1024, 768),
        child: AlbumActionBar(
          tracks: _tracks,
          onPlayAll: () {},
          onShuffle: () {},
        ),
      ),
    );

    expect(find.text('PLAY ALL'), findsOneWidget);
    expect(find.text('播放全部'), findsNothing);
  });
}
