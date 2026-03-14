import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/track.dart';

void main() {
  group('Track.vocalLine', () {
    test('merges composer and lyricist people and uses commas', () {
      const track = Track(
        id: 1,
        title: 'Test',
        audioPath: '/tmp/test.flac',
        videoPath: '',
        composer: 'A;B',
        lyricist: 'C；D',
        vocal: 'Miku; Rin',
      );

      expect(track.vocalLine, 'A, B, C, D feat. Miku, Rin');
    });

    test('deduplicates repeated names across composer and lyricist', () {
      const track = Track(
        id: 1,
        title: 'Test',
        audioPath: '/tmp/test.flac',
        videoPath: '',
        composer: 'A；B;A',
        lyricist: 'B; C; A',
      );

      expect(track.vocalLine, 'A, B, C');
    });

    test('shows vocal credits alone when composer and lyricist are empty', () {
      const track = Track(
        id: 1,
        title: 'Test',
        audioPath: '/tmp/test.flac',
        videoPath: '',
        vocal: 'Miku；Rin; Miku',
      );

      expect(track.vocalLine, 'Miku, Rin');
    });
  });
}
