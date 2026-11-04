# mab-file

File manager cross-platform (Windows · Android · iOS · macOS · Linux) berbasis **Flutter + Dart**.
100% on-device, tanpa server, tanpa akun, tanpa biaya.

## Fitur
- Copy / Cut / Paste / Rename / Delete / New Folder / New File / Multi-select
- Deep search (berjalan di Isolate) + filter tipe (dokumen, gambar, video, audio, APK, arsip)
- Storage Analyzer (pie chart + pelacak file terbesar)
- Viewer bawaan: gambar (zoom), video/audio (media_kit), text/code editor
- ZIP / TAR / TAR.GZ (buat & ekstrak, dengan proteksi zip-slip); RAR/7z via binary 7z di desktop
- Secure Vault: AES-256-GCM, kunci dari PIN (PBKDF2-HMAC-SHA256), biometrik opsional

## Mulai
```bash
bash scripts/bootstrap.sh   # generate folder platform + pub get
flutter run -d linux        # atau windows / macos / android / ios
```
Lihat `docs/PLATFORM_SETUP.md` untuk izin & dependensi tiap OS.

## Arsitektur
`lib/core` (tema, util) · `lib/features/<fitur>/{domain,data,application,presentation}`
State management: Riverpod (Notifier). I/O berat selalu lewat `Isolate.run`.
