import 'package:flutter_test/flutter_test.dart';
import 'package:mab_file/core/utils/natural_sort.dart';

void main() {
  test('angka dibandingkan sebagai angka', () {
    final l = ['file10', 'file2', 'File1', 'b', 'a'];
    l.sort(naturalCompare);
    expect(l, ['a', 'b', 'File1', 'file2', 'file10']);
  });

  test('kapital diabaikan', () => expect(naturalCompare('abc', 'ABC'), 0));

  test('nol di depan hanya penentu terakhir', () {
    expect(naturalCompare('a1', 'a01') < 0, isTrue);
    expect(naturalCompare('a01a', 'a1b') < 0, isTrue);
  });

  test('awalan lebih pendek lebih dulu', () {
    expect(naturalCompare('a', 'ab') < 0, isTrue);
    expect(naturalCompare('', 'a') < 0, isTrue);
  });
}
