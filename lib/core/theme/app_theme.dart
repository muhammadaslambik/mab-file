import 'package:flutter/material.dart';

/// Tema "Eye-Comfort": slate pastel gelap (tanpa putih murni / hitam pekat)
/// dan varian terang berwarna krem hangat agar tidak silau.
class AppTheme {
  static const _bgDark = Color(0xFF1E2430);
  static const _surfaceDark = Color(0xFF262D3A);
  static const _textDark = Color(0xFFD7DEE9);
  static const pastelBlue = Color(0xFF8FB8DE);
  static const sage = Color(0xFFA8C9A5);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: pastelBlue,
      brightness: Brightness.dark,
    ).copyWith(
      primary: pastelBlue,
      secondary: sage,
      surface: _surfaceDark,
      onSurface: _textDark,
    );
    return _base(scheme, _bgDark);
  }

  static ThemeData soft() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B7FA6),
      brightness: Brightness.light,
    ).copyWith(
      surface: const Color(0xFFFAF8F4),
      onSurface: const Color(0xFF2E3440),
    );
    return _base(scheme, const Color(0xFFF1EFE9));
  }

  static ThemeData _base(ColorScheme s, Color bg) => ThemeData(
        useMaterial3: true,
        colorScheme: s,
        scaffoldBackgroundColor: bg,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          backgroundColor: bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: s.onSurface,
        ),
        navigationBarTheme: NavigationBarThemeData(backgroundColor: s.surface),
        navigationRailTheme:
            NavigationRailThemeData(backgroundColor: s.surface),
        listTileTheme: const ListTileThemeData(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      );
}
