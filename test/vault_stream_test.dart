import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mab_file/features/vault/vault_stream.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  final key = List<int>.generate(32, (i) => i);
  const chunk = 4096;
  const rec = chunk + 28;
  setUp(() => tmp = Directory.systemTemp.createTempSync('mabvault'));
  tearDown(() => tmp.deleteSync(recursive: true));

  List<int> sample(int n) => List<int>.generate(n, (i) => (i * 7 + 3) & 0xFF);

  Future<String> encrypt(int n, {int chunkSize = chunk}) async {
    final src = File(p.join(tmp.path, 'src.bin'))..writeAsBytesSync(sample(n));
    final enc = p.join(tmp.path, 'x.enc2');
    await vaultEncryptFile(key, src.path, enc, chunkSize: chunkSize);
    return enc;
  }

  for (final n in [0, 1, chunk - 1, chunk, chunk + 1, 3 * chunk, 3 * chunk + 5]) {
    test('bolak-balik $n byte', () async {
      final enc = await encrypt(n);
      expect(File(enc).lengthSync(), vaultEncryptedLength(n, chunkSize: chunk));
      final out = p.join(tmp.path, 'out.bin');
      await vaultDecryptFile(key, enc, out);
      expect(File(out).readAsBytesSync(), sample(n));
    });
  }

  test('ukuran bawaan 1 MiB: berkas 2,5 MiB utuh', () async {
    const n = 2 * 1024 * 1024 + 512 * 1024;
    final enc = await encrypt(n, chunkSize: vaultChunkSize);
    expect(File(enc).lengthSync(), vaultEncryptedLength(n));
    final out = p.join(tmp.path, 'out.bin');
    await vaultDecryptFile(key, enc, out);
    expect(File(out).readAsBytesSync(), sample(n));
  });

  test('byte yang diubah terdeteksi', () async {
    final enc = await encrypt(3 * chunk + 5);
    final b = File(enc).readAsBytesSync();
    b[24 + 100] ^= 0x01;
    File(enc).writeAsBytesSync(b);
    await expectLater(vaultDecryptFile(key, enc, p.join(tmp.path, 'o')), throwsA(isA<FormatException>()));
  });

  test('pemotongan di batas potongan terdeteksi', () async {
    final enc = await encrypt(3 * chunk);
    final b = File(enc).readAsBytesSync();
    File(enc).writeAsBytesSync(b.sublist(0, 24 + 2 * rec));
    await expectLater(vaultDecryptFile(key, enc, p.join(tmp.path, 'o')), throwsA(isA<FormatException>()));
  });

  test('potongan yang ditukar urutannya terdeteksi', () async {
    final enc = await encrypt(3 * chunk);
    final b = File(enc).readAsBytesSync();
    final swapped = Uint8List.fromList([
      ...b.sublist(0, 24),
      ...b.sublist(24 + rec, 24 + 2 * rec),
      ...b.sublist(24, 24 + rec),
      ...b.sublist(24 + 2 * rec),
    ]);
    File(enc).writeAsBytesSync(swapped);
    await expectLater(vaultDecryptFile(key, enc, p.join(tmp.path, 'o')), throwsA(isA<FormatException>()));
  });

  test('kunci salah ditolak', () async {
    final enc = await encrypt(chunk + 10);
    final wrong = List<int>.generate(32, (i) => 255 - i);
    await expectLater(vaultDecryptFile(wrong, enc, p.join(tmp.path, 'o')), throwsA(isA<FormatException>()));
  });

  test('vaultDeriveKey sama dengan PBKDF2 langsung (PIN lama tetap valid)', () async {
    final salt = List<int>.generate(16, (i) => i * 3);
    final direct = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 210000, bits: 256)
        .deriveKeyFromPassword(password: '1234', nonce: salt);
    expect(await vaultDeriveKey('1234', salt), await direct.extractBytes());
  });

  test('berkas bukan format v2 ditolak', () async {
    final f = File(p.join(tmp.path, 'junk.enc2'))..writeAsBytesSync(sample(100));
    await expectLater(vaultDecryptFile(key, f.path, p.join(tmp.path, 'o')), throwsA(isA<FormatException>()));
  });
}
