import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/utils/app_log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLog.init();
  // Semua galat (framework maupun async yang tak tertangkap) dicatat ke berkas log.
  FlutterError.onError = (d) {
    FlutterError.presentError(d);
    AppLog.error('flutter', d.exception, d.stack);
  };
  PlatformDispatcher.instance.onError = (e, st) {
    AppLog.error('async', e, st);
    return true;
  };
  // Batasi cache gambar agar memori tetap kecil.
  PaintingBinding.instance.imageCache
    ..maximumSizeBytes = 64 << 20
    ..maximumSize = 300;
  // Inisialisasi media_kit di awal (sesuai dokumentasi) demi keandalan. Ini hanya memuat
  // library; objek Player (yang berat) tetap dibuat malas saat pertama memutar.
  MediaKit.ensureInitialized();
  runApp(const ProviderScope(child: MabFileApp()));
}
