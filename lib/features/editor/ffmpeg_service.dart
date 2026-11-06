import 'dart:convert';
import 'dart:io';

/// Pembungkus FFmpeg (open-source, gratis). Memanggil biner `ffmpeg` yang terpasang
/// di sistem atau path khusus yang diatur pengguna. Didukung di Windows/macOS/Linux.
class FfmpegService {
  FfmpegService([this.customPath = '']);
  final String customPath;

  static bool get supported => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  String get exe => customPath.trim().isNotEmpty ? customPath.trim() : 'ffmpeg';

  Process? _proc;

  Future<bool> available() async {
    try {
      final r = await Process.run(exe, ['-version']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static double _secs(RegExpMatch m) =>
      int.parse(m[1]!) * 3600 + int.parse(m[2]!) * 60 + double.parse(m[3]!);

  /// Menjalankan ffmpeg; [onProgress] menerima 0..1. Mengembalikan (kodeKeluar, ekorLog).
  Future<(int, String)> run(List<String> args, {void Function(double)? onProgress}) async {
    final full = ['-y', '-hide_banner', '-progress', 'pipe:1', '-nostats', ...args];
    final proc = await Process.start(exe, full);
    _proc = proc;
    double total = 0;
    var tail = '';
    final dur = RegExp(r'Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)');
    final cur = RegExp(r'out_time=(\d+):(\d+):(\d+(?:\.\d+)?)');

    proc.stderr.transform(utf8.decoder).listen((s) {
      final m = dur.firstMatch(s);
      if (m != null && total == 0) total = _secs(m);
      tail = (tail + s);
      if (tail.length > 1500) tail = tail.substring(tail.length - 1500);
    });
    proc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((l) {
      final m = cur.firstMatch(l);
      if (m != null && total > 0) onProgress?.call((_secs(m) / total).clamp(0.0, 1.0).toDouble());
    });

    final code = await proc.exitCode;
    _proc = null;
    return (code, tail);
  }

  void cancel() => _proc?.kill();
}
