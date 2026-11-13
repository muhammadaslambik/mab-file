import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Format berkas Vault v2 (`<id>.enc2`), enkripsi per potongan (streaming) agar RAM tetap kecil.
///
/// ```
/// header (24 B) : "MBV2" | chunkSize u32 LE | salt acak 16 B
/// potongan ke-i : nonce 12 B | ciphertext (<= chunkSize) | tag GCM 16 B
/// ```
/// Tiap potongan dienkripsi AES-256-GCM dengan nonce acak dan AAD = header + indeks (u64 LE) +
/// penanda "terakhir" (1 B). Akibatnya potongan tidak bisa ditukar urutannya, dipindah ke berkas
/// lain, maupun dipotong di batas potongan tanpa terdeteksi. Berkas v1 (`<id>.enc`, satu blok GCM)
/// tetap dibaca oleh VaultService.
const int vaultChunkSize = 1 << 20;
const int _headerLen = 24;
const int _overhead = 28; // nonce 12 + tag 16
const List<int> _magic = [0x4D, 0x42, 0x56, 0x32]; // "MBV2"

/// Panjang berkas terenkripsi untuk [plainLength] byte (untuk memeriksa hasil tulis).
int vaultEncryptedLength(int plainLength, {int chunkSize = vaultChunkSize}) {
  final chunks = plainLength == 0 ? 1 : (plainLength + chunkSize - 1) ~/ chunkSize;
  return _headerLen + chunks * _overhead + plainLength;
}

List<int> _aad(Uint8List header, int index, bool last) {
  final out = Uint8List(header.length + 9)..setRange(0, header.length, header);
  ByteData.sublistView(out).setUint64(header.length, index, Endian.little);
  out[header.length + 8] = last ? 1 : 0;
  return out;
}

Future<void> vaultEncryptFile(List<int> keyBytes, String src, String dst,
    {int chunkSize = vaultChunkSize}) async {
  final aes = AesGcm.with256bits();
  final key = SecretKey(keyBytes);
  final header = Uint8List(_headerLen)..setRange(0, 4, _magic);
  ByteData.sublistView(header).setUint32(4, chunkSize, Endian.little);
  header.setRange(8, _headerLen, SecretKeyData.random(length: 16).bytes);

  final input = File(src).openSync();
  final output = File(dst).openSync(mode: FileMode.write);
  try {
    output.writeFromSync(header);
    var cur = input.readSync(chunkSize);
    var index = 0;
    while (true) {
      // Intip potongan berikutnya agar tahu apakah ini yang terakhir.
      final next = cur.length == chunkSize ? input.readSync(chunkSize) : Uint8List(0);
      final last = next.isEmpty;
      final box = await aes.encrypt(cur, secretKey: key, aad: _aad(header, index, last));
      output.writeFromSync(box.concatenation());
      if (last) break;
      cur = next;
      index++;
    }
    output.flushSync();
  } finally {
    input.closeSync();
    output.closeSync();
  }
}

Future<void> vaultDecryptFile(List<int> keyBytes, String src, String dst) async {
  final aes = AesGcm.with256bits();
  final key = SecretKey(keyBytes);
  final input = File(src).openSync();
  RandomAccessFile? output;
  try {
    final header = input.readSync(_headerLen);
    if (header.length != _headerLen ||
        header[0] != _magic[0] ||
        header[1] != _magic[1] ||
        header[2] != _magic[2] ||
        header[3] != _magic[3]) {
      throw const FormatException('Format berkas Vault tidak dikenal');
    }
    final chunkSize = ByteData.sublistView(header).getUint32(4, Endian.little);
    if (chunkSize < 1024 || chunkSize > (64 << 20)) {
      throw const FormatException('Ukuran potongan Vault tidak wajar');
    }
    final record = chunkSize + _overhead;
    output = File(dst).openSync(mode: FileMode.write);
    var cur = input.readSync(record);
    var index = 0;
    while (true) {
      if (cur.length < _overhead) throw const FormatException('Berkas Vault terpotong');
      final next = cur.length == record ? input.readSync(record) : Uint8List(0);
      final last = next.isEmpty;
      final plain = await aes.decrypt(
        SecretBox.fromConcatenation(cur, nonceLength: 12, macLength: 16),
        secretKey: key,
        aad: _aad(header, index, last),
      );
      output.writeFromSync(plain);
      if (last) break;
      cur = next;
      index++;
    }
    output.flushSync();
  } on SecretBoxAuthenticationError {
    throw const FormatException('Berkas Vault rusak, diubah, atau kunci salah');
  } finally {
    input.closeSync();
    output?.closeSync();
  }
}

/// Kunci dari PIN: PBKDF2-HMAC-SHA256, 210.000 iterasi, 256 bit (sama dengan sebelumnya).
/// Dijalankan di Isolate karena Dart murni cukup lama dan akan membekukan UI bila di isolate utama.
Future<List<int>> vaultDeriveKey(String pin, List<int> salt) => Isolate.run(() async {
      final kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 210000, bits: 256);
      final key = await kdf.deriveKeyFromPassword(password: pin, nonce: salt);
      return key.extractBytes();
    });

/// Dijalankan di Isolate terpisah supaya AES (Dart murni) tidak membekukan UI.
Future<void> vaultEncryptInIsolate(List<int> keyBytes, String src, String dst) =>
    Isolate.run(() => vaultEncryptFile(keyBytes, src, dst));

Future<void> vaultDecryptInIsolate(List<int> keyBytes, String src, String dst) =>
    Isolate.run(() => vaultDecryptFile(keyBytes, src, dst));
