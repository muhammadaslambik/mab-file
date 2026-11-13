import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/utils/paths.dart';
import 'vault_stream.dart';

void _tryDelete(String path) {
  try {
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
  } catch (_) {}
}

class VaultEntry {
  const VaultEntry(this.id, this.name);
  final String id, name;
}

/// Brankas terenkripsi lokal.
/// - KDF: PBKDF2-HMAC-SHA256 (210.000 iterasi) dari PIN + salt acak
/// - Cipher: AES-256-GCM (autentikasi integritas bawaan)
/// - Biometrik: membuka kunci yang disimpan di Keychain/Keystore (flutter_secure_storage)
class VaultService {
  static final _aes = AesGcm.with256bits();
  static const _check = 'mab-file-vault-v1';
  static const _secureKey = 'vault_master_key';

  final _secure = const FlutterSecureStorage();
  final _auth = LocalAuthentication();
  SecretKey? _key;

  bool get unlocked => _key != null;
  void lock() => _key = null;

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory(p.join(base.path, 'vault'));
    await d.create(recursive: true);
    return d;
  }

  Future<File> _meta() async => File(p.join((await _dir()).path, '.meta'));
  Future<bool> get isSetUp async => (await _meta()).exists();

  Future<void> setUp(String pin) async {
    if (pin.length < 4) throw ArgumentError('PIN minimal 4 digit');
    final salt = SecretKeyData.random(length: 16).bytes;
    final key = SecretKey(await vaultDeriveKey(pin, salt));
    final box = await _aes.encrypt(utf8.encode(_check), secretKey: key);
    await (await _meta()).writeAsBytes([...salt, ...box.concatenation()]);
    await _persist(key);
    _key = key;
  }

  Future<bool> unlockWithPin(String pin) async {
    final data = await (await _meta()).readAsBytes();
    final salt = data.sublist(0, 16);
    final key = SecretKey(await vaultDeriveKey(pin, salt));
    try {
      final box = SecretBox.fromConcatenation(data.sublist(16),
          nonceLength: 12, macLength: 16);
      final plain = await _aes.decrypt(box, secretKey: key);
      if (utf8.decode(plain) != _check) return false;
    } catch (_) {
      return false; // MAC gagal = PIN salah
    }
    await _persist(key);
    _key = key;
    return true;
  }

  Future<bool> unlockWithBiometric() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final ok = await _auth.authenticate(
        localizedReason: 'Buka Secure Vault mab-file',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (!ok) return false;
      final b64 = await _secure.read(key: _secureKey);
      if (b64 == null) return false;
      _key = SecretKey(base64Decode(b64));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persist(SecretKey k) async =>
      _secure.write(key: _secureKey, value: base64Encode(await k.extractBytes()));

  String _rid() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<List<int>> _enc(List<int> data) async =>
      (await _aes.encrypt(data, secretKey: _key!)).concatenation();

  Future<List<int>> _dec(List<int> data) async => _aes.decrypt(
      SecretBox.fromConcatenation(data, nonceLength: 12, macLength: 16),
      secretKey: _key!);

  /// Enkripsi file (streaming per potongan 1 MiB, format v2) lalu hapus aslinya.
  /// Aslinya baru dihapus setelah berkas terenkripsi ditulis penuh dan panjangnya cocok.
  Future<void> addFile(String path) async {
    _requireUnlocked();
    final dir = await _dir();
    final id = _rid();
    final keyBytes = await _key!.extractBytes();
    final plainLen = await File(path).length();
    final enc = p.join(dir.path, '$id.enc2');
    final part = '$enc.part';
    try {
      await vaultEncryptInIsolate(keyBytes, path, part);
      if (await File(part).length() != vaultEncryptedLength(plainLen)) {
        throw const FileSystemException('Berkas terenkripsi tidak lengkap; file asli dibiarkan utuh');
      }
      await File(part).rename(enc);
      await File(p.join(dir.path, '$id.meta'))
          .writeAsBytes(await _enc(utf8.encode(p.basename(path))));
    } catch (_) {
      _tryDelete(part);
      _tryDelete(enc);
      rethrow;
    }
    await File(path).delete();
  }

  Future<List<VaultEntry>> list() async {
    _requireUnlocked();
    final out = <VaultEntry>[];
    for (final f in (await _dir()).listSync().whereType<File>()) {
      if (!f.path.endsWith('.meta') || p.basename(f.path) == '.meta') continue;
      final id = p.basenameWithoutExtension(f.path);
      out.add(VaultEntry(id, utf8.decode(await _dec(await f.readAsBytes()))));
    }
    return out;
  }

  Future<String> export(VaultEntry e, String destDir) async {
    _requireUnlocked();
    final dir = await _dir();
    final out = uniquePath(p.join(destDir, p.basename(e.name)));
    final v2 = File(p.join(dir.path, '${e.id}.enc2'));
    if (await v2.exists()) {
      final part = '$out.part';
      try {
        await vaultDecryptInIsolate(await _key!.extractBytes(), v2.path, part);
        await File(part).rename(out);
      } catch (_) {
        _tryDelete(part);
        rethrow;
      }
      return out;
    }
    // Berkas lama (format v1, satu blok GCM) tetap bisa dibuka.
    final data = await _dec(await File(p.join(dir.path, '${e.id}.enc')).readAsBytes());
    await File(out).writeAsBytes(Uint8List.fromList(data));
    return out;
  }

  Future<void> remove(VaultEntry e) async {
    final dir = await _dir();
    for (final ext in ['enc', 'enc2', 'meta']) {
      final f = File(p.join(dir.path, '${e.id}.$ext'));
      if (await f.exists()) await f.delete();
    }
  }

  void _requireUnlocked() {
    if (_key == null) throw StateError('Vault terkunci');
  }
}
