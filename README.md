# MAB-File

Manajer file lintas platform (Windows, Android, iOS, macOS, Linux) berbasis **Flutter + Dart**.
100% di perangkat: tanpa server, tanpa akun.

*English: a cross-platform file manager built with Flutter. Everything runs on-device. Windows is the main tested target.*

> Status: **v0.4.0**, dalam pengembangan aktif. Windows adalah target yang diuji. Android/iOS/macOS/Linux
> berbagi kode yang sama tetapi belum diuji di perangkat nyata.

## Fitur
- Salin, potong, tempel, ganti nama, hapus, folder/file baru, multi-seleksi, pintasan keyboard, menu klik kanan
- Urutan nama alami, dialog Properti (ukuran folder dihitung di Isolate)
- Pencarian dalam folder (Isolate) dan filter jenis (dokumen, gambar, video, audio, APK, arsip)
- Penganalisis penyimpanan (grafik + file terbesar)
- Viewer: gambar (dekode terbatas agar hemat memori), Markdown, Office (docx/xlsx/pptx), editor kode dengan highlight
- Pemutar musik latar + antrean + playlist; video lewat mesin Windows asli (hemat GPU) dengan fallback mpv
- ZIP/TAR/TAR.GZ (buat dan ekstrak, dengan proteksi zip-slip); RAR/7z lewat 7-Zip bila terpasang
- Vault terenkripsi (AES-256-GCM, kunci dari PIN via PBKDF2-HMAC-SHA256, biometrik opsional)
- 12 tema, termasuk mode otomatis mengikuti sistem

## Performa (terukur, iGPU Intel, Windows)
| Skenario | CPU | GPU | Memori |
|---|---|---|---|
| Musik saja | 0,5% | 1-1,5% | 210-265 MB |
| Video mesin mpv | 3,4-3,9% | 21-27% | ~300 MB |
| Video mesin Windows asli | 2,4-2,9% | 7-11% | 216-240 MB |
| Media Player Windows (pembanding) | 1,2-1,7% | 3,7-4,5% | 102-146 MB |

Pelajaran utama: event posisi pemutar yang membangun ulang UI tiap event membuat GPU sibuk; solusinya
membatasi frekuensi update. Rincian di `CHANGELOG.md` dan `docs/`.

## Menjalankan
```bash
bash scripts/bootstrap.sh   # membuat folder platform + pub get
flutter run -d windows      # atau linux / macos / android / ios
flutter test
```
Izin dan dependensi tiap OS: `docs/PLATFORM_SETUP.md`.

## Arsitektur
`lib/core` (tema, pengaturan, log, util) dan `lib/features/<fitur>/{domain,data,application,presentation}`.
State: Riverpod (Notifier). I/O berat selalu lewat `Isolate.run`. Galat dicatat ke berkas log
(`AppLog`) dan bisa disalin lewat "Salin info diagnostik".

## Lisensi
Kode ini **source-available** di bawah **PolyForm Noncommercial License 1.0.0** (lihat `LICENSE`).
Anda boleh membaca, menjalankan, dan mempelajarinya untuk tujuan nonkomersial. Penggunaan komersial
membutuhkan lisensi tersendiri dari pemegang hak cipta. Ini bukan lisensi open source menurut OSI.
Pustaka pihak ketiga tetap memakai lisensi masing-masing (lihat halaman "Lisensi pihak ketiga" di aplikasi
dan `docs/LICENSES_AUDIT.md`).
