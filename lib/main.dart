import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Batasi cache gambar agar memori tetap kecil.
  PaintingBinding.instance.imageCache
    ..maximumSizeBytes = 64 << 20
    ..maximumSize = 300;
  // media_kit (libmpv) TIDAK dimuat di sini; baru dimuat saat pertama kali memutar media.
  runApp(const ProviderScope(child: MabFileApp()));
}
