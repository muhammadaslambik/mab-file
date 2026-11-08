import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/paths.dart';

enum ArchiveFormat { zip, tar, tarGz }

/// Arsip diproses per file lewat aliran disk (tidak lagi memuat seluruh isi ke RAM):
/// - ZIP/TAR dibuat dengan ZipFileEncoder/TarFileEncoder, file demi file.
/// - TAR.GZ: TAR sementara lalu gzip streaming milik dart:io.
/// - Ekstrak: InputFileStream + OutputFileStream per entri; TAR.GZ di-gunzip ke berkas sementara.
class ArchiveService {
  Future<String> compress(List<String> paths, String destDir, ArchiveFormat f) =>
      Isolate.run(() => _compress(paths, destDir, f));

  Future<String> extract(String archivePath, String destDir) =>
      Isolate.run(() => _extract(archivePath, destDir));
}

/// Pasangan (file, nama di dalam arsip). Hanya file biasa; tautan simbolik dilewati.
Iterable<(File, String)> _entries(List<String> paths) sync* {
  for (final path in paths) {
    final parent = p.dirname(path);
    if (FileSystemEntity.isDirectorySync(path)) {
      for (final e in Directory(path).listSync(recursive: true, followLinks: false)) {
        if (e is File) {
          yield (e, p.relative(e.path, from: parent).replaceAll('\\', '/'));
        }
      }
    } else {
      yield (File(path), p.basename(path));
    }
  }
}

Future<String> _compress(List<String> paths, String destDir, ArchiveFormat f) async {
  final base = paths.length == 1 ? p.basenameWithoutExtension(paths.first) : 'archive';
  final ext = switch (f) {
    ArchiveFormat.zip => '.zip',
    ArchiveFormat.tar => '.tar',
    ArchiveFormat.tarGz => '.tar.gz',
  };
  final out = uniquePath(p.join(destDir, '$base$ext'));
  final tarTarget = f == ArchiveFormat.tarGz ? '$out.tmp' : out;
  try {
    if (f == ArchiveFormat.zip) {
      final enc = ZipFileEncoder()..create(out);
      try {
        for (final (file, rel) in _entries(paths)) {
          await enc.addFile(file, rel);
        }
      } finally {
        await enc.close();
      }
    } else {
      final enc = TarFileEncoder()..create(tarTarget);
      try {
        for (final (file, rel) in _entries(paths)) {
          await enc.addFile(file, rel);
        }
      } finally {
        await enc.close();
      }
      if (f == ArchiveFormat.tarGz) {
        await File(tarTarget).openRead().transform(gzip.encoder).pipe(File(out).openWrite());
      }
    }
    return out;
  } catch (_) {
    _tryDelete(out); // jangan tinggalkan arsip setengah jadi
    rethrow;
  } finally {
    if (tarTarget != out) _tryDelete(tarTarget);
  }
}

void _tryDelete(String path) {
  try {
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
  } catch (_) {}
}

String _stem(String path) {
  var n = p.basename(path);
  final l = n.toLowerCase();
  if (l.endsWith('.tar.gz')) return n.substring(0, n.length - 7);
  return p.basenameWithoutExtension(n);
}

Future<String> _extract(String archivePath, String destDir) async {
  final lower = archivePath.toLowerCase();
  final outDir = uniquePath(p.join(destDir, _stem(archivePath)));

  if (lower.endsWith('.rar') || lower.endsWith('.7z')) {
    return _extractExternal(archivePath, outDir);
  }

  InputFileStream? input;
  String? tmpDir;
  try {
    final Archive archive;
    if (lower.endsWith('.zip') || lower.endsWith('.apk')) {
      input = InputFileStream(archivePath);
      archive = ZipDecoder().decodeBuffer(input);
    } else if (lower.endsWith('.tar')) {
      input = InputFileStream(archivePath);
      archive = TarDecoder().decodeBuffer(input);
    } else if (lower.endsWith('.tar.gz') || lower.endsWith('.tgz')) {
      tmpDir = Directory.systemTemp.createTempSync('mabfile_tgz').path;
      final tmpTar = p.join(tmpDir, 'a.tar');
      await File(archivePath).openRead().transform(gzip.decoder).pipe(File(tmpTar).openWrite());
      input = InputFileStream(tmpTar);
      archive = TarDecoder().decodeBuffer(input);
    } else {
      throw UnsupportedError('Format arsip tidak didukung');
    }

    Directory(outDir).createSync(recursive: true);
    final root = p.canonicalize(outDir);
    // Proteksi zip-slip: periksa SEMUA entri dulu, sebelum satu byte pun ditulis.
    for (final f in archive) {
      if (!p.isWithin(root, p.canonicalize(p.join(outDir, f.name)))) {
        throw FileSystemException('Entri arsip berbahaya ditolak', f.name);
      }
    }
    for (final f in archive) {
      final target = p.canonicalize(p.join(outDir, f.name));
      if (f.isFile) {
        Directory(p.dirname(target)).createSync(recursive: true);
        final out = OutputFileStream(target);
        try {
          f.writeContent(out);
        } finally {
          await out.close();
        }
      } else {
        Directory(target).createSync(recursive: true);
      }
    }
    return outDir;
  } finally {
    await input?.close();
    if (tmpDir != null) {
      try {
        Directory(tmpDir).deleteSync(recursive: true);
      } catch (_) {}
    }
  }
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
