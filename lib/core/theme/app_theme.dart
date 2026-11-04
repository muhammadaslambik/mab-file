import 'package:flutter/material.dart';

/// Identitas warna diambil langsung dari logo: biru #0091FF -> ungu #7A00CC.
class Brand {
  static const blue = Color(0xFF0091FF);
  static const violet = Color(0xFF7A00CC);
  static const gradient = LinearGradient(
    colors: [blue, violet],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

/// Palet permukaan (bukan hitam/putih murni -> nyaman di mata).
class Pal {
  const Pal({
    required this.bg,
    required this.side,
    required this.card,
    required this.hover,
    required this.border,
    required this.text,
    required this.muted,
    required this.select,
  });

  final Color bg, side, card, hover, border, text, muted, select;

  static const dark = Pal(
    bg: Color(0xFF0D1021),
    side: Color(0xFF10142B),
    card: Color(0xFF161B36),
    hover: Color(0x14FFFFFF),
    border: Color(0xFF252B52),
    text: Color(0xFFE8EAF6),
    muted: Color(0xFF8F96BF),
    select: Color(0x337C9CFF),
  );

  static const light = Pal(
    bg: Color(0xFFF3F4FA),
    side: Color(0xFFE9EBF6),
    card: Color(0xFFFBFBFE),
    hover: Color(0x0F000000),
    border: Color(0xFFDADDEE),
    text: Color(0xFF22263F),
    muted: Color(0xFF6E7391),
    select: Color(0x294458E0),
  );

  static Pal of(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? dark : light;
}

class AppTheme {
  static ThemeData dark() => _build(Brightness.dark, Pal.dark,
      primary: const Color(0xFF7C9CFF), secondary: const Color(0xFFB07CFF));

  static ThemeData light() => _build(Brightness.light, Pal.light,
      primary: const Color(0xFF4458E0), secondary: const Color(0xFF8A3FE0));

  static ThemeData _build(Brightness b, Pal p,
      {required Color primary, required Color secondary}) {
    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: b)
        .copyWith(
      primary: primary,
      secondary: secondary,
      surface: p.card,
      onSurface: p.text,
      outline: p.border,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      dividerColor: p.border,
      splashFactory: NoSplash.splashFactory, // lebih ringan, terasa seperti Explorer
      visualDensity: VisualDensity.compact,
      popupMenuTheme: PopupMenuThemeData(
        color: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: p.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.side,
        indicatorColor: primary.withValues(alpha: 0.2),
        surfaceTintColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.border),
        ),
        textStyle: TextStyle(color: p.text, fontSize: 12),
      ),
    );
  }
}
