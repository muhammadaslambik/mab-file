import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mab_file/core/app_info.dart';

void main() {
  test('kAppVersion sama dengan pubspec.yaml', () {
    final txt = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true).firstMatch(txt);
    expect(m, isNotNull);
    expect(m!.group(1), kAppVersion);
  });
}
