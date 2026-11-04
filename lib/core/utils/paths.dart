import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Nama unik: "file.txt" -> "file (1).txt" bila sudah ada.
String uniquePath(String path) {
  if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
    return path;
  }
  final dir = p.dirname(path);
  final ext = p.extension(path);
  final base = p.basenameWithoutExtension(path);
  var i = 1;
  while (true) {
    final c = p.join(dir, '$base ($i)$ext');
    if (FileSystemEntity.typeSync(c) == FileSystemEntityType.notFound) return c;
    i++;
  }
}

Future<String> defaultRoot() async {
  if (Platform.isAndroid) return '/storage/emulated/0';
  if (Platform.isIOS) return (await getApplicationDocumentsDirectory()).path;
  return Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.current.path;
}
