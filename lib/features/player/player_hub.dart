import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
  PlaylistMode mode = PlaylistMode.none;

  Player get player => _player ??= _create();
  VideoController get video => _video ??= VideoController(player);

  Player _create() {
    MediaKit.ensureInitialized();
    final pl = Player();
    pl.stream.playlist.listen((_) {
      if (!_disposed) notifyListeners();
    });
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
    await player.open(Playlist([for (final f in paths) Media(f)], index: i));
    notifyListeners();
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
    _player?.dispose();
    super.dispose();
  }
}

final playerHubProvider = Provider<PlayerHub>((ref) {
  final hub = PlayerHub();
  ref.onDispose(hub.dispose);
  return hub;
});
