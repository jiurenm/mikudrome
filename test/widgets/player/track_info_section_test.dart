import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/widgets/player/track_info_section.dart';

void main() {
  testWidgets('uses dash when vocalists are unavailable', (tester) async {
    const track = Track(
      id: 1,
      title: 'Test',
      audioPath: '/tmp/test.flac',
      videoPath: '',
      composer: 'Composer',
      lyricist: 'Lyricist',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrackInfoSection(track: track),
        ),
      ),
    );

    expect(find.text('Composer'), findsWidgets);
    expect(find.text('Lyricist'), findsWidgets);
    expect(find.text('-'), findsOneWidget);
    expect(find.text('Unknown'), findsNothing);
  });
}
