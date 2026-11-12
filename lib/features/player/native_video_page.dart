import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:video_player_win/video_player_win.dart';

import '../../core/utils/app_log.dart';
import '../viewer/viewers.dart' show openExternally;
import 'media_page.dart';

/// EKSPERIMEN (Windows): pemutar video memakai Windows Media Foundation (akselerasi GPU
/// bawaan Windows, tanpa libmpv). Tujuannya membandingkan beban GPU dengan pemutar mpv.
/// Format yang bisa diputar = format yang bisa diputar Media Player Windows.
class NativeVideoPage extends StatefulWidget {
  const NativeVideoPage({super.key, required this.path, this.playlist = const []});

  final String path;
  final List<String> playlist;

  @override
  State<NativeVideoPage> createState() => _NativeVideoPageState();
}

class _NativeVideoPageState extends State<NativeVideoPage> {
  late final List<String> _list = widget.playlist.isEmpty ? [widget.path] : widget.playlist;
  late int _index = max(0, _list.indexOf(widget.path));
  WinVideoPlayerController? _c;
  Timer? _timer;
  String? _error;
  int _gen = 0;
  double? _dragMs; // posisi sementara saat slider digeser
  double _vol = 1.0;

  // Posisi dibaca tiap 500 ms (bukan tiap event) supaya jendela tidak digambar ulang terus.
  final ValueNotifier<Duration> _pos = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> _playing = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open(_index));
  }

  @override
  void dispose() {
    _gen++;
    _timer?.cancel();
    _c?.dispose();
    _pos.dispose();
    _playing.dispose();
    super.dispose();
  }

  Future<void> _open(int i) async {
    final gen = ++_gen;
    _timer?.cancel();
    final old = _c;
    _c = null;
    old?.dispose();
    if (!mounted) return;
    setState(() {
      _index = i;
      _error = null;
      _dragMs = null;
    });
    _pos.value = Duration.zero;
    final c = WinVideoPlayerController.file(File(_list[i]));
    try {
      await c.initialize();
      if (gen != _gen || !mounted) {
        c.dispose();
        return;
      }
      if (!c.value.isInitialized) throw 'gagal memuat';
      _c = c;
      c.setVolume(_vol);
      await c.play();
      _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
      if (mounted) setState(() {});
    } catch (e) {
      c.dispose();
      if (!mounted || gen != _gen) return;
      // Mis. AV1 tanpa ekstensi codec: mesin Windows gagal, mpv (dav1d) bisa. Beralih otomatis
      // agar pengguna tidak berhenti di halaman galat.
      if (File(_list[i]).existsSync()) {
        AppLog.warn('video', 'Mesin Windows gagal ($e), beralih ke mpv: ${p.basename(_list[i])}');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MediaPage(path: _list[i], playlist: _list)),
        );
        return;
      }
      setState(() => _error = 'Video ini tidak bisa diputar oleh mesin Windows ($e).');
    }
  }

  void _tick() {
    final c = _c;
    if (c == null || !mounted) return;
    final v = c.value;
    _pos.value = v.position;
    _playing.value = v.isPlaying;
    if (v.isCompleted && _index < _list.length - 1) _open(_index + 1);
  }

  void _toggle() {
    final c = _c;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
      _playing.value = false;
    } else {
      c.play();
      _playing.value = true;
    }
  }

  void _seekBy(Duration d) {
    final c = _c;
    if (c == null) return;
    final total = c.value.duration;
    var t = c.value.position + d;
    if (t < Duration.zero) t = Duration.zero;
    if (t > total) t = total;
    c.seekTo(t);
    _pos.value = t;
  }

  String _fmt(Duration d) {
    String t(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    return '${h > 0 ? '$h:' : ''}${t(d.inMinutes % 60)}:${t(d.inSeconds % 60)}';
  }

  Widget _controls(WinVideoPlayerController c) {
    final total = c.value.duration.inMilliseconds.toDouble();
    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(children: [
        IconButton(
          color: Colors.white,
          onPressed: _index > 0 ? () => _open(_index - 1) : null,
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _playing,
          builder: (_, playing, __) => IconButton.filled(
            onPressed: _toggle,
            icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          ),
        ),
        IconButton(
          color: Colors.white,
          onPressed: _index < _list.length - 1 ? () => _open(_index + 1) : null,
          icon: const Icon(Icons.skip_next_rounded),
        ),
        Expanded(
          child: ValueListenableBuilder<Duration>(
            valueListenable: _pos,
            builder: (_, pos, __) {
              final now = _dragMs ?? pos.inMilliseconds.toDouble();
              return Row(children: [
                const SizedBox(width: 8),
                Text(_fmt(Duration(milliseconds: now.round())),
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: total <= 0 ? 0.0 : now.clamp(0.0, total).toDouble(),
                    max: total <= 0 ? 1.0 : total,
                    onChanged: (v) => setState(() => _dragMs = v),
                    onChangeEnd: (v) {
                      final d = Duration(milliseconds: v.round());
                      c.seekTo(d);
                      _pos.value = d;
                      setState(() => _dragMs = null);
                    },
                  ),
                ),
                Text(_fmt(Duration(milliseconds: total.round())),
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(width: 8),
              ]);
            },
          ),
        ),
        Icon(_vol <= 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white70, size: 20),
        SizedBox(
          width: 90,
          child: Slider(
            value: _vol,
            onChanged: (v) {
              setState(() => _vol = v);
              c.setVolume(v);
            },
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _toggle,
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _seekBy(const Duration(seconds: 5)),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _seekBy(const Duration(seconds: -5)),
      },
      child: Focus(autofocus: true, child: _scaffold(c)),
    );
  }

  Widget _scaffold(WinVideoPlayerController? c) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(p.basename(_list[_index]), maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Buka dengan aplikasi default',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => openExternally(_list[_index]),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                    FilledButton.icon(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => MediaPage(path: _list[_index], playlist: _list)),
                      ),
                      icon: const Icon(Icons.play_circle_outline_rounded),
                      label: const Text('Coba dengan pemutar MAB (mpv)'),
                    ),
                    OutlinedButton(
                      onPressed: () => openExternally(_list[_index]),
                      child: const Text('Buka dengan aplikasi default'),
                    ),
                  ]),
                ]),
              ),
            )
          : c == null
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggle,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9,
                          child: WinVideoPlayer(c),
                        ),
                      ),
                    ),
                  ),
                  _controls(c),
                ]),
    );
  }
}
