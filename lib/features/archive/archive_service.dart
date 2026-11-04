import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/paths.dart';

enum ArchiveFormat { zip, tar, tarGz }

class ArchiveService {
  Future<String> compress(List<String> paths, String destDir, ArchiveFormat f) =>
      Isolate.run(() => _compress(paths, destDir, f));

  Future<String> extract(String archivePath, String destDir) =>
      Isolate.run(() => _extract(archivePath, destDir));
}

String _compress(List<String> paths, String destDir, ArchiveFormat f) {
  final archive = Archive();
  for (final path in paths) {
    final parent = p.dirname(path);
    final entities = FileSystemEntity.isDirectorySync(path)
        ? Directory(path).listSync(recursive: true, followLinks: false)
        : <FileSystemEntity>[File(path)];
    for (final e in entities) {
      if (e is! File) continue;
      final bytes = e.readAsBytesSync();
      final rel = p.relative(e.path, from: parent).replaceAll('\\', '/');
      archive.addFile(ArchiveFile(rel, bytes.length, bytes));
    }
  }
  final base = paths.length == 1 ? p.basenameWithoutExtension(paths.first) : 'archive';
  late List<int> data;
  late String ext;
  switch (f) {
    case ArchiveFormat.zip:
      data = ZipEncoder().encode(archive)!;
      ext = '.zip';
    case ArchiveFormat.tar:
      data = TarEncoder().encode(archive);
      ext = '.tar';
    case ArchiveFormat.tarGz:
      data = GZipEncoder().encode(TarEncoder().encode(archive))!;
      ext = '.tar.gz';
  }
  final out = uniquePath(p.join(destDir, '$base$ext'));
  File(out).writeAsBytesSync(data);
  return out;
}

String _stem(String path) {
  var n = p.basename(path);
  final l = n.toLowerCase();
  if (l.endsWith('.tar.gz')) return n.substring(0, n.length - 7);
  return p.basenameWithoutExtension(n);
}

String _extract(String archivePath, String destDir) {
  final lower = archivePath.toLowerCase();
  final outDir = uniquePath(p.join(destDir, _stem(archivePath)));

  if (lower.endsWith('.rar') || lower.endsWith('.7z')) {
    return _extractExternal(archivePath, outDir);
  }

  final bytes = File(archivePath).readAsBytesSync();
  Archive archive;
  if (lower.endsWith('.zip') || lower.endsWith('.apk')) {
    archive = ZipDecoder().decodeBytes(bytes);
  } else if (lower.endsWith('.tar')) {
    archive = TarDecoder().decodeBytes(bytes);
  } else if (lower.endsWith('.tar.gz') || lower.endsWith('.tgz')) {
    archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
  } else {
    throw UnsupportedError('Format arsip tidak didukung');
  }

  Directory(outDir).createSync(recursive: true);
  final root = p.canonicalize(outDir);
  for (final f in archive) {
    final target = p.canonicalize(p.join(outDir, f.name));
    // Proteksi zip-slip: tolak path keluar dari folder tujuan
    if (!p.isWithin(root, target)) {
      throw FileSystemException('Entri arsip berbahaya ditolak', f.name);
    }
    if (f.isFile) {
      File(target)
        ..createSync(recursive: true)
        ..writeAsBytesSync(f.content as List<int>);
    } else {
      Directory(target).createSync(recursive: true);
    }
  }
  return outDir;
}

/// RAR/7z: tidak ada decoder RAR pure-Dart. Di desktop, pakai binary `7z`/`7zz`.
String _extractExternal(String archivePath, String outDir) {
  if (!(Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
    throw UnsupportedError(
        'RAR/7z di mobile membutuhkan libarchive via FFI (lihat roadmap).');
  }
  Directory(outDir).createSync(recursive: true);
  for (final bin in ['7z', '7zz', '7za']) {
    try {
      final r = Process.runSync(bin, ['x', archivePath, '-o$outDir', '-y']);
      if (r.exitCode == 0) return outDir;
    } on ProcessException {
      continue;
    }
  }
  throw UnsupportedError('Pasang 7-Zip (gratis) dan pastikan ada di PATH.');
}
