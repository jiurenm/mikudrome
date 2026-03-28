import 'package:flutter/material.dart';
import '../models/track.dart';

class VocalColors {
  VocalColors._();

  static const Color defaultColor = Color(0xFF39C5BB);

  static final Map<String, Color> _groupMap = {
    'leo/need': const Color(0xFF4455DD),
    'more more jump!': const Color(0xFF88DD44),
    'vivid bad squad': const Color(0xFFEE1166),
    'ワンダーランズ×ショウタイム': const Color(0xFFFF9900),
    '25時、ナイトコードで。': const Color(0xFF884499),
  };

  static final Map<String, Color> _vocalMap = {
    '初音ミク': const Color(0xFF39C5BB),
    '巡音ルカ': const Color(0xFFFAAFBE),
    '鏡音リン': const Color(0xFFFFA500),
    '鏡音レン': const Color(0xFFFFE211),
    'kaito': const Color(0xFF0000FF),
    'meiko': const Color(0xFFD80000),
  };

  static Color resolveColor(Track track) {
    if (track.albumArtist.isNotEmpty) {
      final groupColor = _groupMap[track.albumArtist.toLowerCase()];
      if (groupColor != null) return groupColor;
    }

    final vocalists = track.vocalists;
    if (vocalists.isEmpty) return defaultColor;

    final colors = <Color>[];
    for (final v in vocalists) {
      final color = _vocalMap[v.toLowerCase()];
      if (color != null) colors.add(color);
    }

    if (colors.isEmpty) return defaultColor;
    if (colors.length == 1) return colors.first;

    int r = 0, g = 0, b = 0;
    for (final c in colors) {
      r += c.red;
      g += c.green;
      b += c.blue;
    }
    final n = colors.length;
    return Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
  }
}
