import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Latar bergerak yang MURAH: dua lingkaran gradien digambar SEKALI (RepaintBoundary),
/// lalu hanya digeser lewat Transform (kerja compositor, bukan menggambar ulang gradien
/// layar penuh tiap frame). Berhenti total saat jendela tidak aktif/terminimalkan.
class LiveBackdrop extends StatefulWidget {
  const LiveBackdrop({super.key});
  @override
  State<LiveBackdrop> createState() => _LiveBackdropState();
}

class _LiveBackdropState extends State<LiveBackdrop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 45))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.dispose();
    super.dispose();
  }

  Widget _blob(Color color, double size) => RepaintBoundary(
        child: SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final still = MediaQuery.of(context).disableAnimations;
    if (still) _c.stop();
    return IgnorePointer(
      child: LayoutBuilder(builder: (_, cs) {
        final w = cs.maxWidth, h = cs.maxHeight;
        // Kanvas 20% lebih besar dari layar (OverflowBox menengahkan) -> saat digeser
        // tidak ada tepi yang terbuka. Amplitudo geser (<= 6%) lebih kecil dari kelebihan (10%).
        final bw = w * 1.2, bh = h * 1.2;
        final size = (bw > bh ? bw : bh) * 0.8;
        final child = Stack(children: [
          Positioned(left: -size * 0.25, top: -size * 0.35, child: _blob(pal.accentA, size)),
          Positioned(right: -size * 0.25, bottom: -size * 0.40, child: _blob(pal.accentB, size)),
        ]);
        return ClipRect(
          child: OverflowBox(
            minWidth: bw,
            maxWidth: bw,
            minHeight: bh,
            maxHeight: bh,
            child: AnimatedBuilder(
              animation: _c,
              child: SizedBox(width: bw, height: bh, child: child),
              builder: (_, c) {
                final t = _c.value; // 0..1..0 halus
                return Transform.translate(
                  offset: Offset(w * 0.06 * (t - 0.5), h * 0.06 * (0.5 - t)),
                  child: c,
                );
              },
            ),
          ),
        );
      }),
    );
  }
}
