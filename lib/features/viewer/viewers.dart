import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_theme.dart';
import '../editor/image_editor_page.dart';
import '../editor/media_studio_page.dart';

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

// ------------------------------------------------------------------ MEDIA ---
/// Pemutar audio/video semua format (libmpv via media_kit) dengan playlist folder.
class MediaPage extends StatefulWidget {
  const MediaPage({super.key, required this.path, this.playlist = const [], this.audio = false});
  final String path;
  final List<String> playlist;
  final bool audio;

  @override
  State<MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<MediaPage> {
  late final Player player = Player();
  late final VideoController controller = VideoController(player);
  int _index = 0;
  late final List<String> _list;

  @override
  void initState() {
    super.initState();
    _list = widget.playlist.isEmpty ? [widget.path] : widget.playlist;
    _index = _list.indexOf(widget.path).clamp(0, _list.length - 1).toInt();
    player.open(Playlist([for (final f in _list) Media(f)], index: _index));
    player.stream.playlist.listen((pl) {
      if (mounted && pl.index != _index) setState(() => _index = pl.index);
    });
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    String t(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    return '${h > 0 ? '$h:' : ''}${t(d.inMinutes % 60)}:${t(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final cur = _list[_index];
    final pal = Pal.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(cur), style: const TextStyle(fontSize: 15)),
        actions: [
          IconButton(
            tooltip: 'Studio Media: konversi / potong / kompres',
            icon: const Icon(Icons.auto_fix_high_rounded),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => MediaStudioPage(path: cur))),
          ),
          IconButton(
            tooltip: 'Buka dengan aplikasi default',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => openExternally(cur),
          ),
        ],
      ),
      body: widget.audio ? _audioUi(pal, cur) : Video(controller: controller),
    );
  }

  Widget _audioUi(Pal pal, String cur) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  gradient: pal.gradient,
                  borderRadius: BorderRadius.circular(36),
                ),
                child: const Icon(Icons.music_note_rounded, size: 96, color: Colors.white),
              ),
              const SizedBox(height: 22),
              Text(p.basenameWithoutExtension(cur),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              if (_list.length > 1)
                Text('${_index + 1} dari ${_list.length}', style: TextStyle(color: pal.muted)),
              const SizedBox(height: 14),
              StreamBuilder<Duration>(
                stream: player.stream.position,
                builder: (_, pos) => StreamBuilder<Duration>(
                  stream: player.stream.duration,
                  builder: (_, dur) {
                    final total = (dur.data ?? player.state.duration).inMilliseconds.toDouble();
                    final now = (pos.data ?? player.state.position).inMilliseconds.toDouble();
                    return Column(children: [
                      Slider(
                        value: total <= 0 ? 0.0 : now.clamp(0.0, total).toDouble(),
                        max: total <= 0 ? 1 : total,
                        onChanged: (v) => player.seek(Duration(milliseconds: v.round())),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(_fmt(Duration(milliseconds: now.round())), style: TextStyle(color: pal.muted, fontSize: 12)),
                          Text(_fmt(Duration(milliseconds: total.round())), style: TextStyle(color: pal.muted, fontSize: 12)),
                        ]),
                      ),
                    ]);
                  },
                ),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(iconSize: 32, onPressed: player.previous, icon: const Icon(Icons.skip_previous_rounded)),
                const SizedBox(width: 8),
                StreamBuilder<bool>(
                  stream: player.stream.playing,
                  builder: (_, s) => Container(
                    decoration: BoxDecoration(gradient: pal.gradient, shape: BoxShape.circle),
                    child: IconButton(
                      iconSize: 40,
                      color: Colors.white,
                      onPressed: player.playOrPause,
                      icon: Icon((s.data ?? player.state.playing) ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(iconSize: 32, onPressed: player.next, icon: const Icon(Icons.skip_next_rounded)),
              ]),
              const SizedBox(height: 8),
              StreamBuilder<double>(
                stream: player.stream.volume,
                builder: (_, v) => Row(children: [
                  const Icon(Icons.volume_down_rounded, size: 20),
                  Expanded(
                    child: Slider(
                      value: (v.data ?? player.state.volume).clamp(0.0, 100.0).toDouble(),
                      max: 100,
                      onChanged: player.setVolume,
                    ),
                  ),
                  const Icon(Icons.volume_up_rounded, size: 20),
                ]),
              ),
            ]),
          ),
        ),
      );
}
