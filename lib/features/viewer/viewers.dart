import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;

class ImageViewerPage extends StatelessWidget {
  const ImageViewerPage({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(p.basename(path))),
        body: InteractiveViewer(
          maxScale: 8,
          child: Center(child: Image.file(File(path), errorBuilder: (_, e, __) => Text('$e'))),
        ),
      );
}

class MediaPage extends StatefulWidget {
  const MediaPage({super.key, required this.path});
  final String path;
  @override
  State<MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<MediaPage> {
  late final player = Player();
  late final controller = VideoController(player);

  @override
  void initState() {
    super.initState();
    player.open(Media(widget.path));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(p.basename(widget.path))),
        body: Video(controller: controller),
      );
}

class TextEditorPage extends StatefulWidget {
  const TextEditorPage({super.key, required this.path});
  final String path;
  @override
  State<TextEditorPage> createState() => _TextEditorPageState();
}

class _TextEditorPageState extends State<TextEditorPage> {
  final _c = TextEditingController();
  bool _loaded = false, _dirty = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    try {
      final f = File(widget.path);
      if (await f.length() > 2 * 1024 * 1024) throw 'File > 2 MB, tidak dibuka di editor';
      _c.text = await f.readAsString();
      setState(() => _loaded = true);
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  Future<void> _save() async {
    await File(widget.path).writeAsString(_c.text);
    setState(() => _dirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tersimpan')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('${p.basename(widget.path)}${_dirty ? ' •' : ''}'),
          actions: [IconButton(icon: const Icon(Icons.save), onPressed: _dirty ? _save : null)],
        ),
        body: _err != null
            ? Center(child: Text(_err!))
            : !_loaded
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _c,
                      maxLines: null,
                      expands: true,
                      onChanged: (_) => setState(() => _dirty = true),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.4),
                      decoration: const InputDecoration(border: InputBorder.none),
                    ),
                  ),
      );
}
