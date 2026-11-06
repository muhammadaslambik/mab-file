
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/notify/notify.dart';
import '../../core/settings/settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/paths.dart';
import '../file_manager/application/file_manager_state.dart';
import '../file_manager/domain/file_item.dart';
import '../viewer/viewers.dart';
import 'ffmpeg_service.dart';

enum StudioOp { convert, extractAudio, trim, compress, mute, volume }

const _videoFmts = ['mp4', 'mkv', 'webm', 'avi', 'mov', 'gif'];
const _audioFmts = ['mp3', 'm4a', 'wav', 'flac', 'ogg', 'opus'];

/// Studio Media: konversi format, ekstrak audio (video -> MP3 dll), potong, kompres, bisukan, volume.
class MediaStudioPage extends ConsumerStatefulWidget {
  const MediaStudioPage({super.key, required this.path});
  final String path;

  @override
  ConsumerState<MediaStudioPage> createState() => _MediaStudioPageState();
}

class _MediaStudioPageState extends ConsumerState<MediaStudioPage> {
  late final bool _video = categoryOf(widget.path) == FileCategory.video;
  late final List<StudioOp> _ops = _video
      ? StudioOp.values
      : [StudioOp.convert, StudioOp.trim, StudioOp.volume];
  late StudioOp _op = _video ? StudioOp.extractAudio : StudioOp.convert;
  late String _fmt = _video ? 'mp3' : 'mp3';

  final _start = TextEditingController(text: '00:00:00');
  final _end = TextEditingController(text: '00:00:30');
  bool _fast = true;
  double _crf = 26;
  String _height = 'asli';
  double _vol = 1.5;

  bool? _ready;
  bool _running = false;
  double? _progress;
  String _log = '';
  String? _result;
  late final FfmpegService _ff = FfmpegService(ref.read(settingsProvider).ffmpegPath);
  final _pathCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _pathCtl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (!FfmpegService.supported) {
      setState(() => _ready = false);
      return;
    }
    final ok = await FfmpegService(ref.read(settingsProvider).ffmpegPath).available();
    if (mounted) setState(() => _ready = ok);
  }

  String get _srcExt => p.extension(widget.path).replaceFirst('.', '').toLowerCase();

  List<String> get _formats => switch (_op) {
        StudioOp.convert => _video ? _videoFmts : _audioFmts,
        StudioOp.extractAudio => _audioFmts,
        _ => const [],
      };

  String _outExt() => _formats.isNotEmpty ? _fmt : _srcExt;

  List<String> _audioCodec(String f) => switch (f) {
        'mp3' => ['-c:a', 'libmp3lame', '-b:a', '192k'],
        'm4a' || 'aac' => ['-c:a', 'aac', '-b:a', '192k'],
        'wav' => ['-c:a', 'pcm_s16le'],
        'flac' => ['-c:a', 'flac'],
        'ogg' => ['-c:a', 'libvorbis', '-q:a', '5'],
        'opus' => ['-c:a', 'libopus', '-b:a', '128k'],
        _ => const [],
      };

  List<String> _args(String input, String output) {
    switch (_op) {
      case StudioOp.convert:
        if (!_video) return ['-i', input, '-vn', ..._audioCodec(_fmt), output];
        if (_fmt == 'gif') return ['-i', input, '-vf', 'fps=12,scale=480:-1:flags=lanczos', '-an', output];
        return ['-i', input, output];
      case StudioOp.extractAudio:
        return ['-i', input, '-vn', ..._audioCodec(_fmt), output];
      case StudioOp.trim:
        return [
          '-ss', _start.text.trim(), '-to', _end.text.trim(), '-i', input,
          if (_fast) ...['-c', 'copy'],
          output,
        ];
      case StudioOp.compress:
        return [
          '-i', input, '-c:v', 'libx264', '-crf', _crf.round().toString(), '-preset', 'veryfast',
          if (_height != 'asli') ...['-vf', 'scale=-2:$_height'],
          '-c:a', 'aac', '-b:a', '128k', output,
        ];
      case StudioOp.mute:
        return ['-i', input, '-an', '-c:v', 'copy', output];
      case StudioOp.volume:
        return [
          '-i', input, '-filter:a', 'volume=${_vol.toStringAsFixed(2)}',
          if (_video) ...['-c:v', 'copy'],
          output,
        ];
    }
  }

  String _suffix() => switch (_op) {
        StudioOp.convert => 'konversi',
        StudioOp.extractAudio => 'audio',
        StudioOp.trim => 'potong',
        StudioOp.compress => 'kompres',
        StudioOp.mute => 'bisu',
        StudioOp.volume => 'volume',
      };

  Future<void> _start_() async {
    final dir = p.dirname(widget.path);
    final base = p.basenameWithoutExtension(widget.path);
    final out = uniquePath(p.join(dir, '${base}_${_suffix()}.${_outExt()}'));
    setState(() {
      _running = true;
      _progress = 0;
      _log = '';
      _result = null;
    });
    try {
      final (code, tail) = await _ff.run(_args(widget.path, out), onProgress: (v) {
        if (mounted) setState(() => _progress = v);
      });
      if (!mounted) return;
      if (code == 0) {
        setState(() => _result = out);
        ref.read(notifsProvider.notifier).push('Selesai', body: p.basename(out), kind: NoteKind.success);
        ref.read(fmProvider.notifier).refresh();
      } else {
        setState(() => _log = tail);
        ref.read(notifsProvider.notifier).push('FFmpeg gagal', body: 'kode $code', kind: NoteKind.error);
      }
    } catch (e) {
      if (mounted) setState(() => _log = '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  String _label(StudioOp o) => switch (o) {
        StudioOp.convert => 'Konversi format',
        StudioOp.extractAudio => 'Ambil audio (video → MP3, dll)',
        StudioOp.trim => 'Potong',
        StudioOp.compress => 'Kompres video',
        StudioOp.mute => 'Hapus suara',
        StudioOp.volume => 'Ubah volume',
      };

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Studio Media • ${p.basename(widget.path)}', style: const TextStyle(fontSize: 15))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _ready == null
              ? const CircularProgressIndicator()
              : _ready == false
                  ? _notReady(pal)
                  : _form(pal),
        ),
      ),
    );
  }

  Widget _notReady(Pal pal) => ListView(padding: const EdgeInsets.all(24), children: [
        const Icon(Icons.movie_filter_rounded, size: 56),
        const SizedBox(height: 12),
        if (!FfmpegService.supported)
          const Text(
            'Konversi & edit media memakai FFmpeg dan saat ini tersedia di Windows, macOS, dan Linux. '
            'Dukungan Android/iOS direncanakan di tahap berikutnya.',
            style: TextStyle(height: 1.5),
          )
        else ...[
          const Text('FFmpeg belum ditemukan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('FFmpeg gratis & open-source. Pasang sekali, lalu tekan "Cek ulang":',
              style: TextStyle(height: 1.5)),
          const SizedBox(height: 12),
          _cmd('Windows', 'winget install Gyan.FFmpeg', pal),
          _cmd('macOS', 'brew install ffmpeg', pal),
          _cmd('Linux', 'sudo apt install ffmpeg', pal),
          const SizedBox(height: 8),
          Text('Setelah pemasangan di Windows, tutup & buka ulang aplikasi ini agar PATH terbaca.',
              style: TextStyle(color: pal.muted, fontSize: 12.5)),
          const SizedBox(height: 16),
          TextField(
            controller: _pathCtl,
            decoration: const InputDecoration(
              labelText: 'Atau isi lokasi ffmpeg.exe secara manual',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              final s = ref.read(settingsProvider);
              ref.read(settingsProvider.notifier).update(s.copyWith(ffmpegPath: _pathCtl.text.trim()));
              final ok = await FfmpegService(_pathCtl.text.trim()).available();
              if (mounted) setState(() => _ready = ok);
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Cek ulang'),
          ),
        ],
      ]);

  Widget _cmd(String os, String c, Pal pal) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: pal.side, borderRadius: BorderRadius.circular(10), border: Border.all(color: pal.border)),
        child: Row(children: [
          SizedBox(width: 70, child: Text(os, style: TextStyle(color: pal.muted))),
          Expanded(child: SelectableText(c, style: const TextStyle(fontFamily: 'monospace'))),
        ]),
      );

  Widget _form(Pal pal) {
    Widget chips<T>(List<T> items, T sel, String Function(T) label, ValueChanged<T> on) => Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final i in items)
              ChoiceChip(
                label: Text(label(i)),
                selected: i == sel,
                showCheckmark: false,
                side: BorderSide(color: pal.border),
                onSelected: _running ? null : (_) => on(i),
              ),
          ],
        );

    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Operasi', style: TextStyle(color: pal.muted, fontWeight: FontWeight.w600, fontSize: 12.5)),
      const SizedBox(height: 8),
      chips<StudioOp>(_ops, _op, _label, (o) {
        setState(() {
          _op = o;
          if (_formats.isNotEmpty && !_formats.contains(_fmt)) _fmt = _formats.first;
        });
      }),
      const SizedBox(height: 18),
      if (_formats.isNotEmpty) ...[
        Text('Format hasil', style: TextStyle(color: pal.muted, fontWeight: FontWeight.w600, fontSize: 12.5)),
        const SizedBox(height: 8),
        chips<String>(_formats, _fmt, (s) => s.toUpperCase(), (f) => setState(() => _fmt = f)),
      ],
      if (_op == StudioOp.trim) ...[
        Row(children: [
          Expanded(child: TextField(controller: _start, decoration: const InputDecoration(labelText: 'Mulai (jj:mm:dd)', border: OutlineInputBorder()))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _end, decoration: const InputDecoration(labelText: 'Selesai (jj:mm:dd)', border: OutlineInputBorder()))),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Cepat (tanpa re-encode)'),
          subtitle: const Text('Sangat cepat; titik potong mengikuti keyframe terdekat'),
          value: _fast,
          onChanged: _running ? null : (v) => setState(() => _fast = v),
        ),
      ],
      if (_op == StudioOp.compress) ...[
        Text('Kualitas (CRF ${_crf.round()}) — makin kecil makin bagus & besar', style: const TextStyle(fontSize: 12.5)),
        Slider(value: _crf, min: 18, max: 34, divisions: 16, onChanged: _running ? null : (v) => setState(() => _crf = v)),
        chips<String>(const ['asli', '1080', '720', '480', '360'], _height, (s) => s == 'asli' ? 'Resolusi asli' : '${s}p', (h) => setState(() => _height = h)),
      ],
      if (_op == StudioOp.volume) ...[
        Text('Volume ×${_vol.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5)),
        Slider(value: _vol, min: 0.2, max: 3, onChanged: _running ? null : (v) => setState(() => _vol = v)),
      ],
      const SizedBox(height: 22),
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _running ? null : _start_,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Mulai'),
          ),
        ),
        if (_running) ...[
          const SizedBox(width: 10),
          OutlinedButton(onPressed: _ff.cancel, child: const Text('Batal')),
        ],
      ]),
      if (_running) ...[
        const SizedBox(height: 16),
        LinearProgressIndicator(value: (_progress ?? 0) <= 0 ? null : _progress),
        const SizedBox(height: 6),
        Text(_progress == null ? 'Memproses…' : '${((_progress ?? 0) * 100).round()}%', style: TextStyle(color: pal.muted)),
      ],
      if (_result != null) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: pal.select, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399)),
            const SizedBox(width: 10),
            Expanded(child: Text(p.basename(_result!), overflow: TextOverflow.ellipsis)),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MediaPage(
                    path: _result!,
                    audio: categoryOf(_result!) == FileCategory.audio,
                  ),
                ),
              ),
              child: const Text('Putar'),
            ),
          ]),
        ),
      ],
      if (_log.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: pal.side, borderRadius: BorderRadius.circular(12)),
          child: SelectableText(_log, style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5)),
        ),
      ],
    ]);
  }
}
