import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_theme.dart';
import '../editor/image_editor_page.dart';

Future<void> openExternally(String path) async {
  await OpenFilex.open(path);
}

// ------------------------------------------------------------------ IMAGE ---
/// Viewer gambar: Flutter native (jpg/png/gif/webp/bmp), SVG (flutter_svg),
/// format lain (tiff, ico, tga, psd, ...) didekode lewat paket `image`.
class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({super.key, required this.path, this.siblings = const []});
  final String path;
  final List<String> siblings;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late int _i;
  late final List<String> _list;

  @override
  void initState() {
    super.initState();
    _list = widget.siblings.isEmpty ? [widget.path] : widget.siblings;
    _i = _list.indexOf(widget.path).clamp(0, _list.length - 1).toInt();
  }

  void _go(int d) {
    if (_list.length < 2) return;
    setState(() => _i = (_i + d) % _list.length);
  }

  @override
  Widget build(BuildContext context) {
    final path = _list[_i];
    final ext = p.extension(path).toLowerCase();
    final pal = Pal.of(context);

    Widget body;
    if (ext == '.svg') {
      body = SvgPicture.file(File(path), fit: BoxFit.contain);
    } else {
      body = _ImageBody(key: ValueKey(path), path: path);
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.maybePop(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text('${p.basename(path)}${_list.length > 1 ? '   (${_i + 1}/${_list.length})' : ''}',
                style: const TextStyle(fontSize: 15)),
            actions: [
              if (_list.length > 1) ...[
                IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _go(-1)),
                IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: () => _go(1)),
              ],
              if (ext != '.svg')
                IconButton(
                  tooltip: 'Edit gambar',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => ImageEditorPage(path: path))),
                ),
              IconButton(
                tooltip: 'Buka dengan aplikasi default',
                icon: const Icon(Icons.open_in_new_rounded),
                onPressed: () => openExternally(path),
              ),
            ],
          ),
          body: Container(
            color: pal.side,
            child: InteractiveViewer(maxScale: 6, child: Center(child: body)),
          ),
        ),
      ),
    );
  }
}

/// Gambar dekode-terbatas: dikecilkan ke ukuran layar saat dibaca (bukan resolusi penuh),
/// sehingga foto 12-50 MP tidak memakan ratusan MB RAM/GPU.
class _ImageBody extends StatefulWidget {
  const _ImageBody({super.key, required this.path});
  final String path;

  @override
  State<_ImageBody> createState() => _ImageBodyState();
}

class _ImageBodyState extends State<_ImageBody> {
  static const _native = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.wbmp'};
  ImageProvider? _provider;
  int _retry = 0;
  bool _useFallback = false;

  @override
  void dispose() {
    _provider?.evict(); // lepaskan gambar besar dari cache
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = p.extension(widget.path).toLowerCase();
    if (_useFallback || !_native.contains(ext)) return _FallbackImage(path: widget.path);
    final mq = MediaQuery.of(context);
    final dpr = mq.devicePixelRatio;
    final w = (mq.size.width * dpr).clamp(256.0, 2560.0).round();
    final h = (mq.size.height * dpr).clamp(256.0, 1600.0).round();
    final provider = _provider = ResizeImage(
      FileImage(File(widget.path)),
      width: w,
      height: h,
      policy: ResizeImagePolicy.fit,
    );
    return Image(
      key: ValueKey(_retry),
      image: provider,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.broken_image_outlined, size: 56),
        const SizedBox(height: 12),
        const Text('Gambar gagal dimuat'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          FilledButton.icon(
            onPressed: () {
              provider.evict();
              setState(() => _retry++);
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba lagi'),
          ),
          OutlinedButton(
            onPressed: () => setState(() => _useFallback = true),
            child: const Text('Dekode alternatif'),
          ),
          OutlinedButton(
            onPressed: () => openExternally(widget.path),
            child: const Text('Buka dengan aplikasi default'),
          ),
        ]),
      ]),
    );
  }
}

/// Dekode lewat paket `image` (tiff/ico/tga/psd, atau jpg yang tak bisa didekode native).
/// Hasil dikecilkan maks 2048 px dan Future dibuat SEKALI (bukan tiap build).
class _FallbackImage extends StatefulWidget {
  const _FallbackImage({required this.path});
  final String path;

  @override
  State<_FallbackImage> createState() => _FallbackImageState();
}

class _FallbackImageState extends State<_FallbackImage> {
  late final Future<Uint8List?> _f = Isolate.run(() => _decode(widget.path));

  static Uint8List? _decode(String path) {
    final f = File(path);
    if (f.lengthSync() > 40 << 20) return null; // terlalu besar untuk dekode di Dart murni
    var d = img.decodeImage(f.readAsBytesSync());
    if (d == null) return null;
    const maxSide = 2048;
    if (d.width > maxSide || d.height > maxSide) {
      d = d.width >= d.height
          ? img.copyResize(d, width: maxSide)
          : img.copyResize(d, height: maxSide);
    }
    return Uint8List.fromList(img.encodePng(d, level: 1));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
        future: _f,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const CircularProgressIndicator();
          }
          final b = snap.data;
          if (b != null) return Image.memory(b, gaplessPlayback: true);
          return Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.broken_image_outlined, size: 56),
            const SizedBox(height: 12),
            const Text('Format ini belum bisa ditampilkan di dalam aplikasi'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => openExternally(widget.path),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Buka dengan aplikasi default'),
            ),
          ]);
        },
      );
}
