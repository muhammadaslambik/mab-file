import 'package:flutter/material.dart';

/// Warna asli logo (dipakai untuk logo & tema "Aurora").
class Brand {
  static const blue = Color(0xFF0091FF);
  static const violet = Color(0xFF7A00CC);
  static const gradient = LinearGradient(colors: [blue, violet]);
}

/// Palet permukaan + aksen. Dipasang sebagai ThemeExtension sehingga semua widget
/// otomatis ikut berubah saat tema diganti.
@immutable
class Pal extends ThemeExtension<Pal> {
  const Pal({
    required this.bg,
    required this.side,
    required this.card,
    required this.hover,
    required this.border,
    required this.text,
    required this.muted,
    required this.select,
    required this.accentA,
    required this.accentB,
  });

  final Color bg, side, card, hover, border, text, muted, select, accentA, accentB;

  LinearGradient get gradient => LinearGradient(colors: [accentA, accentB]);

  static Pal of(BuildContext c) => Theme.of(c).extension<Pal>() ?? kThemes.first.pal;

  @override
  Pal copyWith({Color? bg, Color? side, Color? card, Color? hover, Color? border, Color? text,
          Color? muted, Color? select, Color? accentA, Color? accentB}) =>
      Pal(
        bg: bg ?? this.bg,
        side: side ?? this.side,
        card: card ?? this.card,
        hover: hover ?? this.hover,
        border: border ?? this.border,
        text: text ?? this.text,
        muted: muted ?? this.muted,
        select: select ?? this.select,
        accentA: accentA ?? this.accentA,
        accentB: accentB ?? this.accentB,
      );

  @override
  Pal lerp(ThemeExtension<Pal>? other, double t) {
    if (other is! Pal) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Pal(
      bg: l(bg, other.bg), side: l(side, other.side), card: l(card, other.card),
      hover: l(hover, other.hover), border: l(border, other.border), text: l(text, other.text),
      muted: l(muted, other.muted), select: l(select, other.select),
      accentA: l(accentA, other.accentA), accentB: l(accentB, other.accentB),
    );
  }
}

class MabTheme {
  const MabTheme({
    required this.id,
    required this.name,
    required this.tag,
    required this.dark,
    required this.pal,
    required this.primary,
    required this.secondary,
    this.animated = false,
  });
  final String id, name, tag;
  final bool dark, animated;
  final Pal pal;
  final Color primary, secondary;
}

const _dk = Color(0x14FFFFFF);
const _lt = Color(0x0F000000);

const kThemes = <MabTheme>[
  // ---- Gelap ----
  MabTheme(
    id: 'aurora', name: 'Aurora', tag: 'Gelap • identitas MAB', dark: true,
    primary: Color(0xFF7C9CFF), secondary: Color(0xFFB07CFF),
    pal: Pal(bg: Color(0xFF0D1021), side: Color(0xFF10142B), card: Color(0xFF161B36), hover: _dk,
        border: Color(0xFF252B52), text: Color(0xFFE8EAF6), muted: Color(0xFF8F96BF),
        select: Color(0x337C9CFF), accentA: Color(0xFF0091FF), accentB: Color(0xFF7A00CC)),
  ),
  MabTheme(
    id: 'graphite', name: 'Graphite', tag: 'Gelap • netral ala editor', dark: true,
    primary: Color(0xFF5B9BFF), secondary: Color(0xFF8AB4FF),
    pal: Pal(bg: Color(0xFF1C1C1E), side: Color(0xFF171718), card: Color(0xFF252528), hover: _dk,
        border: Color(0xFF323236), text: Color(0xFFE6E6E8), muted: Color(0xFF8E8E93),
        select: Color(0x403B82F6), accentA: Color(0xFF3B82F6), accentB: Color(0xFF6366F1)),
  ),
  MabTheme(
    id: 'midnight', name: 'Midnight', tag: 'Gelap • hemat baterai AMOLED', dark: true,
    primary: Color(0xFF4FD8F0), secondary: Color(0xFF8B8DF5),
    pal: Pal(bg: Color(0xFF04050A), side: Color(0xFF07080F), card: Color(0xFF0E1018), hover: _dk,
        border: Color(0xFF1B1E2B), text: Color(0xFFE4E7F0), muted: Color(0xFF7C8299),
        select: Color(0x3322D3EE), accentA: Color(0xFF22D3EE), accentB: Color(0xFF6366F1)),
  ),
  MabTheme(
    id: 'nord', name: 'Nordic', tag: 'Gelap • biru keabuan lembut', dark: true,
    primary: Color(0xFF88C0D0), secondary: Color(0xFFB48EAD),
    pal: Pal(bg: Color(0xFF2E3440), side: Color(0xFF292E39), card: Color(0xFF3B4252), hover: _dk,
        border: Color(0xFF4C566A), text: Color(0xFFECEFF4), muted: Color(0xFF9AA5B8),
        select: Color(0x4088C0D0), accentA: Color(0xFF88C0D0), accentB: Color(0xFF81A1C1)),
  ),
  MabTheme(
    id: 'forest', name: 'Forest', tag: 'Gelap • hijau menenangkan', dark: true,
    primary: Color(0xFF4ADE9F), secondary: Color(0xFF86EFAC),
    pal: Pal(bg: Color(0xFF0E1813), side: Color(0xFF0B1410), card: Color(0xFF15231C), hover: _dk,
        border: Color(0xFF21352B), text: Color(0xFFE3F0E8), muted: Color(0xFF86A394),
        select: Color(0x3334D399), accentA: Color(0xFF34D399), accentB: Color(0xFF059669)),
  ),
  MabTheme(
    id: 'sunset', name: 'Sunset', tag: 'Gelap • oranye-magenta hangat', dark: true,
    primary: Color(0xFFFFA45C), secondary: Color(0xFFFF6FA5),
    pal: Pal(bg: Color(0xFF1A1218), side: Color(0xFF150E14), card: Color(0xFF231922), hover: _dk,
        border: Color(0xFF3A2735), text: Color(0xFFF5E8EE), muted: Color(0xFFB097A5),
        select: Color(0x33FB923C), accentA: Color(0xFFFB923C), accentB: Color(0xFFE11D74)),
  ),
  // ---- Terang ----
  MabTheme(
    id: 'porcelain', name: 'Porcelain', tag: 'Terang • lavender lembut', dark: false,
    primary: Color(0xFF4458E0), secondary: Color(0xFF8A3FE0),
    pal: Pal(bg: Color(0xFFF3F4FA), side: Color(0xFFE9EBF6), card: Color(0xFFFBFBFE), hover: _lt,
        border: Color(0xFFDADDEE), text: Color(0xFF22263F), muted: Color(0xFF6E7391),
        select: Color(0x294458E0), accentA: Color(0xFF0091FF), accentB: Color(0xFF7A00CC)),
  ),
  MabTheme(
    id: 'paper', name: 'Paper', tag: 'Terang • krem hangat (nyaman di mata)', dark: false,
    primary: Color(0xFFB45309), secondary: Color(0xFF7C5E3B),
    pal: Pal(bg: Color(0xFFF4EFE4), side: Color(0xFFEBE4D4), card: Color(0xFFFAF7EF), hover: _lt,
        border: Color(0xFFDCD3BE), text: Color(0xFF3A3328), muted: Color(0xFF7D725E),
        select: Color(0x33B45309), accentA: Color(0xFFD97706), accentB: Color(0xFF9A3412)),
  ),
  MabTheme(
    id: 'sakura', name: 'Sakura', tag: 'Terang • merah muda & ungu', dark: false,
    primary: Color(0xFFD6338A), secondary: Color(0xFF8B5CF6),
    pal: Pal(bg: Color(0xFFFDF3F7), side: Color(0xFFF8E6EE), card: Color(0xFFFFFAFC), hover: _lt,
        border: Color(0xFFF0D3E0), text: Color(0xFF3B2430), muted: Color(0xFF94687D),
        select: Color(0x29EC4899), accentA: Color(0xFFEC4899), accentB: Color(0xFF8B5CF6)),
  ),
  // ---- Animasi (latar bergerak halus, bisa dimatikan) ----
  MabTheme(
    id: 'aurora_live', name: 'Aurora Live', tag: 'Animasi • gelap', dark: true, animated: true,
    primary: Color(0xFF7C9CFF), secondary: Color(0xFFB07CFF),
    pal: Pal(bg: Color(0xFF0D1021), side: Color(0xE610142B), card: Color(0xFF161B36), hover: _dk,
        border: Color(0xFF252B52), text: Color(0xFFE8EAF6), muted: Color(0xFF8F96BF),
        select: Color(0x337C9CFF), accentA: Color(0xFF0091FF), accentB: Color(0xFF7A00CC)),
  ),
  MabTheme(
    id: 'neon_live', name: 'Neon Pulse', tag: 'Animasi • gelap, tosca-ungu', dark: true, animated: true,
    primary: Color(0xFF2DEBD0), secondary: Color(0xFFB580F0),
    pal: Pal(bg: Color(0xFF090913), side: Color(0xE60C0C1A), card: Color(0xFF121224), hover: _dk,
        border: Color(0xFF222242), text: Color(0xFFE9F7F5), muted: Color(0xFF8A93B0),
        select: Color(0x3300F5D4), accentA: Color(0xFF00F5D4), accentB: Color(0xFF9B5DE5)),
  ),
  MabTheme(
    id: 'ocean_live', name: 'Ocean Breeze', tag: 'Animasi • terang, biru laut', dark: false, animated: true,
    primary: Color(0xFF0284C7), secondary: Color(0xFF6366F1),
    pal: Pal(bg: Color(0xFFEAF4FB), side: Color(0xE6DDEBF6), card: Color(0xFFF7FBFE), hover: _lt,
        border: Color(0xFFC9DEEE), text: Color(0xFF14283C), muted: Color(0xFF5C7790),
        select: Color(0x290EA5E9), accentA: Color(0xFF0EA5E9), accentB: Color(0xFF6366F1)),
  ),
];

MabTheme themeById(String id) =>
    kThemes.firstWhere((t) => t.id == id, orElse: () => kThemes.first);

class AppTheme {
  static ThemeData build(MabTheme t) {
    final p = t.pal;
    final scheme = ColorScheme.fromSeed(
      seedColor: t.primary,
      brightness: t.dark ? Brightness.dark : Brightness.light,
    ).copyWith(
      primary: t.primary,
      secondary: t.secondary,
      surface: p.card,
      onSurface: p.text,
      outline: p.border,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      dividerColor: p.border,
      splashFactory: NoSplash.splashFactory, // ringan, terasa seperti Explorer
      visualDensity: VisualDensity.compact,
      extensions: [p],
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
        indicatorColor: t.primary.withValues(alpha: 0.2),
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.card,
        elevation: 0,
        actionTextColor: t.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: p.border),
        ),
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
