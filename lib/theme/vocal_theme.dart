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

  static Color colorForName(String name) {
    return _vocalMap[name.toLowerCase()] ?? defaultColor;
  }

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
