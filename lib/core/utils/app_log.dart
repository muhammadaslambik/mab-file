import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_info.dart';

/// Log ke berkas dengan rotasi (maks ~512 KB, satu cadangan `.1`).
/// Tujuannya diagnosis: mencatat galat yang sebelumnya ditelan diam-diam, beserta pemakaian
/// memori proses (rss) saat kejadian. Log tidak pernah boleh membuat aplikasi gagal.
class AppLog {
  AppLog._();

  static const _maxBytes = 512 * 1024;
  static const _keepRecent = 40;

  static File? _file;
  static int _bytes = 0;
  static Future<void> _queue = Future.value();
  static final List<String> _recent = [];

  static String? get path => _file?.path;

  static Future<void> init() async {
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory(p.join(base.path, 'logs'));
      await dir.create(recursive: true);
      final f = File(p.join(dir.path, 'mab_file.log'));
      if (await f.exists()) {
        _bytes = await f.length();
        if (_bytes > _maxBytes) await _rotate(f);
      }
      _file = f;
      info('app', 'mulai v$kAppVersion di ${Platform.operatingSystem}');
    } catch (_) {
      // Tanpa berkas log pun aplikasi tetap berjalan.
    }
  }

  static Future<void> _rotate(File f) async {
    final old = File('${f.path}.1');
    if (await old.exists()) await old.delete();
    await f.rename(old.path);
    _bytes = 0;
  }

  static void info(String tag, String msg) => _add('INFO', tag, msg);

  static void warn(String tag, String msg) => _add('WARN', tag, '$msg | ${_mem()}');

  static void error(String tag, Object e, [StackTrace? st]) {
    final trace = st == null ? '' : '\n${st.toString().split('\n').take(20).join('\n')}';
    _add('ERROR', tag, '$e | ${_mem()}$trace');
  }

  static String _mem() => 'rss=${(ProcessInfo.currentRss / (1 << 20)).round()}MB';

  static void _add(String level, String tag, String msg) {
    final line = '${DateTime.now().toIso8601String()} [$level] $tag: $msg\n';
    _recent.add(line);
    if (_recent.length > _keepRecent) _recent.removeAt(0);
    if (kDebugMode) debugPrint(line.trimRight());
    final f = _file;
    if (f == null) return;
    _queue = _queue.then((_) async {
      try {
        if (_bytes > _maxBytes) await _rotate(f);
        await f.writeAsString(line, mode: FileMode.append);
        _bytes += line.length;
      } catch (_) {}
    });
  }

  /// Teks ringkas untuk ditempel ke laporan masalah.
  static String diagnostics() {
    final b = StringBuffer()
      ..writeln('MAB-File v$kAppVersion')
      ..writeln('OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')
      ..writeln('Dart: ${Platform.version.split(' ').first}')
      ..writeln('CPU: ${Platform.numberOfProcessors} inti, bahasa ${Platform.localeName}')
      ..writeln('Memori proses: ${_mem()}')
      ..writeln('Berkas log: ${path ?? '-'}')
      ..writeln()
      ..writeln('--- Log terakhir ---');
    for (final l in _recent) {
      b.write(l);
    }
    return b.toString();
  }
}
