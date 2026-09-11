import 'package:flutter/material.dart';

/// Dark cybersecurity aesthetic (§16: function over animation).
class VcsTheme {
  static const bg = Color(0xFF0B1220);
  static const card = Color(0xFF111A2B);
  static const cardAlt = Color(0xFF16213A);
  static const accent = Color(0xFF22D3EE); // cyan
  static const good = Color(0xFF34D399);
  static const warn = Color(0xFFFBBF24);
  static const high = Color(0xFFFB923C);
  static const danger = Color(0xFFF87171);
  static const textDim = Color(0xFF94A3B8);

  static Color levelColor(String? level) {
    switch (level) {
      case 'LOW':
        return good;
      case 'MEDIUM':
        return warn;
      case 'HIGH':
        return high;
      case 'CRITICAL':
        return danger;
      default:
        return textDim;
    }
  }

  static Color sourceTagColor(String tag) {
    switch (tag) {
      case 'voice':
        return accent;
      case 'scam_rule':
        return good;
      case 'fused':
        return Color(0xFFA78BFA);
      case 'policy':
        return high;
      case 'liveness':
        return Color(0xFFF472B6);
      case 'identity':
        return Color(0xFF60A5FA);
      case 'url_rule':
        return good;
      default:
        return textDim;
    }
  }

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.dark(
          primary: accent,
          secondary: accent,
          surface: card,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        inputDecorationTheme: InputDecorationTheme(
          fillColor: card,
          filled: true,
          hintStyle: const TextStyle(color: textDim),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
        ),
      );
}
