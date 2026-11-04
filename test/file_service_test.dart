import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mab_file/features/file_manager/data/file_service.dart';
import 'package:mab_file/features/file_manager/domain/file_item.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  final fs = FileService();

  setUp(() => tmp = Directory.systemTemp.createTempSync('mabfile'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('kategori file', () {
    expect(categoryOf('a.PNG'), FileCategory.image);
    expect(categoryOf('a.apk'), FileCategory.apk);
    expect(categoryOf('x', isDir: true), FileCategory.folder);
  });

  test('copy, move, rename, delete', () async {
    final a = File(p.join(tmp.path, 'a.txt'))..writeAsStringSync('hi');
    final dir = Directory(p.join(tmp.path, 'd'))..createSync();
    await fs.copy(a.path, dir.path);
    expect(File(p.join(dir.path, 'a.txt')).existsSync(), isTrue);
    await fs.move(a.path, dir.path); // bentrok -> "a (1).txt"
    expect(File(p.join(dir.path, 'a (1).txt')).existsSync(), isTrue);
    await fs.rename(p.join(dir.path, 'a.txt'), 'b.txt');
    expect(File(p.join(dir.path, 'b.txt')).existsSync(), isTrue);
    await fs.delete(dir.path);
    expect(dir.existsSync(), isFalse);
  });

  test('deep search', () async {
    Directory(p.join(tmp.path, 'x', 'y')).createSync(recursive: true);
    File(p.join(tmp.path, 'x', 'y', 'rahasia.pdf')).writeAsStringSync('1');
    final r = await fs.search(tmp.path, query: 'rahasia');
    expect(r.length, 1);
  });
}
