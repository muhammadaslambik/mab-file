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
      body = Image.file(
        File(path),
        key: ValueKey(path),
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _FallbackImage(path: path),
      );
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
            child: InteractiveViewer(maxScale: 10, child: Center(child: body)),
          ),
        ),
      ),
    );
  }
}

class _FallbackImage extends StatelessWidget {
  const _FallbackImage({required this.path});
  final String path;

  static Uint8List? _decode(String path) {
    final d = img.decodeImage(File(path).readAsBytesSync());
    return d == null ? null : Uint8List.fromList(img.encodePng(d));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
        future: Isolate.run(() => _decode(path)),
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const CircularProgressIndicator();
          }
          final b = snap.data;
          if (b != null) return Image.memory(b);
          return Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.broken_image_outlined, size: 56),
            const SizedBox(height: 12),
            const Text('Format ini belum bisa ditampilkan di dalam aplikasi'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => openExternally(path),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Buka dengan aplikasi default'),
            ),
          ]);
        },
      );
}
