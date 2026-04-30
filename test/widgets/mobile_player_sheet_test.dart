import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/widgets/mobile_player_sheet.dart';

void main() {
  testWidgets('expanded sheet covers the tab bar bottom padding', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Colors.black)),
            MobilePlayerSheet(
              track: const Track(
                id: 1,
                title: 'Track',
                audioPath: 'track.flac',
                videoPath: '',
              ),
              coverUrl: '',
              isPlaying: false,
              progress: 0,
              onPlayPause: () {},
              bottomPadding: 80,
              expanded: true,
              playerBuilder: (_) =>
                  const ColoredBox(color: Colors.teal, child: Text('player')),
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    final positioned = tester.widget<Positioned>(
      find.ancestor(of: find.text('player'), matching: find.byType(Positioned)),
    );

    expect(positioned.bottom, 0);
  });
}
