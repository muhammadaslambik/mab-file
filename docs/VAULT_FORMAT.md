# Format dan batasan Vault

> Dokumen teknis, BUKAN klaim keamanan. Vault belum diaudit pihak independen.

## Format v2 (`<id>.enc2`, sejak 0.4.4)
- Streaming per potongan 1 MiB, jadi RAM tetap kecil untuk file besar.
- Header 24 B: `MBV2` | ukuran potongan (u32 LE) | salt acak 16 B.
- Tiap potongan: AES-256-GCM, nonce acak 12 B, tag 16 B, AAD = header + indeks potongan + penanda "terakhir".
- Potongan tidak bisa ditukar, dipindah antarberkas, atau dipotong di batas potongan tanpa terdeteksi (diuji di `test/vault_stream_test.dart`).
- Nama asli disimpan terenkripsi di `<id>.meta` (AES-GCM satu blok). Ukuran file tetap terlihat.
- File asli dihapus hanya setelah berkas terenkripsi ditulis penuh dan panjangnya cocok.

## Format v1 (`<id>.enc`)
Satu blok AES-GCM di memori. Masih dibaca; file baru selalu ditulis v2.

## Batasan yang diketahui
- File asli dihapus dengan penghapusan biasa (bukan penimpaan aman); sisa data masih bisa dipulihkan dengan alat forensik, terutama di SSD.
- Kunci utama disimpan di penyimpanan aman OS agar biometrik bisa membukanya; siapa pun yang menguasai akun OS pengguna mungkin dapat mengaksesnya tanpa PIN.
- PIN minimal 4 digit (PBKDF2-HMAC-SHA256, 210.000 iterasi): lemah terhadap serangan offline pada `.meta`.
- Enkripsi memakai AES Dart murni (`cryptography`), jalan di Isolate; lebih lambat dari AES native.
- Belum ada migrasi otomatis v1 -> v2.
