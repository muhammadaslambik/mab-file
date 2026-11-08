import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mab_file/features/file_manager/data/file_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  final fs = FileService();
  setUp(() => tmp = Directory.systemTemp.createTempSync('mabfs2'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('folder tidak bisa disalin ke dalam dirinya sendiri', () async {
    final d = Directory(p.join(tmp.path, 'd'))..createSync();
    final inner = Directory(p.join(d.path, 'in'))..createSync();
    await expectLater(fs.copy(d.path, inner.path), throwsA(isA<FileSystemException>()));
  });

  test('rename menolak pemisah path dan nama yang sudah ada', () async {
    final a = File(p.join(tmp.path, 'a.txt'))..writeAsStringSync('1');
    File(p.join(tmp.path, 'b.txt')).writeAsStringSync('2');
    await expectLater(fs.rename(a.path, 'x/y.txt'), throwsA(isA<FileSystemException>()));
    await expectLater(fs.rename(a.path, 'b.txt'), throwsA(isA<FileSystemException>()));
  });

  test('list menyembunyikan file berawalan titik kecuali diminta', () async {
    File(p.join(tmp.path, '.rahasia')).writeAsStringSync('1');
    File(p.join(tmp.path, 'biasa.txt')).writeAsStringSync('1');
    expect((await fs.list(tmp.path)).map((e) => e.name), ['biasa.txt']);
    expect((await fs.list(tmp.path, showHidden: true)).length, 2);
  });

  test('folderStats menghitung file, folder, dan byte (termasuk tersembunyi)', () async {
    Directory(p.join(tmp.path, 'x', 'y')).createSync(recursive: true);
    File(p.join(tmp.path, 'x', 'a.bin')).writeAsBytesSync(List.filled(100, 1));
    File(p.join(tmp.path, 'x', 'y', '.b.bin')).writeAsBytesSync(List.filled(50, 1));
    final s = await fs.folderStats(tmp.path);
    expect(s.files, 2);
    expect(s.dirs, 2);
    expect(s.bytes, 150);
    expect(s.capped, isFalse);
  });
}
