# HANDOFF MAB-File: status v0.3.11 (disusun 2026-11-08)

Dokumen ini untuk Claude di sesi chat baru. Baca seluruhnya sebelum menjawab. File
`HANDOFF_mab-file.md` yang lama (v0.3.2) masih relevan untuk arsitektur, tetapi kode di
dalamnya SUDAH BERUBAH. Minta pengguna mengunggah zip sumber terbaru (lihat bagian 9).

## 1. Konteks proyek dan tujuan pengguna
- Aplikasi: **MAB-File**, manajer file lintas platform (Flutter/Dart, riverpod). Target: Windows
  (utama, diuji), Android, iOS, macOS, Linux. Pengembang tunggal, bahasa kerja: **Indonesia**.
- Folder kerja: `E:\0\MAB Project\mab-file`. JANGAN tertukar dengan `E:\0\MAB Project\mab-pdf`
  (proyek lain; pernah salah memasang patch ke sana).
- Tujuan: tampilan bagus, fitur lengkap, **ringan**, **bisa dikomersilkan**, pengembangan
  **gratis tanpa kartu kredit/debit**, jalan di **desktop dan HP**. Untuk Google Play ($25 sekali)
  dan App Store ($99/tahun) pengguna sudah menyatakan bisa menganggarkan nanti.
- Pengguna lebih suka jawaban jujur, singkat, dan terukur. Jangan berjanji berlebihan.

## 2. Cara kerja yang disepakati (PENTING)
- Claude TIDAK bisa menjalankan Flutter/aplikasi di sandbox. Semua kode ditulis "buta"; pengguna
  yang membangun dan mengukur. Selalu katakan "belum dikompilasi" dan minta `flutter analyze`.
- Pengiriman perubahan: **zip berisi hanya berkas yang berubah**, jalur relatif dari akar proyek.
  Pasang di PowerShell (akar proyek):
  ```powershell
  taskkill /IM mab_file.exe /F 2>$null
  Expand-Archive -Force $env:USERPROFILE\Downloads\<nama-zip>.zip .
  flutter analyze
  flutter build windows --release; start build\windows\x64\runner\Release\mab_file.exe
  ```
  Tambah `flutter pub get` bila `pubspec.yaml` menambah paket. Selalu tutup aplikasi dulu.
- Berkas proyek memakai **CRLF**. Saat mengedit dengan Python: baca, ubah `\r\n`->`\n`, edit,
  tulis kembali dengan `\r\n`. Periksa keseimbangan kurung sebelum mengemas.
- Tiap rilis: naikkan `version:` di `pubspec.yaml`, teks `'v0.3.x'` di
  `lib/features/file_manager/presentation/widgets/sidebar.dart`, dan `applicationVersion` di
  `lib/core/widgets/theme_picker.dart`. Minta pengguna memastikan sidebar menampilkan versi baru.
- Pengukuran: Task Manager (CPU/GPU/Memori baris `mab_file`), bandingkan dengan Media Player
  Windows pada file yang sama. Catat kondisi (ukuran jendela, jenis file) karena memengaruhi angka.
- Hati-hati: keluaran alat bash menampilkan tanda kutip ber-escape JSON; jangan menyamakannya
  dengan isi berkas. Satu skrip patch pernah gagal di tengah dan menghasilkan zip tidak lengkap:
  periksa semua perubahan masuk (grep) sebelum mengemas.

## 3. Riwayat versi (yang sudah dikerjakan)

| Versi | Isi |
|---|---|
| 0.3.3 | Viewer gambar dengan dekode terbatas (ResizeImage, maks 2560x1600) + evict; fallback `image` hanya sekali (Future di initState), dikecilkan 2048 px, batas 40 MB; listing file: fallback sinkron bila Isolate gagal; `_loadSeq` mengabaikan hasil muat basi; `MediaKit.ensureInitialized()` kembali ke `main()`; perbandingan path lewat `Media(x).uri` (`PlayerHub.isSame`). |
| 0.3.4 | Seek ulang setelah trek video dinyalakan (kemudian tidak relevan). |
| 0.3.5 | Fitur mematikan trek video saat halaman pemutar ditutup DIMATIKAN (`_pauseVideoWhenHidden = false`) karena membuat video hitam/pecah di Windows. |
| 0.3.6 | Profil mpv `fast` + `RepaintBoundary` (tidak ada penurunan terukur; tidak berbahaya). |
| 0.3.7 | `PlayerHub.position` dibatasi ~400 ms; MiniPlayer dan slider halaman audio memakainya. GPU musik 9,5% -> ~1,5%. |
| 0.3.8 | Pengaturan `videoMode` (auto/system/builtin/native); `showLicensePage` ("Lisensi pihak ketiga"); halaman audio kompak di jendela rendah (<720 px). |
| 0.3.9 | `lib/features/player/native_video_page.dart` memakai paket `video_player_win` (Windows Media Foundation); dropdown "Pemutar video" di dialog tema (ikon palet). |
| 0.3.10 | `auto` di Windows memakai mesin Windows asli (build uji). |
| 0.3.11 | Default resmi: Windows asli di Windows, pemutar sistem di Linux/macOS, mpv (MediaPage) di HP. Halaman galat menawarkan "Coba dengan pemutar MAB (mpv)" dan "Buka dengan aplikasi default". Kontrol volume, pintasan Spasi dan panah kiri/kanan (5 dtk). |

Dokumen yang dibuat: `docs/LICENSES_AUDIT.md` (sudah di repo), `docs/COMMERCIAL_READINESS.md`.

## 4. Hasil pengukuran (iGPU Intel, Windows, file "Piche Kota" 1280x720 25fps 347 kbps)

| Kondisi | CPU | GPU | Memori |
|---|---|---|---|
| v0.3.2 awal (kondisi berat) | 21,6% | 49,8% | 623 MB |
| Musik saja v0.3.3 (halaman ditutup) | 6,7% | 9,5% | 481 MB |
| Musik saja v0.3.7 | 0,5% | 1,1-1,5% | 210-265 MB |
| Dijeda/idle | 0% | 0% | 366 MB (v0.3.3) |
| Video mpv, jendela lebar (v0.3.6) | 3,4% | 27,5% | 305 MB |
| Video mpv, jendela sempit (v0.3.7) | 3,9% | 21,3% | 300 MB |
| Video Windows asli, sempit (v0.3.10) | 2,9% | 7,1% | 216 MB |
| Video Windows asli, lebih lebar (v0.3.11) | 2,4% | 11,1% | 240 MB |
| Media Player Windows (pembanding) | 1,2-1,7% | 3,7-4,5% | 102-146 MB |

Temuan kunci:
- Penyebab beban musik/UI: event posisi mpv membangun ulang widget tiap event; tiap rebuild =
  satu frame penuh jendela Flutter di GPU. Solusi: batasi frekuensi (sudah).
- Menyalakan/mematikan trek video mpv (`setVideoTrack`) di Windows merusak video (hitam/pecah).
  JANGAN dihidupkan lagi tanpa pengujian.
- Mesin `video_player_win` ~2,5-3x lebih hemat GPU daripada mpv, tetapi tetap ~2-3x di atas
  Media Player (frame tetap lewat Flutter).

## 5. BELUM dikerjakan / harus dilakukan

### A. Blokir rilis komersial (prioritas tertinggi)
1. **Lisensi libmpv/FFmpeg Windows belum terkonfirmasi.** Minta pengguna menjalankan perintah di
   `docs/LICENSES_AUDIT.md` bagian 3 (membaca flag `--enable-...` dari `libmpv-2.dll`), lalu
   bacakan hasilnya: `--enable-gpl`/`--enable-nonfree` = jangan rilis tertutup sebelum diganti
   build LGPL/ditinjau. Bukan nasihat hukum; sarankan ahli hukum.
2. **`LICENSE` proyek masih MIT** (siapa pun boleh menjual ulang kode). Pengguna harus memutuskan:
   repo privat + lisensi proprietari/EULA, atau model lain. PASTIKAN repo GitHub privat.
3. Verifikasi lisensi tiap paket di pub.dev (tabel di `LICENSES_AUDIT.md` ditulis dari ingatan;
   `open_filex` WAJIB dicek). `video_player_win` = BSD-3 (terkonfirmasi).
4. EULA (jangan melarang reverse engineering komponen LGPL), kebijakan privasi (Vault/biometrik),
   pemeriksaan merek "MAB-File", teks lisensi library native di halaman Tentang, paten codec.

### B. Verifikasi v0.3.11 (pengguna belum melaporkan)
- Video lain di folder Musik: ada yang hitam/pecah/gagal? Tombol "Coba dengan pemutar MAB (mpv)"
  berfungsi? Pintasan Spasi/panah dan volume berfungsi? Beban GPU saat 1+ menit.
- Dialog tema (ikon palet): dropdown "Pemutar video" berfungsi dan tersimpan di `settings.json`.

### C. Fitur pemutar yang belum ada (native_video_page)
- Layar penuh (butuh paket pengatur jendela, mis. `window_manager`; periksa lisensi/kompatibilitas),
  antrean tampilan, subtitle, kecepatan putar, ingat posisi terakhir.
- Format di luar codec bawaan Windows (MKV, dll.) hanya lewat fallback mpv.

### D. HP (Android/iOS), BELUM disentuh dan BELUM diuji
- Sambungkan video HP ke paket resmi `video_player` (dokumentasi `video_player_win` menyebut
  kombinasi ini untuk Windows/Android/iOS). Saat ini HP memakai mpv (`MediaPage`).
- Audit fitur khusus desktop agar aman di HP: FFmpeg eksternal (`Process.start('ffmpeg')`), 7z,
  "Run" di editor kode (`Process.start`), pengukur disk, `isDesktopPlatform`.
- Uji di perangkat nyata (kinerja, izin penyimpanan, `permission_handler`, `local_auth`).

### E. Stabilitas dan mutu
- Bug awal "semua jenis file tiba-tiba tidak terbaca lalu normal lagi" BELUM terbukti beres.
  Dugaan: tekanan RAM sistem (Chrome ~1 GB + VS Code ~0,5-1,4 GB saat itu). Tambahkan log ke
  berkas (rotasi) dan catat Memory% saat muncul.
- Memori idle sesekali 362 MB (vs 210-265 MB) belum dijelaskan.
- Uji otomatis: `test/` hanya `file_service_test.dart`. Tambah untuk listing, pencarian,
  salin/pindah/hapus, perbandingan path Windows, pengaturan.
- Pelaporan crash (opt-in) dan halaman "Salin info diagnostik".
- Keamanan: "Run" di editor kode perlu konfirmasi/pembatasan; audit Vault sebelum klaim keamanan.

### F. Tampilan dan distribusi
- Sistem desain tunggal, uji kontras 12 tema, tata letak sempit/aksesibilitas, keadaan
  kosong/galat/memuat.
- Distribusi: Microsoft Store (individu gratis, tanpa kartu, MSIX), APK langsung untuk Android
  (gratis), Google Play ($25 sekali), App Store ($99/tahun; build iOS butuh Mac atau layanan
  build cloud, harga belum dicek). Penandatanganan kode Windows. Syarat menjual aplikasi
  berbayar dari Indonesia di Play/App Store BELUM diperiksa. Pembayaran pelanggan belum dipilih.
- Roadmap lama (Cloud, otomasi ala n8n, AI Agent) sangat besar. Saran: rilis 1.0 = manajer file +
  viewer + musik/video; tambah modul per rilis, dimuat malas dan mati secara default.

### G. Dokumentasi repo
- `README.md` masih teks v0.1; `docs/ROADMAP.md` perlu diperbarui; tambahkan aturan "tutup
  aplikasi sebelum build"; simpan `docs/COMMERCIAL_READINESS.md` di repo bila belum ada.

## 6. Keputusan arsitektur yang berlaku
- Musik: media_kit (libmpv), `PlayerHub`. Video: `NativeVideoPage` (Windows), pemutar sistem
  (Linux/macOS), `MediaPage` mpv (HP dan fallback).
- Pengaturan di `lib/core/settings/settings.dart`: `videoMode` in {auto, system, builtin, native};
  getter `videoUsesNative` dan `videoUsesSystemPlayer`; disimpan di `settings.json`.
- Router pembuka file: `openItem` dan `playSelection` di
  `lib/features/file_manager/presentation/file_actions.dart`.
- FFmpeg dipanggil sebagai program luar milik pengguna (tidak dibundel): aman bagi lisensi
  selama tetap tidak dibundel.

## 7. Jebakan yang pernah terjadi
- Patch dipasang di folder salah (`mab-pdf`): cek `pwd` dan `dir lib\main.dart` sebelum
  `Expand-Archive`.
- Mematikan trek video mpv saat halaman ditutup: video hitam/pecah.
- Zip tidak lengkap akibat skrip patch gagal di tengah.
- Dropdown "Pemutar video" belum diubah pengguna sehingga video tetap dilempar ke Media Player
  (default lama). Sekarang default Windows sudah native.

## 8. Saran urutan kerja berikutnya
1. Pengguna menjalankan perintah DLL (A1) dan memverifikasi v0.3.11 (B).
2. Putuskan LICENSE/privasi repo (A2). Jangan memublikasikan kode sebelum itu.
3. Jalur video HP (D), lalu audit fitur desktop-only di HP.
4. Uji otomatis + log berkas (E), lalu polesan tampilan (F), lalu distribusi.

## 9. Yang harus diunggah pengguna di sesi baru
- Berkas ini dan `HANDOFF_mab-file.md` (lama).
- Zip sumber terbaru: `git archive --format=zip -o "$env:USERPROFILE\Downloads\mab-file-src-v0.3.11.zip" HEAD`
  (setelah commit). Jangan memakai `mab-file-src.zip` lama (v0.3.2).
