import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';

import 'vault_stream.dart';

/// Mengukur kecepatan NYATA di mesin ini (MB/dtk): enkripsi/dekripsi Vault dan ZIP (bawaan vs level 0).
/// Memakai data acak 16 MiB di berkas sementara, di Isolate. Hasilnya satu baris teks.
Future<String> runVaultBenchmark() => Isolate.run(_bench);

Future<String> _bench() async {
  const size = 16 << 20;
  final dir = Directory.systemTemp.createTempSync('mabbench');
  try {
    final rnd = Random(42);
    final data = Uint8List(size);
    for (var i = 0; i < size; i++) {
      data[i] = rnd.nextInt(256);
    }
    final src = File('${dir.path}${Platform.pathSeparator}b.bin')..writeAsBytesSync(data);
    final key = List<int>.generate(32, (i) => i);
    final enc = '${src.path}.enc2';
    final out = '${src.path}.out';

    String rate(Stopwatch sw) =>
        (size / 1048576 / (sw.elapsedMicroseconds / 1e6)).toStringAsFixed(1);
    String mib(int bytes) => (bytes / 1048576).toStringAsFixed(1);

    var sw = Stopwatch()..start();
    await vaultEncryptFile(key, src.path, enc);
    sw.stop();
    final encRate = rate(sw);

    sw = Stopwatch()..start();
    await vaultDecryptFile(key, enc, out);
    sw.stop();
    final decRate = rate(sw);

    final zDef = '${src.path}.def.zip';
    sw = Stopwatch()..start();
    final e1 = ZipFileEncoder()..create(zDef);
    await e1.addFile(src, 'b.bin');
    await e1.close();
    sw.stop();
    final defRate = rate(sw);
    final defSize = File(zDef).lengthSync();

    final zSto = '${src.path}.sto.zip';
    sw = Stopwatch()..start();
    final e2 = ZipFileEncoder()..create(zSto);
    await e2.addFile(src, 'b.bin', 0);
    await e2.close();
    sw.stop();
    final stoRate = rate(sw);
    final stoSize = File(zSto).lengthSync();

    return 'AES-GCM enkripsi $encRate MB/dtk, dekripsi $decRate MB/dtk; '
        'ZIP bawaan $defRate MB/dtk (hasil ${mib(defSize)} MiB), '
        'ZIP level 0 $stoRate MB/dtk (hasil ${mib(stoSize)} MiB); data acak ${mib(size)} MiB';
  } finally {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  }
}
