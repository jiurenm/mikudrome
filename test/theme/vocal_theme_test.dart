import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/theme/vocal_theme.dart';

void main() {
  group('VocalColors.resolveColor', () {
    const configuredVocalColors = <(String, Color)>[
      ('宵崎奏', Color(0xFFBB6688)),
      ('朝比奈まふゆ', Color(0xFF8888CC)),
      ('東雲絵名', Color(0xFFCCAA88)),
      ('暁山瑞希', Color(0xFFDDAACC)),
      ('花里みのり', Color(0xFFFFCCAA)),
      ('桐谷遥', Color(0xFF99CCFF)),
      ('桃井愛莉', Color(0xFFFFAACC)),
      ('日野森雫', Color(0xFF99EEDD)),
      ('星乃一歌', Color(0xFF33AAEE)),
      ('天馬咲希', Color(0xFFFFDD44)),
      ('望月穗波', Color(0xFFEE6666)),
      ('望月穂波', Color(0xFFEE6666)),
      ('日野森志步', Color(0xFFBBDD22)),
      ('日野森志歩', Color(0xFFBBDD22)),
      ('重音テト', Color(0xFFDD4444)),
      ('重音テトSV', Color(0xFFDD4444)),
      ('GUMI', Color(0xFF7ED957)),
      ('IA', Color(0xFFF6D1D8)),
      ('可不', Color(0xFFC9D6EA)),
    ];

    for (final (name, expectedColor) in configuredVocalColors) {
      test('returns configured color for $name', () {
        final track =
            Track(id: 1, title: 'T', audioPath: 'a', videoPath: '', vocal: name);
        expect(VocalColors.resolveColor(track), expectedColor);
      });
    }

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
