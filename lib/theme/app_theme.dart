import 'package:flutter/material.dart';

/// Miku-style theme matching example HTML (--miku-green, --miku-dark).
class AppTheme {
  AppTheme._();

  static const Color mikuGreen = Color(0xFF39C5BB);
  static const Color mikuDark = Color(0xFF121212);
  static const Color cardBg = Color(0xFF1E1E1E);
  static const Color footerBg = Color(0xFF181818);
  static const Color textPrimary = Color(0xFFE0E0E0);
  static const Color textMuted = Color(0xFF6B7280);

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: mikuDark,
      colorScheme: ColorScheme.dark(
        primary: mikuGreen,
        surface: mikuDark,
        onSurface: textPrimary,
        onSurfaceVariant: textMuted,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: mikuDark,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerColor: Colors.white.withValues(alpha: 0.05),
      iconTheme: const IconThemeData(color: textPrimary),
      textTheme: _textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  static TextTheme get _textTheme {
    const base = TextStyle(
      color: textPrimary,
      fontFamilyFallback: ['NotoSansSC', 'NotoSansJP'],
    );
    return TextTheme(
      displayLarge: base.copyWith(fontSize: 48, fontWeight: FontWeight.w700),
      displayMedium: base.copyWith(fontSize: 36, fontWeight: FontWeight.w700),
      headlineLarge: base.copyWith(fontSize: 28, fontWeight: FontWeight.w700),
      headlineMedium: base.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
      titleLarge: base.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      titleMedium: base.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: base.copyWith(fontSize: 16),
      bodyMedium: base.copyWith(fontSize: 14),
      bodySmall: base.copyWith(fontSize: 12),
      labelSmall: base.copyWith(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
    );
  }
}
