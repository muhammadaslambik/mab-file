import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mab_file/core/utils/formatters.dart';
import 'package:mab_file/core/utils/paths.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('mabpaths'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('uniquePath menambah nomor', () {
    final f = p.join(tmp.path, 'x.txt');
    expect(uniquePath(f), f);
    File(f).writeAsStringSync('1');
    expect(uniquePath(f), p.join(tmp.path, 'x (1).txt'));
    File(p.join(tmp.path, 'x (1).txt')).writeAsStringSync('1');
    expect(uniquePath(f), p.join(tmp.path, 'x (2).txt'));
  });

  test('formatBytes', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(1023), '1023 B');
    expect(formatBytes(1024), '1.0 KB');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(150 * 1024), '150 KB');
    expect(formatBytes(1 << 20), '1.0 MB');
  });

  test('formatDate', () {
    expect(formatDate(DateTime(2026, 1, 2, 3, 4)), '2026-01-02 03:04');
  });
}
