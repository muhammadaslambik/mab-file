import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../core/notify/notify.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/paths.dart';
import '../file_manager/application/file_manager_state.dart';

class EditParams {
  const EditParams({
    this.turns = 0,
    this.flipH = false,
    this.flipV = false,
    this.crop = 'none',
    this.brightness = 1.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.filter = 'none',
    this.blur = 0.0,
    this.scalePct = 100.0,
  });

  final int turns;
  final bool flipH, flipV;
  final String crop, filter;
  final double brightness, contrast, saturation, blur, scalePct;

  EditParams copyWith({
    int? turns, bool? flipH, bool? flipV, String? crop, String? filter,
    double? brightness, double? contrast, double? saturation, double? blur, double? scalePct,
  }) =>
      EditParams(
        turns: turns ?? this.turns,
        flipH: flipH ?? this.flipH,
        flipV: flipV ?? this.flipV,
        crop: crop ?? this.crop,
        filter: filter ?? this.filter,
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
        blur: blur ?? this.blur,
        scalePct: scalePct ?? this.scalePct,
      );
}

/// Seluruh pipeline edit gambar (pure Dart, jalan di Isolate, semua platform).
Uint8List applyEdits(Uint8List src, EditParams e,
    {required String format, int quality = 90, int? maxSide}) {
  var im = img.decodeImage(src);
  if (im == null) throw 'Format gambar tidak didukung untuk diedit';
  if (maxSide != null && max(im.width, im.height) > maxSide) {
    im = im.width >= im.height
        ? img.copyResize(im, width: maxSide)
        : img.copyResize(im, height: maxSide);
  }
  final t = ((e.turns % 4) + 4) % 4;
  if (t != 0) im = img.copyRotate(im, angle: 90.0 * t);
  if (e.flipH) im = img.flip(im, direction: img.FlipDirection.horizontal);
  if (e.flipV) im = img.flip(im, direction: img.FlipDirection.vertical);

  if (e.crop != 'none') {
    final parts = e.crop.split(':');
    final r = double.parse(parts[0]) / double.parse(parts[1]);
    var w = im.width, h = (im.width / r).round();
    if (h > im.height) {
      h = im.height;
      w = (im.height * r).round();
    }
    im = img.copyCrop(im, x: (im.width - w) ~/ 2, y: (im.height - h) ~/ 2, width: w, height: h);
  }

  if (e.brightness != 1 || e.contrast != 1 || e.saturation != 1) {
    im = img.adjustColor(im, brightness: e.brightness, contrast: e.contrast, saturation: e.saturation);
  }
  switch (e.filter) {
    case 'mono':
      im = img.grayscale(im);
    case 'sepia':
      im = img.sepia(im);
    case 'invert':
      im = img.invert(im);
  }
  if (e.blur > 0) im = img.gaussianBlur(im, radius: e.blur.round());
  if (maxSide == null && e.scalePct != 100) {
    im = img.copyResize(im, width: max(1, (im.width * e.scalePct / 100).round()));
  }

  final List<int> out = switch (format) {
    'jpg' => img.encodeJpg(im, quality: quality),
    'gif' => img.encodeGif(im),
    'bmp' => img.encodeBmp(im),
    'tiff' => img.encodeTiff(im),
    'ico' => img.encodeIco(max(im.width, im.height) > 256 ? img.copyResize(im, width: 256) : im),
    _ => img.encodePng(im),
  };
  return Uint8List.fromList(out);
}

class ImageEditorPage extends ConsumerStatefulWidget {
  const ImageEditorPage({super.key, required this.path});
  final String path;

  @override
  ConsumerState<ImageEditorPage> createState() => _ImageEditorPageState();
}

class _ImageEditorPageState extends ConsumerState<ImageEditorPage> {
  Uint8List? _orig, _small, _preview;
  EditParams _e = const EditParams();
  String _format = 'png';
  double _quality = 90;
  Timer? _debounce;
  int _ver = 0;
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    final ext = p.extension(widget.path).toLowerCase().replaceFirst('.', '');
    _format = const {'jpg', 'jpeg'}.contains(ext) ? 'jpg' : (const {'gif', 'bmp', 'tiff', 'ico'}.contains(ext) ? ext : 'png');
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final path = widget.path;
      final bytes = await File(path).readAsBytes();
      final small = await Isolate.run(() => applyEdits(bytes, const EditParams(), format: 'png', maxSide: 1200));
      if (!mounted) return;
      setState(() {
        _orig = bytes;
        _small = small;
        _preview = small;
      });
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  void _set(EditParams e) {
    setState(() => _e = e);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 140), _render);
  }

  Future<void> _render() async {
    final small = _small;
    if (small == null) return;
    final v = ++_ver;
    final e = _e;
    try {
      final out = await Isolate.run(() => applyEdits(small, e, format: 'jpg', quality: 85, maxSide: 1200));
      if (mounted && v == _ver) setState(() => _preview = out);
    } catch (_) {}
  }

  Future<void> _save({required bool overwrite}) async {
    final orig = _orig;
    if (orig == null) return;
    setState(() => _busy = true);
    try {
      final e = _e, f = _format, q = _quality.round();
      final out = await Isolate.run(() => applyEdits(orig, e, format: f, quality: q));
      final dir = p.dirname(widget.path);
      final base = p.basenameWithoutExtension(widget.path);
      final target = overwrite && p.extension(widget.path).toLowerCase() == '.$f'
          ? widget.path
          : uniquePath(p.join(dir, overwrite ? '$base.$f' : '${base}_edit.$f'));
      await File(target).writeAsBytes(out);
      ref.read(notifsProvider.notifier).push('Gambar disimpan', body: p.basename(target), kind: NoteKind.success);
      await ref.read(fmProvider.notifier).refresh();
    } catch (e) {
      ref.read(notifsProvider.notifier).push('Gagal menyimpan', body: '$e', kind: NoteKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------- UI ---
  Widget _slider(String label, double v, double min, double max, ValueChanged<double> on, {String? suffix}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            Text(label, style: const TextStyle(fontSize: 12.5)),
            const Spacer(),
            Text('${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}${suffix ?? ''}',
                style: TextStyle(fontSize: 12, color: Pal.of(context).muted)),
          ]),
        ),
        Slider(value: v.clamp(min, max).toDouble(), min: min, max: max, onChanged: on),
      ]);

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(t, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Pal.of(context).muted)),
      );

  Widget _panel() {
    final pal = Pal.of(context);
    Widget chip(String label, bool sel, VoidCallback on) => ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          selected: sel,
          showCheckmark: false,
          side: BorderSide(color: pal.border),
          onSelected: (_) => on(),
        );
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 20), children: [
      _title('TRANSFORMASI'),
      Wrap(spacing: 6, children: [
        IconButton.outlined(tooltip: 'Putar kiri', onPressed: () => _set(_e.copyWith(turns: _e.turns - 1)), icon: const Icon(Icons.rotate_left_rounded)),
        IconButton.outlined(tooltip: 'Putar kanan', onPressed: () => _set(_e.copyWith(turns: _e.turns + 1)), icon: const Icon(Icons.rotate_right_rounded)),
        IconButton.outlined(tooltip: 'Balik horizontal', onPressed: () => _set(_e.copyWith(flipH: !_e.flipH)), icon: const Icon(Icons.flip_rounded)),
        IconButton.outlined(tooltip: 'Balik vertikal', onPressed: () => _set(_e.copyWith(flipV: !_e.flipV)), icon: const Icon(Icons.swap_vert_rounded)),
      ]),
      _title('POTONG (tengah)'),
      Wrap(spacing: 6, runSpacing: 4, children: [
        for (final c in const ['none', '1:1', '4:3', '3:4', '16:9', '9:16'])
          chip(c == 'none' ? 'Asli' : c, _e.crop == c, () => _set(_e.copyWith(crop: c))),
      ]),
      _title('PENYESUAIAN'),
      _slider('Kecerahan', _e.brightness, 0.5, 1.5, (v) => _set(_e.copyWith(brightness: v))),
      _slider('Kontras', _e.contrast, 0.5, 1.5, (v) => _set(_e.copyWith(contrast: v))),
      _slider('Saturasi', _e.saturation, 0, 2, (v) => _set(_e.copyWith(saturation: v))),
      _slider('Blur', _e.blur, 0, 10, (v) => _set(_e.copyWith(blur: v))),
      _title('FILTER'),
      Wrap(spacing: 6, children: [
        for (final f in const [('none', 'Normal'), ('mono', 'Hitam putih'), ('sepia', 'Sepia'), ('invert', 'Negatif')])
          chip(f.$2, _e.filter == f.$1, () => _set(_e.copyWith(filter: f.$1))),
      ]),
      _title('EKSPOR'),
      Row(children: [
        const Text('Format', style: TextStyle(fontSize: 12.5)),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: _format,
          underline: const SizedBox.shrink(),
          items: [for (final f in const ['png', 'jpg', 'gif', 'bmp', 'tiff', 'ico']) DropdownMenuItem(value: f, child: Text(f.toUpperCase()))],
          onChanged: (v) => setState(() => _format = v ?? 'png'),
        ),
      ]),
      if (_format == 'jpg') _slider('Kualitas JPG', _quality, 30, 100, (v) => setState(() => _quality = v)),
      _slider('Skala ukuran', _e.scalePct, 10, 200, (v) => setState(() => _e = _e.copyWith(scalePct: v)), suffix: '%'),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _set(const EditParams()),
            child: const Text('Reset'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: _busy ? null : () => _save(overwrite: false),
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_alt_rounded, size: 18),
            label: const Text('Simpan salinan'),
          ),
        ),
      ]),
      TextButton(
        onPressed: _busy
            ? null
            : () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Timpa file asli?'),
                    content: const Text('Perubahan akan menggantikan gambar asli dan tidak bisa dibatalkan.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Timpa')),
                    ],
                  ),
                );
                if (ok == true) _save(overwrite: true);
              },
        child: const Text('Simpan (timpa asli)'),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final canvas = Container(
      color: pal.side,
      child: _err != null
          ? Center(child: Text(_err!))
          : _preview == null
              ? const Center(child: CircularProgressIndicator())
              : InteractiveViewer(
                  maxScale: 8,
                  child: Center(child: Image.memory(_preview!, gaplessPlayback: true)),
                ),
    );
    return Scaffold(
      appBar: AppBar(title: Text('Edit • ${p.basename(widget.path)}', style: const TextStyle(fontSize: 15))),
      body: LayoutBuilder(builder: (ctx, cs) {
        if (cs.maxWidth >= 760) {
          return Row(children: [
            Expanded(child: canvas),
            Container(
              width: 320,
              decoration: BoxDecoration(color: pal.card, border: Border(left: BorderSide(color: pal.border))),
              child: _panel(),
            ),
          ]);
        }
        return Column(children: [
          Expanded(flex: 5, child: canvas),
          Expanded(flex: 6, child: Container(color: pal.card, child: _panel())),
        ]);
      }),
    );
  }
}
