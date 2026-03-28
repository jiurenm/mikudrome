import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/theme/vocal_theme.dart';

void main() {
  group('VocalColors.resolveColor', () {
    test('returns default for empty vocal and albumArtist', () {
      const track = Track(id: 1, title: 'T', audioPath: 'a', videoPath: '');
      expect(VocalColors.resolveColor(track), const Color(0xFF39C5BB));
    });

    test('returns mapped color for known vocal', () {
      const track = Track(
          id: 1, title: 'T', audioPath: 'a', videoPath: '', vocal: '巡音ルカ');
      expect(VocalColors.resolveColor(track), const Color(0xFFFAAFBE));
    });

    test('matches vocal case-insensitively', () {
      const track = Track(
          id: 1, title: 'T', audioPath: 'a', videoPath: '', vocal: 'kaito');
      expect(VocalColors.resolveColor(track), const Color(0xFF0000FF));
    });

    test('returns default for unknown vocal', () {
      const track = Track(
          id: 1, title: 'T', audioPath: 'a', videoPath: '',
          vocal: 'Unknown Singer');
      expect(VocalColors.resolveColor(track), const Color(0xFF39C5BB));
    });

    test('mixes colors for multiple known vocals (RGB average)', () {
      const track = Track(
          id: 1, title: 'T', audioPath: 'a', videoPath: '',
          vocal: '初音ミク,巡音ルカ');
      final color = VocalColors.resolveColor(track);
      // miku #39C5BB=(57,197,187), luka #FAAFBE=(250,175,190)
      // avg = (153, 186, 188)
      expect(color.red, 153);
      expect(color.green, 186);
      expect(color.blue, 188);
    });

    test('ignores unknown vocals in mix', () {
      const track = Track(
          id: 1, title: 'T', audioPath: 'a', videoPath: '',
          vocal: '初音ミク,Unknown');
      expect(VocalColors.resolveColor(track), const Color(0xFF39C5BB));
    });

    test('group mapping takes priority over vocal', () {
      const track = Track(
          id: 1, title: 'T', audioPath: 'a', videoPath: '',
          albumArtist: '25時、ナイトコードで。', vocal: '初音ミク');
      expect(VocalColors.resolveColor(track), const Color(0xFF884499));
    });

    test('group matching is case-insensitive', () {
      const track = Track(
          id: 1, title: 'T', audioPath: 'a', videoPath: '',
          albumArtist: 'leo/need');
      expect(VocalColors.resolveColor(track), const Color(0xFF4455DD));
    });

    test('falls through to vocal when albumArtist not in group map', () {
      const track = Track(
          id: 1, title: 'T', audioPath: 'a', videoPath: '',
          albumArtist: 'Some Producer', vocal: 'MEIKO');
      expect(VocalColors.resolveColor(track), const Color(0xFFD80000));
    });
  });
}
