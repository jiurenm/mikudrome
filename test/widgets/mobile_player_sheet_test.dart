import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/widgets/mobile_mini_player.dart';
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

  testWidgets('collapsed sheet disables tickers in the hidden player', (
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
              isPlaying: true,
              progress: 0,
              onPlayPause: () {},
              bottomPadding: 80,
              expanded: false,
              playerBuilder: (_) => const _TickerModeProbe(),
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    final context = tester.element(
      find.byType(_TickerModeProbe, skipOffstage: false),
    );

    expect(TickerMode.valuesOf(context).enabled, isFalse);
  });

  testWidgets('expanded player close callback collapses the sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final expandedChanges = <bool>[];

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
              onExpandedChanged: expandedChanges.add,
              playerBuilder: (onClose) => TextButton(
                onPressed: onClose,
                child: const Text('collapse player'),
              ),
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('collapse player'));
    await tester.pump();

    expect(expandedChanges, [false]);
  });

  testWidgets('reasserted expanded state keeps the player visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var expanded = true;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Stack(
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
                  expanded: expanded,
                  onExpandedChanged: (value) {
                    if (!value) {
                      setState(() {
                        expanded = true;
                      });
                    }
                  },
                  playerBuilder: (onClose) => Column(
                    children: [
                      TextButton(
                        onPressed: onClose,
                        child: const Text('try collapse'),
                      ),
                      const Text('player body'),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('try collapse'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('player body'), findsOneWidget);
  });

  testWidgets('partial expansion clips a full-height player without overflow', (
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
              expanded: false,
              playerBuilder: (_) => const _TallPlayerProbe(),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byType(MobileMiniPlayer));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.text('upper'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TickerModeProbe extends StatelessWidget {
  const _TickerModeProbe();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.teal, child: Text('player'));
  }
}

class _TallPlayerProbe extends StatelessWidget {
  const _TallPlayerProbe();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(height: 280, child: Text('upper')),
        SizedBox(height: 280, child: Text('lower')),
      ],
    );
  }
}
