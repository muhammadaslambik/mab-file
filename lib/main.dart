import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Batasi cache gambar agar memori tetap kecil.
  PaintingBinding.instance.imageCache
    ..maximumSizeBytes = 64 << 20
    ..maximumSize = 300;
  // Inisialisasi media_kit di awal (sesuai dokumentasi) demi keandalan. Ini hanya memuat
  // library; objek Player (yang berat) tetap dibuat malas saat pertama memutar.
  MediaKit.ensureInitialized();
  runApp(const ProviderScope(child: MabFileApp()));
}
