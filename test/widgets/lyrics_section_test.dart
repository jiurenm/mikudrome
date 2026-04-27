import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/timed_lyric_line.dart';
import 'package:mikudrome/theme/app_theme.dart';
import 'package:mikudrome/widgets/player/lyrics_section.dart';

List<TimedLyricLine> _timedLyrics(int count) {
  return List<TimedLyricLine>.generate(
    count,
    (index) => TimedLyricLine(
      start: Duration(seconds: index * 5),
      texts: <String>['Line $index'],
    ),
  );
}

Widget _buildLyricsSection({
  required List<TimedLyricLine> timedLyrics,
  required int activeIndex,
  double width = 420,
  double height = 320,
  String? lyrics,
  TargetPlatform platform = TargetPlatform.macOS,
}) {
  return MaterialApp(
    theme: ThemeData(platform: platform),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: LyricsSection(
            lyrics: lyrics ??
                timedLyrics.map((line) => line.texts.join(' / ')).join('\n'),
            timedLyrics: timedLyrics,
            activeIndex: activeIndex,
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpDesktopStage(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  const desktopWidth = 1280.0;
  const desktopHeight = 720.0;

  testWidgets(
    'desktop timed lyrics render a stage instead of a scrollable list',
    (tester) async {
      await tester.pumpWidget(
        _buildLyricsSection(
          timedLyrics: _timedLyrics(8),
          activeIndex: 3,
          width: desktopWidth,
          height: desktopHeight,
        ),
      );
      await _pumpDesktopStage(tester);

      expect(
          find.byKey(const ValueKey<String>('lyrics-stage')), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('lyrics-stage-mask')),
        findsOneWidget,
      );
      expect(find.byType(ListView), findsNothing);
      expect(find.byType(Scrollbar), findsNothing);
    },
  );

  testWidgets(
    'desktop timed lyrics expose the active line marker for highlight styling',
    (tester) async {
      await tester.pumpWidget(
        _buildLyricsSection(
          timedLyrics: _timedLyrics(8),
          activeIndex: 3,
          width: desktopWidth,
          height: desktopHeight,
        ),
      );
      await _pumpDesktopStage(tester);

      final lineFinder = find.byKey(const ValueKey<String>('lyrics-line-3'));
      final activeMarkerFinder = find.byKey(
        const ValueKey<String>('lyrics-line-active-3'),
      );
      final activeMarkerWithinLineFinder = find.descendant(
        of: lineFinder,
        matching: activeMarkerFinder,
      );

      expect(lineFinder, findsOneWidget);
      expect(activeMarkerWithinLineFinder, findsOneWidget);
      expect(activeMarkerFinder, findsOneWidget);
    },
  );

  testWidgets(
    'desktop timed lyrics wrap the active line in the focus animation shell',
    (tester) async {
      await tester.pumpWidget(
        _buildLyricsSection(
          timedLyrics: _timedLyrics(8),
          activeIndex: 4,
          width: desktopWidth,
          height: desktopHeight,
        ),
      );
      await _pumpDesktopStage(tester);

      final lineFinder = find.byKey(const ValueKey<String>('lyrics-line-4'));
      final activeMarkerFinder = find.byKey(
        const ValueKey<String>('lyrics-line-active-4'),
      );
      final glowFinder = find.byKey(
        const ValueKey<String>('lyrics-line-glow-4'),
      );

      expect(lineFinder, findsOneWidget);
      expect(activeMarkerFinder, findsOneWidget);
      expect(glowFinder, findsOneWidget);
      expect(
        find.descendant(of: lineFinder, matching: glowFinder),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'desktop timed lyrics render the active line with a larger font size',
    (tester) async {
      await tester.pumpWidget(
        _buildLyricsSection(
          timedLyrics: _timedLyrics(8),
          activeIndex: 4,
          width: desktopWidth,
          height: desktopHeight,
        ),
      );
      await _pumpDesktopStage(tester);

      final activeLineText = tester.widget<Text>(find.text('Line 4'));
      final nearbyLineText = tester.widget<Text>(find.text('Line 3'));

      expect(
        activeLineText.style?.fontSize,
        greaterThan(nearbyLineText.style?.fontSize ?? 0),
      );
    },
  );

  testWidgets(
    'desktop timed lyrics render the active line with a lighter font weight',
    (tester) async {
      await tester.pumpWidget(
        _buildLyricsSection(
          timedLyrics: _timedLyrics(8),
          activeIndex: 4,
          width: desktopWidth,
          height: desktopHeight,
        ),
      );
      await _pumpDesktopStage(tester);

      final activeLineText = tester.widget<Text>(find.text('Line 4'));

      expect(activeLineText.style?.fontWeight, FontWeight.w500);
    },
  );

  testWidgets(
    'desktop timed lyrics render the active line with a brighter highlight tint',
    (tester) async {
      await tester.pumpWidget(
        _buildLyricsSection(
          timedLyrics: _timedLyrics(8),
          activeIndex: 4,
          width: desktopWidth,
          height: desktopHeight,
        ),
      );
      await _pumpDesktopStage(tester);

      final activeLineText = tester.widget<Text>(find.text('Line 4'));
      final expectedHighlight =
          Color.lerp(AppTheme.mikuGreen, Colors.white, 0.18)!
              .withValues(alpha: 1.0);

      expect(activeLineText.style?.color, expectedHighlight);
    },
  );

  testWidgets(
    'desktop timed lyrics keep the active line glow away from the leading gutter',
    (tester) async {
      await tester.pumpWidget(
        _buildLyricsSection(
          timedLyrics: _timedLyrics(8),
          activeIndex: 4,
          width: desktopWidth,
          height: desktopHeight,
        ),
      );
      await _pumpDesktopStage(tester);

      final activeLineText = tester.widget<Text>(find.text('Line 4'));
      final shadows = activeLineText.style?.shadows;

      expect(shadows, isNotNull);
      expect(shadows, isNotEmpty);
      expect(
        shadows!.every((shadow) => shadow.offset.dx > 0),
        isTrue,
      );
      expect(
        shadows.every((shadow) => shadow.blurRadius <= 14),
        isTrue,
      );
    },
  );

  testWidgets(
    'desktop timed lyrics render the translation line with a smaller font size',
    (tester) async {
      final timedLyrics = <TimedLyricLine>[
        const TimedLyricLine(
          start: Duration.zero,
          texts: <String>['Primary line', 'Translated line'],
        ),
      ];

      await tester.pumpWidget(
        _buildLyricsSection(
          timedLyrics: timedLyrics,
          activeIndex: 0,
          width: desktopWidth,
          height: desktopHeight,
        ),
      );
      await _pumpDesktopStage(tester);

      final primaryText = tester.widget<Text>(find.text('Primary line'));
      final translatedText = tester.widget<Text>(find.text('Translated line'));

      expect(translatedText.style?.fontSize, 15);
      expect(
        translatedText.style?.fontSize,
        lessThan(primaryText.style?.fontSize ?? 0),
      );
    },
  );

  testWidgets(
    'desktop timed lyrics update the active marker after large index jumps',
    (tester) async {
      final timedLyrics = _timedLyrics(40);

      await tester.pumpWidget(
        _buildLyricsSection(
          timedLyrics: timedLyrics,
          activeIndex: 1,
          width: desktopWidth,
          height: desktopHeight,
        ),
      );
      await _pumpDesktopStage(tester);

      expect(
        find.byKey(const ValueKey<String>('lyrics-line-active-1')),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _buildLyricsSection(
          timedLyrics: timedLyrics,
          activeIndex: 28,
          width: desktopWidth,
          height: desktopHeight,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(const ValueKey<String>('lyrics-line-active-28')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('lyrics-line-active-1')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'desktop timed lyrics switch the active marker without delayed sync',
    (tester) async {
      final timedLyrics = _timedLyrics(12);

      await tester.pumpWidget(
        _buildLyricsSection(
          timedLyrics: timedLyrics,
          activeIndex: 2,
          width: desktopWidth,
          height: desktopHeight,
        ),
      );
      await _pumpDesktopStage(tester);

      await tester.pumpWidget(
        _buildLyricsSection(
          timedLyrics: timedLyrics,
          activeIndex: 5,
          width: desktopWidth,
          height: desktopHeight,
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('lyrics-line-active-5')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('lyrics-line-active-2')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'desktop timed lyrics with no active line still render the stage path',
    (tester) async {
      await tester.pumpWidget(
        _buildLyricsSection(
          timedLyrics: _timedLyrics(40),
          activeIndex: -1,
          width: desktopWidth,
          height: desktopHeight,
        ),
      );
      await _pumpDesktopStage(tester);

      final maskFinder =
          find.byKey(const ValueKey<String>('lyrics-stage-mask'));
      final lineFinder = find.byKey(const ValueKey<String>('lyrics-line-0'));

      expect(
          find.byKey(const ValueKey<String>('lyrics-stage')), findsOneWidget);
      expect(
        maskFinder,
        findsOneWidget,
      );
      expect(find.byType(ListView), findsNothing);
      expect(find.text('Line 0'), findsOneWidget);
      expect(lineFinder, findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('lyrics-line-active-0')),
        findsNothing,
      );

      final stageCenter = tester.getCenter(maskFinder).dy;
      final lineCenter = tester.getCenter(lineFinder).dy;
      expect((lineCenter - stageCenter).abs(), lessThan(160));
    },
  );

  testWidgets(
    'narrow desktop timed lyrics still render the stage path',
    (tester) async {
      await tester.pumpWidget(
        _buildLyricsSection(
          timedLyrics: _timedLyrics(80),
          activeIndex: 40,
          width: 420,
          height: 320,
        ),
      );
      await _pumpDesktopStage(tester);

      expect(
          find.byKey(const ValueKey<String>('lyrics-stage')), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('lyrics-stage-mask')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('lyrics-line-glow-40')),
        findsOneWidget,
      );
      expect(find.byType(ListView), findsNothing);
    },
  );

  testWidgets(
    'wide non-desktop timed lyrics stay on the scrollable list path',
    (tester) async {
      await tester.pumpWidget(
        _buildLyricsSection(
          timedLyrics: _timedLyrics(8),
          activeIndex: 3,
          width: desktopWidth,
          height: desktopHeight,
          platform: TargetPlatform.android,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('lyrics-stage')), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('lyrics-stage-mask')),
        findsNothing,
      );
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(Scrollbar), findsOneWidget);
      expect(find.text('Line 3'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('lyrics-line-3')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'mobile timed lyrics keep the active line free of desktop glow styling',
    (tester) async {
      await tester.pumpWidget(
        _buildLyricsSection(
          timedLyrics: _timedLyrics(8),
          activeIndex: 4,
          width: 420,
          height: 320,
          platform: TargetPlatform.android,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('lyrics-line-glow-4')),
        findsNothing,
      );

      final activeLineText = tester.widget<Text>(find.text('Line 4'));
      expect(activeLineText.style?.shadows, isNull);

      final nearbyLineText = tester.widget<Text>(find.text('Line 3'));
      expect(
        nearbyLineText.style?.color,
        AppTheme.textPrimary.withValues(alpha: 0.72),
      );
      expect(nearbyLineText.style?.fontWeight, FontWeight.w500);
    },
  );

  testWidgets(
    'plain text lyrics keep the fallback scroll view structure',
    (tester) async {
      await tester.pumpWidget(
        _buildLyricsSection(
          timedLyrics: const <TimedLyricLine>[],
          activeIndex: -1,
          lyrics: 'First line\nSecond line',
          width: desktopWidth,
          height: desktopHeight,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('lyrics-stage')), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('lyrics-stage-mask')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('lyrics-line-0')),
        findsNothing,
      );
      expect(find.text('First line\nSecond line'), findsOneWidget);
    },
  );

  testWidgets(
    'keeps far active lyric jumps from snapping to the bottom of the list',
    (tester) async {
      final timedLyrics = _timedLyrics(80);

      await tester.pumpWidget(
        _buildLyricsSection(
          timedLyrics: timedLyrics,
          activeIndex: 0,
          platform: TargetPlatform.android,
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _buildLyricsSection(
          timedLyrics: timedLyrics,
          activeIndex: 40,
          platform: TargetPlatform.android,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      final position = scrollable.position;

      expect(find.text('Line 40'), findsOneWidget);
      expect(position.pixels, lessThan(position.maxScrollExtent));
    },
  );
}
