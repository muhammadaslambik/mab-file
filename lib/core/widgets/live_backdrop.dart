import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Latar bergerak sangat halus: dua gradien radial yang melayang pelan.
/// Hanya gradien statis yang digeser -> beban GPU kecil; otomatis berhenti
/// bila sistem meminta "kurangi animasi".
class LiveBackdrop extends StatefulWidget {
  const LiveBackdrop({super.key});
  @override
  State<LiveBackdrop> createState() => _LiveBackdropState();
}

class _LiveBackdropState extends State<LiveBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _blob(Color c, Alignment a, double r) => Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: a,
              radius: r,
              colors: [c.withValues(alpha: 0.20), Colors.transparent],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final still = MediaQuery.of(context).disableAnimations;
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = still ? 0.0 : _c.value * 2 * pi;
            return Stack(children: [
              _blob(pal.accentA, Alignment(-0.9 + 0.45 * sin(t), -1.0 + 0.35 * cos(t)), 1.0),
              _blob(pal.accentB, Alignment(0.95 + 0.35 * cos(t * 1.0), 1.0 - 0.45 * sin(t)), 1.1),
            ]);
          },
        ),
      ),
    );
  }
}
