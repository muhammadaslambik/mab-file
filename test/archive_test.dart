import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:mab_file/features/archive/archive_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  final svc = ArchiveService();
  setUp(() => tmp = Directory.systemTemp.createTempSync('mabarc'));
  tearDown(() => tmp.deleteSync(recursive: true));

  for (final f in ArchiveFormat.values) {
    test('kompres lalu ekstrak: $f', () async {
      final src = Directory(p.join(tmp.path, 'src', 'proj'))..createSync(recursive: true);
      File(p.join(src.path, 'a.txt')).writeAsStringSync('halo');
      Directory(p.join(src.path, 'sub')).createSync();
      File(p.join(src.path, 'sub', 'b.txt')).writeAsStringSync('dunia');
      final out = Directory(p.join(tmp.path, 'out'))..createSync();
      final archive = await svc.compress([src.path], out.path, f);
      expect(File(archive).existsSync(), isTrue);

      final dest = Directory(p.join(tmp.path, 'ex'))..createSync();
      final dir = await svc.extract(archive, dest.path);
      expect(File(p.join(dir, 'proj', 'a.txt')).readAsStringSync(), 'halo');
      expect(File(p.join(dir, 'proj', 'sub', 'b.txt')).readAsStringSync(), 'dunia');
    });
  }

  test('zip-slip ditolak', () async {
    final a = Archive()..addFile(ArchiveFile('../evil.txt', 1, [65]));
    final z = File(p.join(tmp.path, 'bad.zip'))..writeAsBytesSync(ZipEncoder().encode(a)!);
    final dest = Directory(p.join(tmp.path, 'ex'))..createSync();
    await expectLater(svc.extract(z.path, dest.path), throwsA(anything));
    expect(File(p.join(dest.path, 'evil.txt')).existsSync(), isFalse);
    expect(File(p.join(tmp.path, 'evil.txt')).existsSync(), isFalse);
  });

  test('zip-slip: tidak ada file yang tertulis sebelum entri jahat ditolak', () async {
    final a = Archive()
      ..addFile(ArchiveFile('ok.txt', 2, [72, 73]))
      ..addFile(ArchiveFile('../evil.txt', 1, [65]));
    final z = File(p.join(tmp.path, 'bad2.zip'))..writeAsBytesSync(ZipEncoder().encode(a)!);
    final dest = Directory(p.join(tmp.path, 'ex2'))..createSync();
    await expectLater(svc.extract(z.path, dest.path), throwsA(anything));
    expect(File(p.join(dest.path, 'bad2', 'ok.txt')).existsSync(), isFalse);
  });

  test('file besar (6 MB) utuh dan tanpa berkas sementara tersisa', () async {
    final src = Directory(p.join(tmp.path, 'big'))..createSync();
    final bytes = List<int>.generate(6 * 1024 * 1024, (i) => (i * 31 + (i >> 8)) & 0xFF);
    File(p.join(src.path, 'big.bin')).writeAsBytesSync(bytes);
    for (final f in ArchiveFormat.values) {
      final out = Directory(p.join(tmp.path, 'o_${f.name}'))..createSync();
      final archive = await svc.compress([src.path], out.path, f);
      expect(out.listSync().length, 1, reason: 'hanya arsip, tanpa .tmp');
      final dest = Directory(p.join(tmp.path, 'e_${f.name}'))..createSync();
      final dir = await svc.extract(archive, dest.path);
      final got = File(p.join(dir, 'big', 'big.bin')).readAsBytesSync();
      expect(got.length, bytes.length);
      expect(listEquals(got, bytes), isTrue, reason: 'isi berbeda untuk $f');
    }
  });
}
