import 'package:flutter/material.dart';
import '../models/track.dart';

class VocalColors {
  VocalColors._();

  static const Color defaultColor = Color(0xFF39C5BB);

  static String _normalizeName(String name) => name.toLowerCase();

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
    '宵崎奏': const Color(0xFFBB6688),
    '朝比奈まふゆ': const Color(0xFF8888CC),
    '東雲絵名': const Color(0xFFCCAA88),
    '暁山瑞希': const Color(0xFFDDAACC),
    '花里みのり': const Color(0xFFFFCCAA),
    '桐谷遥': const Color(0xFF99CCFF),
    '桃井愛莉': const Color(0xFFFFAACC),
    '日野森雫': const Color(0xFF99EEDD),
    '星乃一歌': const Color(0xFF33AAEE),
    '天馬咲希': const Color(0xFFFFDD44),
    '望月穗波': const Color(0xFFEE6666),
    '望月穂波': const Color(0xFFEE6666),
    '日野森志步': const Color(0xFFBBDD22),
    '日野森志歩': const Color(0xFFBBDD22),
    '重音テト': const Color(0xFFDD4444),
    '重音テトsv': const Color(0xFFDD4444),
    'gumi': const Color(0xFF7ED957),
    'ia': const Color(0xFFF6D1D8),
    '可不': const Color(0xFFC9D6EA),
  };

  static Color colorForName(String name) {
    return _vocalMap[_normalizeName(name)] ?? defaultColor;
  }

  static Color resolveColor(Track track) {
    if (track.albumArtist.isNotEmpty) {
      final groupColor = _groupMap[_normalizeName(track.albumArtist)];
      if (groupColor != null) return groupColor;
    }

    final vocalists = track.vocalists;
    if (vocalists.isEmpty) return defaultColor;

    final colors = <Color>[];
    for (final v in vocalists) {
      final color = _vocalMap[_normalizeName(v)];
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

class VocalThemeProvider extends StatefulWidget {
  const VocalThemeProvider({super.key, required this.track, required this.child});

  final Track? track;
  final Widget child;

  static Color of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_VocalThemeData>()?.color
        ?? VocalColors.defaultColor;
  }

  @override
  State<VocalThemeProvider> createState() => _VocalThemeProviderState();
}

class _VocalThemeProviderState extends State<VocalThemeProvider> {
  Color _targetColor = VocalColors.defaultColor;

  @override
  void initState() {
    super.initState();
    _targetColor = _resolve();
  }

  @override
  void didUpdateWidget(VocalThemeProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track?.id != widget.track?.id) {
      setState(() => _targetColor = _resolve());
    }
  }

  Color _resolve() {
    final t = widget.track;
    return t == null ? VocalColors.defaultColor : VocalColors.resolveColor(t);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: _targetColor),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      builder: (context, color, _) => _VocalThemeData(
        color: color ?? VocalColors.defaultColor,
        child: widget.child,
      ),
    );
  }
}

class _VocalThemeData extends InheritedWidget {
  const _VocalThemeData({required this.color, required super.child});
  final Color color;

  @override
  bool updateShouldNotify(_VocalThemeData oldWidget) => color != oldWidget.color;
}
