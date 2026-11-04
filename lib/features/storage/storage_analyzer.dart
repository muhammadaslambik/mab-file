import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../file_manager/application/file_manager_state.dart';
import '../file_manager/domain/file_item.dart';

class StorageInfo {
  const StorageInfo(this.total, this.free);
  final int total, free;
  int get used => total - free;
}

/// Tanpa plugin: `df` (Linux/macOS/Android) dan PowerShell (Windows).
Future<StorageInfo> probeStorage(String path) async {
  if (Platform.isWindows) {
    final drive = path.substring(0, 1);
    final r = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      r'$d=Get-PSDrive ' + drive + r'; "$($d.Used),$($d.Free)"'
    ]);
    final parts = r.stdout.toString().trim().split(',');
    final used = int.parse(parts[0]), free = int.parse(parts[1]);
    return StorageInfo(used + free, free);
  }
  if (Platform.isIOS) {
    throw UnsupportedError('iOS tidak mengekspos kapasitas lewat dart:io');
  }
  final r = await Process.run('df', ['-k', path]);
  final cols = r.stdout.toString().trim().split('\n').skip(1).join(' ').split(RegExp(r'\s+'));
  return StorageInfo(int.parse(cols[1]) * 1024, int.parse(cols[3]) * 1024);
}

final storageProvider = FutureProvider.autoDispose<StorageInfo>(
    (ref) => probeStorage(ref.read(fmProvider).path));

final largestProvider = FutureProvider.autoDispose<List<FileItem>>(
    (ref) => ref.read(fileServiceProvider).largest(ref.read(fmProvider).path));

class StorageAnalyzerPage extends ConsumerWidget {
  const StorageAnalyzerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(storageProvider);
    final big = ref.watch(largestProvider);
    final cs = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.all(16), children: [
      info.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Kapasitas tidak tersedia: $e'),
        data: (s) => Row(children: [
          SizedBox(
            width: 160,
            height: 160,
            child: PieChart(PieChartData(
              centerSpaceRadius: 50,
              sectionsSpace: 2,
              sections: [
                PieChartSectionData(value: s.used.toDouble(), color: cs.primary, title: '', radius: 24),
                PieChartSectionData(value: s.free.toDouble(), color: cs.secondary, title: '', radius: 24),
              ],
            )),
          ),
          const SizedBox(width: 24),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Terpakai: ${formatBytes(s.used)}'),
            Text('Tersisa: ${formatBytes(s.free)}'),
            Text('Total: ${formatBytes(s.total)}'),
          ]),
        ]),
      ),
      const SizedBox(height: 24),
      Text('File terbesar di folder ini', style: Theme.of(context).textTheme.titleMedium),
      big.when(
        loading: () => const Padding(
            padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text('$e'),
        data: (l) => Column(children: [
          for (final f in l.take(30))
            ListTile(
              dense: true,
              title: Text(f.name, overflow: TextOverflow.ellipsis),
              subtitle: Text(f.path, overflow: TextOverflow.ellipsis),
              trailing: Text(formatBytes(f.size)),
            ),
        ]),
      ),
    ]);
  }
}
