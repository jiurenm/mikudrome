import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/album.dart';
import 'package:mikudrome/widgets/album_detail/album_hero_section.dart';

Widget _buildHarness(Size size) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
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
  );
}

Future<void> _expectCoverLightboxBehavior(WidgetTester tester) async {
  final semantics = tester.ensureSemantics();

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
}

void main() {
  testWidgets('AlbumHeroSection mobile hero opens and closes the cover lightbox',
      (tester) async {
    await tester.pumpWidget(_buildHarness(const Size(390, 844)));
    await tester.pump();

    await _expectCoverLightboxBehavior(tester);
  });

  testWidgets(
      'AlbumHeroSection desktop hero opens and closes the cover lightbox',
      (tester) async {
    await tester.pumpWidget(_buildHarness(const Size(1024, 768)));
    await tester.pump();

    await _expectCoverLightboxBehavior(tester);
  });
}
