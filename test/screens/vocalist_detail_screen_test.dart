import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
