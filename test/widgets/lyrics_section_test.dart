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
  required List<TimedLyricLine> timedLyrics,
  required int activeIndex,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 420,
          height: 320,
          child: LyricsSection(
            lyrics: timedLyrics.map((line) => line.texts.join(' / ')).join('\n'),
            timedLyrics: timedLyrics,
            activeIndex: activeIndex,
          ),
        ),
      ),
    ),
  );
}

void main() {
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
