import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../../../core/utils/paths.dart';
import '../domain/file_item.dart';

class FileService {
  /// Listing di Isolate dengan statSync: jauh lebih cepat & UI tidak tersendat untuk folder besar.
  Future<List<FileItem>> list(String dir, {bool showHidden = false}) =>
      Isolate.run(() => _listSync(dir, showHidden));

  Future<void> copy(String src, String destDir) async {
    if (p.equals(src, destDir) || p.isWithin(src, destDir)) {
      throw const FileSystemException('Tidak bisa menyalin folder ke dalam dirinya sendiri');
    }
    await _copyTo(src, uniquePath(p.join(destDir, p.basename(src))));
  }

  Future<void> _copyTo(String src, String target) async {
    if (await FileSystemEntity.isDirectory(src)) {
      await Directory(target).create(recursive: true);
      await for (final e in Directory(src).list(followLinks: false)) {
        await _copyTo(e.path, p.join(target, p.basename(e.path)));
      }
    } else {
      await File(src).copy(target);
    }
  }

  Future<void> move(String src, String destDir) async {
    final target = uniquePath(p.join(destDir, p.basename(src)));
    if (p.equals(src, target)) return;
    final isDir = await FileSystemEntity.isDirectory(src);
    try {
      isDir ? await Directory(src).rename(target) : await File(src).rename(target);
    } on FileSystemException {
      // beda volume: salin lalu hapus
      await _copyTo(src, target);
      await delete(src);
    }
  }

  Future<void> delete(String path) async {
    if (await FileSystemEntity.isDirectory(path)) {
      await Directory(path).delete(recursive: true);
    } else {
      await File(path).delete();
    }
  }

  Future<void> rename(String path, String newName) async {
    if (newName.contains(RegExp(r'[\\/]'))) {
      throw const FileSystemException('Nama tidak boleh mengandung / atau \\');
    }
    final target = p.join(p.dirname(path), newName);
    if (FileSystemEntity.typeSync(target) != FileSystemEntityType.notFound) {
      throw const FileSystemException('Nama sudah dipakai');
    }
    if (await FileSystemEntity.isDirectory(path)) {
      await Directory(path).rename(target);
    } else {
      await File(path).rename(target);
    }
  }

  Future<void> createFolder(String dir, String name) =>
      Directory(uniquePath(p.join(dir, name))).create();

  Future<void> createFile(String dir, String name) =>
      File(uniquePath(p.join(dir, name))).create();

  /// Deep search rekursif di Isolate agar UI tetap 60fps.
  Future<List<FileItem>> search(String root,
          {String query = '', FileCategory? category, int limit = 1000}) =>
      Isolate.run(() => _search(root, query.toLowerCase(), category, limit));

  /// N file terbesar di bawah [root].
  Future<List<FileItem>> largest(String root, {int top = 50, int maxEntities = 120000}) =>
      Isolate.run(() {
        final all = <FileItem>[];
        var seen = 0;
        for (final e in _walk(root)) {
          if (++seen > maxEntities) break; // batas agar tetap ringan
          if (e is File) {
            try {
              final st = e.statSync();
              all.add(FileItem(path: e.path, isDir: false, size: st.size, modified: st.modified));
            } catch (_) {}
          }
        }
        all.sort((a, b) => b.size.compareTo(a.size));
        return all.take(top).toList();
      });
}

List<FileItem> _listSync(String dir, bool showHidden) {
  final out = <FileItem>[];
  for (final e in Directory(dir).listSync(followLinks: false)) {
    if (!showHidden && p.basename(e.path).startsWith('.')) continue;
    try {
      final st = e.statSync();
      out.add(FileItem(
        path: e.path,
        isDir: st.type == FileSystemEntityType.directory,
        size: st.size,
        modified: st.modified,
      ));
    } catch (_) {/* abaikan entri yang tak bisa dibaca */}
  }
  return out;
}

List<FileItem> _search(String root, String q, FileCategory? cat, int limit) {
  final out = <FileItem>[];
  for (final e in _walk(root)) {
    final name = p.basename(e.path);
    if (q.isNotEmpty && !name.toLowerCase().contains(q)) continue;
    final isDir = e is Directory;
    if (cat != null && categoryOf(e.path, isDir: isDir) != cat) continue;
    try {
      final st = e.statSync();
      out.add(FileItem(path: e.path, isDir: isDir, size: st.size, modified: st.modified));
    } catch (_) {}
    if (out.length >= limit) break;
  }
  return out;
}

/// Penelusuran iteratif yang tahan terhadap folder tanpa izin.
Iterable<FileSystemEntity> _walk(String root) sync* {
  final stack = <String>[root];
  while (stack.isNotEmpty) {
    final dir = stack.removeLast();
    List<FileSystemEntity> children;
    try {
      children = Directory(dir).listSync(followLinks: false);
    } catch (_) {
      continue;
    }
    for (final c in children) {
      if (p.basename(c.path).startsWith('.')) continue;
      yield c;
      if (c is Directory) stack.add(c.path);
    }
  }
}
