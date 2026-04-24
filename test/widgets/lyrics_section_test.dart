import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/timed_lyric_line.dart';
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
  List<TimedLyricLine> timedLyrics = const <TimedLyricLine>[],
  int activeIndex = -1,
  double width = 420,
  double height = 320,
  String? lyrics,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: LyricsSection(
            lyrics:
                lyrics ??
                timedLyrics.map((line) => line.texts.join(' / ')).join('\n'),
            timedLyrics: timedLyrics,
            activeIndex: activeIndex,
          ),
        ),
      ),
    ),
  );
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
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('lyrics-stage')), findsOneWidget);
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
      await tester.pumpAndSettle();

      final lineFinder = find.byKey(const ValueKey<String>('lyrics-line-3'));
      final activeMarkerFinder = find.byKey(
        const ValueKey<String>('lyrics-line-active-3'),
      );
      final activeMarkerWithinLineFinder = find.descendant(
        of: lineFinder,
        matching: activeMarkerFinder,
      );

      expect(lineFinder, findsOneWidget);
      expect(tester.element(lineFinder), isA<Element>());
      expect(activeMarkerWithinLineFinder, findsOneWidget);
      expect(activeMarkerFinder, findsOneWidget);
    },
  );

  testWidgets(
    'plain text lyrics keep the fallback scroll view structure',
    (tester) async {
      await tester.pumpWidget(
        _buildLyricsSection(
          lyrics: 'First line\nSecond line',
          width: desktopWidth,
          height: desktopHeight,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('lyrics-stage')), findsNothing);
    },
  );

  testWidgets(
    'keeps far active lyric jumps from snapping to the bottom of the list',
    (tester) async {
      final timedLyrics = _timedLyrics(80);

      await tester.pumpWidget(
        _buildLyricsSection(timedLyrics: timedLyrics, activeIndex: 0),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _buildLyricsSection(timedLyrics: timedLyrics, activeIndex: 40),
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
