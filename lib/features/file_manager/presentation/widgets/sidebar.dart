import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../storage/storage_analyzer.dart';
import '../../application/file_manager_state.dart';
import '../../application/nav_state.dart';
import '../../application/places.dart';
import '../../domain/file_item.dart';
import 'glyph.dart';

/// Sidebar ala Finder (Favorit, Kategori) + Explorer (Perangkat dengan bar kapasitas).
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = Pal.of(context);
    final s = ref.watch(fmProvider);
    final c = ref.read(fmProvider.notifier);
    final nav = ref.watch(navIndexProvider);
    final places = ref.watch(placesProvider).valueOrNull ?? const <Place>[];
    final drives = ref.watch(drivesProvider).valueOrNull ?? const <DriveInfo>[];
    final mode = ref.watch(themeModeProvider);

    void goFiles() => ref.read(navIndexProvider.notifier).set(0);

    return Container(
      width: 252,
      decoration: BoxDecoration(
        color: pal.side,
        border: Border(right: BorderSide(color: pal.border)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
          child: Row(children: [
            const BrandLogo(size: 34),
            const SizedBox(width: 10),
            const GradientText('MAB-File',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(10, 0, 10, 10), children: [
            const _Section('Favorit'),
            for (final pl in places)
              _NavTile(
                icon: pl.icon,
                label: pl.label,
                selected: nav == 0 && s.path == pl.path && s.filter == null,
                onTap: () {
                  goFiles();
                  c.open(pl.path);
                },
              ),
            if (drives.isNotEmpty) ...[
              const _Section('Perangkat'),
              for (final d in drives)
                _DriveTile(
                  d,
                  selected: nav == 0 && s.path.toLowerCase().startsWith(d.path.toLowerCase()) && d.path != '/',
                  onTap: () {
                    goFiles();
                    c.open(d.path);
                  },
                ),
            ],
            const _Section('Jenis file'),
            for (final k in const [
              (FileCategory.image, Icons.photo_library_rounded, 'Gambar'),
              (FileCategory.video, Icons.movie_rounded, 'Video'),
              (FileCategory.audio, Icons.library_music_rounded, 'Audio'),
              (FileCategory.document, Icons.article_rounded, 'Dokumen'),
              (FileCategory.apk, Icons.android_rounded, 'Aplikasi'),
              (FileCategory.archive, Icons.folder_zip_rounded, 'Arsip'),
            ])
              _NavTile(
                icon: k.$2,
                label: k.$3,
                dot: catColor(k.$1),
                selected: nav == 0 && s.filter == k.$1,
                onTap: () {
                  goFiles();
                  c.setFilter(k.$1);
                },
              ),
            const _Section('Alat'),
            _NavTile(
              icon: Icons.pie_chart_rounded,
              label: 'Penyimpanan',
              selected: nav == 1,
              onTap: () => ref.read(navIndexProvider.notifier).set(1),
            ),
            _NavTile(
              icon: Icons.lock_rounded,
              label: 'Secure Vault',
              selected: nav == 2,
              onTap: () => ref.read(navIndexProvider.notifier).set(2),
            ),
          ]),
        ),
        Divider(height: 1, color: pal.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          child: Row(children: [
            Text('v0.1.0', style: TextStyle(color: pal.muted, fontSize: 12)),
            const Spacer(),
            IconButton(
              tooltip: switch (mode) {
                ThemeMode.dark => 'Tema: Gelap',
                ThemeMode.light => 'Tema: Terang',
                ThemeMode.system => 'Tema: Ikuti sistem',
              },
              onPressed: ref.read(themeModeProvider.notifier).cycle,
              icon: Icon(switch (mode) {
                ThemeMode.dark => Icons.dark_mode_rounded,
                ThemeMode.light => Icons.light_mode_rounded,
                ThemeMode.system => Icons.brightness_auto_rounded,
              }, size: 19),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.t);
  final String t;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 18, 10, 6),
        child: Text(t,
            style: TextStyle(
                color: Pal.of(context).muted, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? pal.select : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: pal.hover,
          onTap: onTap,
          child: Container(
            height: 38,
            padding: const EdgeInsets.only(right: 10),
            child: Row(children: [
              // aksen kiri bergradien = penanda item aktif
              Container(
                width: 3,
                height: 18,
                margin: const EdgeInsets.only(left: 2, right: 9),
                decoration: BoxDecoration(
                  gradient: selected ? Brand.gradient : null,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Icon(icon, size: 19, color: selected ? cs.primary : pal.muted),
              const SizedBox(width: 11),
              Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
              ),
              if (dot != null)
                Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DriveTile extends StatelessWidget {
  const _DriveTile(this.d, {required this.selected, required this.onTap});
  final DriveInfo d;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? pal.select : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: pal.hover,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 12, 9),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.storage_rounded, size: 18, color: pal.muted),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(d.label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 7),
              UsageBar(d.frac, height: 5),
              const SizedBox(height: 4),
              Text('${formatBytes(d.free)} kosong dari ${formatBytes(d.total)}',
                  style: TextStyle(color: pal.muted, fontSize: 11)),
            ]),
          ),
        ),
      ),
    );
  }
}
