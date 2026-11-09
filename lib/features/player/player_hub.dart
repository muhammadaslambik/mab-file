import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/settings/settings.dart';
import '../../core/utils/app_log.dart';
import '../file_manager/domain/file_item.dart';

/// Satu pemutar global (media_kit/libmpv) yang hidup selama aplikasi berjalan.
/// Karena pemiliknya bukan halaman, musik/video TETAP berputar saat Anda
/// berpindah folder atau menutup halaman pemutar (dikontrol lewat MiniPlayer).
/// libmpv baru dimuat saat pertama kali dipakai -> startup & memori tetap ringan.
class PlayerHub extends ChangeNotifier {
  Player? _player;
  VideoController? _video;
  bool _disposed = false;

  bool shuffle = false;
  bool _videoVisible = false;

  /// Posisi putar yang DIBATASI (maks ~2,5 kali/detik). Event posisi mpv jauh lebih sering;
  /// tiap event yang membangun ulang widget = satu frame penuh jendela Flutter di GPU.
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final List<StreamSubscription<dynamic>> _subs = [];

  /// Matikan dekode video saat halaman pemutar ditutup (hemat CPU/GPU). DIMATIKAN secara
  /// default karena menyalakan trek video lagi bisa membuat gambar hitam/pecah di Windows.
  static const bool _pauseVideoWhenHidden = false;
  PlaylistMode mode = PlaylistMode.none;

  /// Mode dekode video mpv dari pengaturan ('default' = bawaan media_kit). Eksperimen untuk
  /// menurunkan beban GPU/CPU; hasil nyata dicatat ke log lewat [_logDecode].
  String hwdec = 'default';
  bool _hwdecTouched = false;
  Timer? _logTimer;

  Player get player => _player ??= _create();
  VideoController get video {
    final created = _video == null;
    final v = _video ??= VideoController(player);
    if (created) {
      // VideoController menetapkan hwdec-nya sendiri saat dibuat; terapkan pilihan kita sesudahnya.
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        final pl = _player;
        if (pl != null) _applyHwdec(pl);
      });
    }
    return v;
  }

  Player _create() {
    final pl = Player();
    // Profil mpv 'fast': penskalaan bilinear, tanpa dither/deband -> beban render (3D engine)
    // lebih ringan. Dibungkus try/catch: kalau gagal, pemutaran tetap jalan seperti biasa.
    () async {
      try {
        await (pl.platform as dynamic).setProperty('profile', 'fast');
      } catch (_) {}
      await _applyHwdec(pl);
    }();
    _subs.add(pl.stream.playlist.listen((_) {
      if (!_disposed) notifyListeners();
    }));
    _subs.add(pl.stream.videoParams.listen((_) => _scheduleDecodeLog(pl)));
    var lastMs = -1000000;
    _subs.add(pl.stream.position.listen((pos) {
      if (_disposed) return;
      final ms = pos.inMilliseconds;
      if ((ms - lastMs).abs() < 400) return;
      lastMs = ms;
      position.value = pos;
    }));
    return pl;
  }

  bool get hasQueue => _player != null && _player!.state.playlist.medias.isNotEmpty;

  List<String> get queue => _player == null
      ? const []
      : [for (final m in _player!.state.playlist.medias) m.uri];

  int get index => _player?.state.playlist.index ?? 0;

  String? get current {
    final q = queue;
    final i = index;
    return (i >= 0 && i < q.length) ? q[i] : null;
  }

  bool get currentIsVideo {
    final c = current;
    return c != null && categoryOf(c) == FileCategory.video;
  }

  Future<void> playAll(List<String> paths, {int start = 0}) async {
    if (paths.isEmpty) return;
    final i = start.clamp(0, paths.length - 1).toInt();
    await _applyHwdec(player);
    await player.open(Playlist([for (final f in paths) Media(f)], index: i));
    _applyVideoTrack();
    notifyListeners();
  }

  void setHwdec(String v) {
    hwdec = v;
    final pl = _player;
    if (pl != null) _applyHwdec(pl);
  }

  Future<void> _applyHwdec(Player pl) async {
    if (_disposed) return;
    // Kembali ke 'default' setelah pernah diubah = pulihkan nilai bawaan media_kit.
    final want = hwdec == 'default' ? (_hwdecTouched ? 'auto-safe' : null) : hwdec;
    if (want == null) return;
    try {
      await (pl.platform as dynamic).setProperty('hwdec', want);
      _hwdecTouched = true;
      AppLog.info('mpv', 'hwdec diatur ke $want');
    } catch (e) {
      AppLog.warn('mpv', 'gagal mengatur hwdec: $e');
    }
  }

  void _scheduleDecodeLog(Player pl) {
    _logTimer?.cancel();
    _logTimer = Timer(const Duration(seconds: 2), () => _logDecode(pl));
  }

  /// Mencatat dekoder yang BENAR-BENAR dipakai mpv (hwdec-current: d3d11va, d3d11va-copy, atau no).
  Future<void> _logDecode(Player pl) async {
    if (_disposed || !currentIsVideo) return;
    try {
      final np = pl.platform as dynamic;
      final cur = await np.getProperty('hwdec-current');
      final cfg = await np.getProperty('hwdec');
      final fmt = await np.getProperty('video-format');
      final vo = await np.getProperty('current-vo');
      final name = (current ?? '-').split(RegExp(r'[\\/]')).last;
      AppLog.info('mpv', 'dekode: hwdec-current=$cur hwdec=$cfg format=$fmt vo=$vo berkas=$name');
    } catch (e) {
      AppLog.warn('mpv', 'gagal membaca info dekode: $e');
    }
  }

  /// Apakah [path] sedang jadi item aktif dan antrean sama dengan [list]?
  /// Dibandingkan lewat `Media(x).uri` agar format path Windows (backslash) tidak membuat
  /// perbandingan salah.
  bool isSame(String path, List<String> list) {
    if (!hasQueue) return false;
    final want = [for (final f in list) Media(f).uri];
    return current == Media(path).uri && listEquals(queue, want);
  }

  /// Video hanya didekode saat halaman pemutar terlihat. Saat halaman ditutup (musik/
  /// video tetap jalan di MiniPlayer), dekode video dimatikan -> CPU/GPU turun drastis.
  Future<void> setVideoVisible(bool v) async {
    final wasVisible = _videoVisible;
    _videoVisible = v;
    if (!_pauseVideoWhenHidden) return;
    _applyVideoTrack();
    final pl = _player;
    // Menyalakan lagi trek video di tengah lagu membuat dekoder mulai dari frame P tanpa
    // keyframe -> gambar pecah/blok sampai keyframe berikutnya. Seek ke posisi yang sama
    // memaksa dekoder mulai bersih dari keyframe terdekat.
    if (v && !wasVisible && pl != null && !_disposed && currentIsVideo) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (_disposed || !_videoVisible) return;
      final pos = pl.state.position;
      if (pos > const Duration(seconds: 1)) await pl.seek(pos);
    }
  }

  void _applyVideoTrack() {
    final pl = _player;
    if (pl == null || _disposed || !_pauseVideoWhenHidden) return;
    pl.setVideoTrack(_videoVisible ? VideoTrack.auto() : VideoTrack.no());
  }

  Future<void> enqueue(List<String> paths) async {
    if (paths.isEmpty) return;
    if (!hasQueue) return playAll(paths);
    for (final f in paths) {
      await player.add(Media(f));
    }
    notifyListeners();
  }

  Future<void> jump(int i) => player.jump(i);

  Future<void> removeAt(int i) async {
    await player.remove(i);
    notifyListeners();
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    player.setShuffle(shuffle);
    notifyListeners();
  }

  void cycleRepeat() {
    mode = switch (mode) {
      PlaylistMode.none => PlaylistMode.loop,
      PlaylistMode.loop => PlaylistMode.single,
      PlaylistMode.single => PlaylistMode.none,
    };
    player.setPlaylistMode(mode);
    notifyListeners();
  }

  Future<void> stop() async {
    await _player?.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _logTimer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    position.dispose();
    _player?.dispose();
    super.dispose();
  }
}

final playerHubProvider = Provider<PlayerHub>((ref) {
  final hub = PlayerHub()..hwdec = ref.read(settingsProvider).mpvHwdec;
  ref.listen(settingsProvider.select((s) => s.mpvHwdec), (_, v) => hub.setHwdec(v));
  ref.onDispose(hub.dispose);
  return hub;
});
