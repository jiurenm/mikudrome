import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/services/playback_timeline.dart';

void main() {
  group('effectiveTimelineDuration', () {
    test('uses scanned duration for browser-transcoded ALAC audio', () {
      const track = Track(
        id: 1,
        title: 'ALAC',
        audioPath: '/music/alac.m4a',
        videoPath: '',
        durationSeconds: 245,
        format: '16bit ALAC',
      );

      expect(
        effectiveTimelineDuration(
          track: track,
          mediaDuration: Duration.zero,
          usesWebAudioPlayer: true,
        ),
        const Duration(seconds: 245),
      );
    });

    test('keeps media duration for normal web audio', () {
      const track = Track(
        id: 2,
        title: 'AAC',
        audioPath: '/music/aac.m4a',
        videoPath: '',
        durationSeconds: 245,
        format: 'AAC',
      );

      expect(
        effectiveTimelineDuration(
          track: track,
          mediaDuration: const Duration(seconds: 244),
          usesWebAudioPlayer: true,
        ),
        const Duration(seconds: 244),
      );
    });
  });
}
