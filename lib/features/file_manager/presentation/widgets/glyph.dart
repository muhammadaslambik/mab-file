import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../core/theme/app_theme.dart';
import '../../domain/file_item.dart';

Color catColor(FileCategory c) => switch (c) {
      FileCategory.folder => Brand.blue,
      FileCategory.image => const Color(0xFF22C7A9),
      FileCategory.video => const Color(0xFFFF5C8A),
      FileCategory.audio => const Color(0xFFFFA63D),
      FileCategory.document => const Color(0xFFFF5A5F),
      FileCategory.apk => const Color(0xFF6CCB5F),
      FileCategory.archive => const Color(0xFFB07CFF),
      FileCategory.code => const Color(0xFF4DA3FF),
      FileCategory.other => const Color(0xFF8A93B8),
    };

String catLabel(FileCategory c) => switch (c) {
      FileCategory.folder => 'Folder',
      FileCategory.image => 'Gambar',
      FileCategory.video => 'Video',
      FileCategory.audio => 'Audio',
      FileCategory.document => 'Dokumen',
      FileCategory.apk => 'Aplikasi',
      FileCategory.archive => 'Arsip',
      FileCategory.code => 'Teks / Kode',
      FileCategory.other => 'Berkas',
    };

IconData catIcon(FileCategory c) => switch (c) {
      FileCategory.folder => Icons.folder_rounded,
      FileCategory.image => Icons.image_rounded,
      FileCategory.video => Icons.play_arrow_rounded,
      FileCategory.audio => Icons.music_note_rounded,
      FileCategory.document => Icons.article_rounded,
      FileCategory.apk => Icons.android_rounded,
      FileCategory.archive => Icons.folder_zip_rounded,
      FileCategory.code => Icons.code_rounded,
      FileCategory.other => Icons.insert_drive_file_rounded,
    };

/// Folder dengan gradien identitas MAB (biru -> ungu).
class FolderGlyph extends StatelessWidget {
  const FolderGlyph({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => Pal.of(context).gradient.createShader(r),
        child: Icon(Icons.folder_rounded, size: size, color: Colors.white),
      );
}

/// Ikon file berwarna per jenis; gambar bisa menampilkan thumbnail ringan.
class FileGlyph extends StatelessWidget {
  const FileGlyph(this.item, {super.key, this.size = 36, this.thumb = false});
  final FileItem item;
  final double size;
  final bool thumb;

  @override
  Widget build(BuildContext context) {
    if (item.isDir) return SizedBox(width: size, height: size, child: FittedBox(child: FolderGlyph(size: size)));
    final c = catColor(item.category);
    final r = size * 0.28;
    Widget inner;
    if (thumb && item.category == FileCategory.image) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Image.file(
          File(item.path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: (size * 2).round(), // decode kecil -> hemat RAM
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _tile(c, r),
        ),
      );
    } else {
      inner = _tile(c, r);
    }
    return SizedBox(width: size, height: size, child: inner);
  }

  Widget _tile(Color c, double r) {
    final ext = p.extension(item.path).replaceFirst('.', '').toUpperCase();
    final showExt = size >= 56 && ext.isNotEmpty && ext.length <= 4;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c, Color.lerp(c, const Color(0xFF3B1E8F), 0.45)!],
        ),
      ),
      child: Center(
        child: showExt
            ? Text(ext,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: size * 0.24))
            : Icon(catIcon(item.category), color: Colors.white, size: size * 0.52),
      ),
    );
  }
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 32});
  final double size;

  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/images/logo.png', width: size, height: size);
}

/// Teks bergradien (dipakai hemat: hanya untuk nama merek).
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => Pal.of(context).gradient.createShader(r),
        child: Text(text, style: (style ?? const TextStyle()).copyWith(color: Colors.white)),
      );
}
