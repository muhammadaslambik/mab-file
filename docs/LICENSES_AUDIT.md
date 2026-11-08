# Audit lisensi MAB-File (draf untuk diperiksa)

> Dokumen kerja, BUKAN nasihat hukum. Kolom "Status" menunjukkan apa yang sudah dan belum
> terverifikasi. Sebelum rilis berbayar, verifikasi tiap baris di pub.dev dan minta tinjauan
> ahli hukum.

Tanggal draf: 2026-11-08 · Versi aplikasi: 0.3.7

## 1. Lisensi proyek sendiri

`LICENSE` saat ini berisi **MIT** (Copyright 2026 Muhammad Aslambik).
Artinya siapa pun yang memegang kodenya boleh menyalin, memodifikasi, dan MENJUAL ulang.
Untuk produk komersial tertutup, putuskan dulu:
- Repo harus privat dan lisensi diganti menjadi "All rights reserved"/EULA proprietari, atau
- Tetap MIT (model open-core) dan jual layanan/dukungan/build resmi.

## 2. Paket Dart/Flutter langsung (pubspec.yaml)

Lisensi di bawah dicatat dari ingatan penyusun dan HARUS diverifikasi di pub.dev.

| Paket | Lisensi (perkiraan) | Status |
|---|---|---|
| flutter_riverpod | MIT | verifikasi |
| path | BSD-3 | verifikasi |
| path_provider | BSD-3 | verifikasi |
| permission_handler | MIT | verifikasi |
| archive | MIT | verifikasi |
| cryptography | Apache-2.0 | verifikasi |
| local_auth | BSD-3 | verifikasi |
| flutter_secure_storage | BSD-3 | verifikasi |
| fl_chart | MIT | verifikasi |
| flutter_svg | MIT | verifikasi |
| open_filex | belum pasti | VERIFIKASI WAJIB |
| xml | MIT | verifikasi |
| image | MIT | verifikasi |
| media_kit | MIT | verifikasi |
| media_kit_video | MIT | verifikasi |
| media_kit_libs_video | MIT (pembungkus) | verifikasi |
| flutter_lints (dev) | BSD-3 | tidak ikut dirilis |
| flutter_launcher_icons (dev) | MIT | tidak ikut dirilis |

Cara otomatis mengumpulkan semua lisensi (termasuk dependensi turunan) dari proyek:
Flutter menyediakan `LicenseRegistry`; tampilkan lewat `showLicensePage()` di layar "Tentang"
(sudah ada daftar lisensi bawaan Flutter untuk semua paket yang dibundel).

## 3. Library native video: poin PALING penting

`media_kit_libs_windows_video` (pembungkus) berlisensi MIT, tetapi ia membawa **libmpv + FFmpeg**
dari `media-kit/libmpv-win32-video-build`, turunan dari `zhongfly/mpv-winbuild`. Upstream itu
menerbitkan dua varian: build default dan build `lgpl`. Pernyataan lisensi untuk build yang
dipakai media_kit di Windows BELUM terkonfirmasi.

Fakta yang sudah terkonfirmasi dari sumber publik:
- mpv secara keseluruhan default GPLv2+, tetapi libmpv dapat dibangun sebagai LGPLv2.1+.
- Build LGPL boleh dipakai di aplikasi komersial dengan syarat: tautan dinamis, sertakan teks
  lisensi LGPL, dan EULA tidak melarang reverse engineering komponen LGPL tsb.
- Build macOS/iOS milik tim media_kit dinyatakan kompatibel dengan penggunaan komersial.

### Cara memeriksa build Windows Anda (PowerShell di folder proyek, setelah build release)

```powershell
Get-ChildItem build\windows\x64\runner\Release -Filter "*mpv*"
$dll = "build\windows\x64\runner\Release\libmpv-2.dll"
$b = [IO.File]::ReadAllBytes($dll)
$t = [Text.Encoding]::ASCII.GetString($b)
[regex]::Matches($t, '--enable-[a-z0-9-]+') | ForEach-Object Value | Sort-Object -Unique
```

Cara membaca hasilnya (indikasi, bukan putusan hukum):
- Ada `--enable-gpl` atau `--enable-nonfree` -> FFmpeg di dalamnya GPL/nonfree: JANGAN dirilis
  tertutup sebelum diganti build LGPL atau dikonsultasikan.
- Tidak ada keduanya -> bagian FFmpeg kemungkinan LGPL. Bagian mpv sendiri tetap perlu dipastikan
  dari dokumentasi build-nya.
Kirim daftar `--enable-...` itu agar dibaca bersama.

Paten codec (H.264, HEVC, AAC, dll.) adalah isu terpisah dari lisensi kode; tanyakan ahli hukum
sebelum menjual di wilayah tujuan.

## 4. Komponen yang dipanggil sebagai program luar

| Komponen | Cara pakai | Catatan |
|---|---|---|
| FFmpeg (Studio Media) | `Process.start('ffmpeg')`, TIDAK dibundel; pengguna memasang sendiri | Posisi lisensi aman selama tidak dibundel. Jika kelak dibundel, build-nya harus dicek (GPL/LGPL). |
| 7z (arsip) | `Process.runSync(bin, ['x', ...])` | Sama: jangan dibundel tanpa mencatat lisensinya (7-Zip: LGPL + aturan unRAR). |
| Run di editor kode | `Process.start(...)` | Risiko keamanan: perlu konfirmasi eksplisit dan peringatan. |

## 5. Yang perlu dibuat sebelum rilis
- Layar "Tentang" + daftar lisensi pihak ketiga (showLicensePage) dan salinan teks LGPL.
- EULA yang TIDAK melarang reverse engineering komponen LGPL.
- Kebijakan privasi (terutama untuk Vault, login biometrik, dan penyimpanan aman).
- Pemeriksaan merek dagang untuk nama "MAB-File"/logo sebelum penjualan.

## 6. Tambahan v0.3.9 (eksperimen)

| Paket | Lisensi | Status |
|---|---|---|
| video_player_win | BSD-3-Clause | terkonfirmasi di pub.dev (halaman lisensi paket); memakai Windows Media Foundation, tanpa library GPL/LGPL pihak ketiga menurut README-nya |

Catatan: format yang diputar mengikuti codec bawaan Windows. Build Windows mungkin perlu dijalankan
sebagai Administrator jika muncul galat "MSB3073" (petunjuk dari README paket).
