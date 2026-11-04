import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../file_manager/application/file_manager_state.dart';
import '../file_manager/domain/file_item.dart';
import '../file_manager/presentation/widgets/glyph.dart';

class DriveInfo {
  const DriveInfo(this.path, this.label, this.total, this.free);
  final String path, label;
  final int total, free;
  int get used => total - free;
  double get frac => total == 0 ? 0 : used / total;
}

const _psScript =
    r"Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null } | ForEach-Object { $_.Name + ',' + $_.Used + ',' + $_.Free }";

/// Tanpa plugin: PowerShell (Windows, 1x panggilan untuk semua drive) / `df` (lainnya).
Future<List<DriveInfo>> listDrives() async {
  try {
    if (Platform.isWindows) {
      final r = await Process.run(
          'powershell', ['-NoProfile', '-NonInteractive', '-Command', _psScript]);
      final out = <DriveInfo>[];
      for (final line in r.stdout.toString().split(RegExp(r'[\r\n]+'))) {
        final t = line.trim().split(',');
        if (t.length != 3) continue;
        final used = int.tryParse(t[1]), free = int.tryParse(t[2]);
        if (used == null || free == null) continue;
        out.add(DriveInfo('${t[0]}:\\', 'Disk Lokal (${t[0]}:)', used + free, free));
      }
      return out;
    }
    if (Platform.isIOS) return [];
    final root = Platform.isAndroid ? '/storage/emulated/0' : '/';
    final r = await Process.run('df', ['-k', root]);
    final cols = r.stdout
        .toString()
        .trim()
        .split('\n')
        .skip(1)
        .join(' ')
        .split(RegExp(r'\s+'));
    return [
      DriveInfo(root, Platform.isAndroid ? 'Penyimpanan internal' : 'Disk utama',
          int.parse(cols[1]) * 1024, int.parse(cols[3]) * 1024)
    ];
  } catch (_) {
    return [];
  }
}

final drivesProvider = FutureProvider<List<DriveInfo>>((_) => listDrives());

DriveInfo? driveFor(List<DriveInfo> ds, String path) {
  if (ds.isEmpty) return null;
  if (Platform.isWindows && path.length >= 2) {
    final l = path.substring(0, 2).toLowerCase();
    for (final d in ds) {
      if (d.path.substring(0, 2).toLowerCase() == l) return d;
    }
  }
  return ds.first;
}

/// Bar gradien tipis untuk pemakaian disk. Merah bila hampir penuh (seperti Explorer).
class UsageBar extends StatelessWidget {
  const UsageBar(this.frac, {super.key, this.height = 6});
  final double frac;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final hot = frac > 0.9;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: pal.border,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: frac.clamp(0.02, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: hot
                  ? const LinearGradient(
                      colors: [Color(0xFFFF8A5B), Color(0xFFFF3B5C)])
                  : Brand.gradient,
            ),
          ),
        ),
      ),
    );
  }
}

final largestProvider = FutureProvider.autoDispose<List<FileItem>>(
    (ref) => ref.read(fileServiceProvider).largest(ref.read(fmProvider).path));

class StorageAnalyzerPage extends ConsumerWidget {
  const StorageAnalyzerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drives = ref.watch(drivesProvider);
    final big = ref.watch(largestProvider);
    final cur = ref.watch(fmProvider.select((s) => s.path));
    final pal = Pal.of(context);
    final cs = Theme.of(context).colorScheme;
    final maxSize = big.maybeWhen(
        data: (l) => l.isEmpty ? 1 : l.first.size, orElse: () => 1);

    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Penyimpanan',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      drives.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Kapasitas tidak tersedia: $e'),
        data: (ds) {
          if (ds.isEmpty) {
            return Text('Kapasitas tidak tersedia di perangkat ini.',
                style: TextStyle(color: pal.muted));
          }
          final main = driveFor(ds, cur)!;
          return Wrap(spacing: 16, runSpacing: 16, children: [
            Container(
              width: 340,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: pal.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: pal.border),
              ),
              child: Row(children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(alignment: Alignment.center, children: [
                    PieChart(PieChartData(
                      startDegreeOffset: -90,
                      centerSpaceRadius: 42,
                      sectionsSpace: 0,
                      sections: [
                        PieChartSectionData(
                            value: main.used.toDouble(),
                            color: cs.primary,
                            title: '',
                            radius: 14),
                        PieChartSectionData(
                            value: main.free.toDouble(),
                            color: pal.border,
                            title: '',
                            radius: 14),
                      ],
                    )),
                    Text('${(main.frac * 100).round()}%',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(main.label,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('Terpakai ${formatBytes(main.used)}',
                            style: TextStyle(color: pal.muted)),
                        Text('Tersisa ${formatBytes(main.free)}',
                            style: TextStyle(color: pal.muted)),
                        Text('Total ${formatBytes(main.total)}',
                            style: TextStyle(color: pal.muted)),
                      ]),
                ),
              ]),
            ),
            for (final d in ds.where((d) => d != main))
              Container(
                width: 260,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: pal.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: pal.border),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.label,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      UsageBar(d.frac),
                      const SizedBox(height: 8),
                      Text(
                          '${formatBytes(d.free)} kosong dari ${formatBytes(d.total)}',
                          style: TextStyle(color: pal.muted, fontSize: 12)),
                    ]),
              ),
          ]);
        },
      ),
      const SizedBox(height: 28),
      Text('File terbesar di folder aktif',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700)),
      Text(cur, style: TextStyle(color: pal.muted, fontSize: 12)),
      const SizedBox(height: 8),
      big.when(
        loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text('$e'),
        data: (l) => Column(children: [
          for (final f in l.take(30))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                FileGlyph(f, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.name, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        UsageBar(f.size / maxSize, height: 4),
                      ]),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: Text(formatBytes(f.size),
                      textAlign: TextAlign.right,
                      style: TextStyle(color: pal.muted)),
                ),
              ]),
            ),
        ]),
      ),
    ]);
  }
}
