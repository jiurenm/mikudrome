import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/album.dart';
import 'package:mikudrome/widgets/album_detail/album_hero_section.dart';

void main() {
  testWidgets('AlbumHeroSection opens and closes the cover lightbox',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Scaffold(
            body: AlbumHeroSection(
              album: const Album(
                id: '42',
                title: 'World.exe',
                trackCount: 1,
                coverUrl: 'http://example.test/albums/42/cover',
              ),
              baseUrl: 'http://example.test',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Open album cover preview'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('album-hero-cover-trigger')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('detail-cover-lightbox')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('detail-cover-lightbox-close-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('detail-cover-lightbox')), findsNothing);
    semantics.dispose();
  });
}
