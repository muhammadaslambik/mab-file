# Roadmap mab-file

## v0.2.0 (rilis ini)
Logo baru (M terlihat), 12 tema + latar animasi, notifikasi in-app, viewer universal
(gambar/SVG/TIFF/ICO, audio/video semua format via libmpv, Markdown, HTML, kode, Word/Excel/PowerPoint/ODF),
editor kode (highlight, nomor baris, Run), editor gambar, Studio Media (FFmpeg).

## Tahap 2 — Cloud
Google Drive & Workspace (OAuth desktop loopback; unduh/unggah; ekspor Docs/Sheets/Slides ke docx/xlsx/pptx/pdf).
Butuh Client ID dari Google Cloud Console (gratis, tanpa kartu kredit).

## Tahap 3 — Otomasi
Workflow lokal ala n8n: pemicu (manual, jadwal, pantau folder) -> aksi (salin/pindah/ganti nama/kompres/
konversi media/notifikasi/HTTP/jalankan perintah). Definisi disimpan sebagai JSON.

## Tahap 4 — AI Agent
Agent dengan alat file (baca, tulis, cari, pindah, zip, konversi) yang memakai model lokal (Ollama, gratis)
atau API pilihan Anda, dengan konfirmasi sebelum aksi yang mengubah/menghapus file.

## Lainnya
PDF viewer native, FFmpeg di Android/iOS, tag & recent files, recycle bin, crop interaktif.
