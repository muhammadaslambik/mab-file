# Changelog

## 0.4.5
- Perbaikan: "Pindah ke Vault" pada FOLDER diam-diam tidak melakukan apa-apa tetapi menampilkan
  "Dipindahkan ke Vault". Kini folder dikompres ke ZIP (streaming), dienkripsi ke Vault, dan folder asli
  dihapus atau dibiarkan sesuai pilihan di dialog. Notifikasi menampilkan hasil nyata; kegagalan dilaporkan
  dan dicatat di log.
- PBKDF2 (PIN) dipindah ke Isolate agar UI tidak membeku saat membuat/membuka Vault (hasil kunci identik).
- Perbaikan lint pada tes Vault.

## 0.4.4
- Vault: format v2 dengan enkripsi streaming per potongan 1 MiB (RAM tetap kecil untuk file besar),
  dijalankan di Isolate. Tiap potongan terikat indeks, penanda akhir, dan header (anti tukar/potong).
  File asli baru dihapus setelah hasil enkripsi diperiksa lengkap. Berkas v1 lama tetap terbaca.
- Dokumen `docs/VAULT_FORMAT.md` berisi format dan batasan yang diketahui.
- Tes baru: bolak-balik berbagai ukuran, ubah byte, potong, tukar potongan, kunci salah, format salah.

## 0.4.3
- Video yang gagal di mesin Windows (mis. AV1 tanpa ekstensi codec) kini otomatis dibuka dengan mpv,
  tidak berhenti di halaman galat; kejadiannya dicatat di log.
- Memilih "Bawaan" pada dekode mpv memulihkan `auto` (nilai bawaan terukur), bukan `auto-safe`.

## 0.4.2
- Eksperimen GPU mpv: pilihan "Dekode video mpv" di dialog tema (hanya Windows) dan pencatatan dekoder
  yang benar-benar dipakai (`hwdec-current`) ke log, supaya penyebab beban GPU/CPU bisa diukur.

## 0.4.1
- Arsip tidak lagi memuat seluruh isi ke RAM: ZIP/TAR dibuat dan diekstrak per file lewat aliran disk;
  TAR.GZ lewat gzip streaming. Entri zip-slip kini ditolak SEBELUM ada file yang ditulis.
  Arsip setengah jadi dihapus bila gagal.
- Tes baru: file 6 MB utuh di ketiga format, tanpa berkas .tmp, zip-slip tanpa tulisan sebagian.

## 0.4.0
- Log ke berkas (rotasi) + penangkap galat global; galat yang dulu ditelan kini dicatat dengan pemakaian memori.
- Tombol "Salin info diagnostik" di dialog tema (ikon palet).
- Urutan nama alami (file2 sebelum file10).
- Dialog Properti (Alt+Enter / klik kanan), ukuran folder dihitung di Isolate.
- Tombol "Jalankan" di editor kode meminta konfirmasi; keluaran dibatasi 200 rb karakter.
- Nomor versi satu sumber (`lib/core/app_info.dart`) dan dijaga tes.
- Tes baru: urutan alami, util, arsip (termasuk zip-slip), pengaturan, operasi file, versi.

## 0.3.11
Mesin video Windows asli sebagai default di Windows; pemutar sistem di Linux/macOS; mpv di HP dan sebagai fallback.

## 0.3.3 - 0.3.10
Viewer gambar dengan dekode terbatas, throttle posisi pemutar (GPU musik 9,5% -> ~1,5%), pilihan mesin video,
halaman Lisensi pihak ketiga, halaman audio kompak.
