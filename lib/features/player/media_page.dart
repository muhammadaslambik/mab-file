import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;

import '../../core/notify/notify.dart';
import '../../core/theme/app_theme.dart';
import '../editor/media_studio_page.dart';
import '../file_manager/presentation/file_actions.dart';
import '../viewer/viewers.dart';
import 'player_hub.dart';
import 'playlist_store.dart';

/// Halaman pemutar penuh. Memakai pemutar global (PlayerHub) sehingga menutup halaman
/// ini TIDAK menghentikan pemutaran; kontrol lanjut di MiniPlayer.
class MediaPage extends ConsumerStatefulWidget {
  const MediaPage({super.key, this.path, this.playlist = const [], this.audio = false});

  /// null = buka pemutar untuk antrean yang sedang berjalan.
  final String? path;
  final List<String> playlist;
  final bool audio;

  @override
  ConsumerState<MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends ConsumerState<MediaPage> {
  late final PlayerHub hub = ref.read(playerHubProvider);
  bool _queue = true;

  @override
  void initState() {
    super.initState();
    final path = widget.path;
    if (path != null) {
      final list = widget.playlist.isEmpty ? [path] : widget.playlist;
      final same = hub.hasQueue && hub.current == path && listEquals(hub.queue, list);
      if (!same) hub.playAll(list, start: max(0, list.indexOf(path)));
    }
  }

  String _fmt(Duration d) {
    String t(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    return '${h > 0 ? '$h:' : ''}${t(d.inMinutes % 60)}:${t(d.inSeconds % 60)}';
  }

  Future<void> _saveAs() async {
    final name = await askText(context, 'Simpan sebagai playlist', initial: 'Playlist baru');
    if (name == null || name.trim().isEmpty) return;
    await ref.read(playlistStoreProvider.notifier).save(name.trim(), hub.queue);
    ref.read(notifsProvider.notifier).push('Playlist disimpan', body: name.trim(), kind: NoteKind.success);
  }

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return ListenableBuilder(
      listenable: hub,
      builder: (ctx, _) {
        final cur = hub.current;
        return Scaffold(
          appBar: AppBar(
            title: Text(cur == null ? 'Pemutar' : p.basename(cur), style: const TextStyle(fontSize: 15)),
            actions: [
              IconButton(
                tooltip: _queue ? 'Sembunyikan antrean' : 'Tampilkan antrean',
                icon: Icon(Icons.queue_music_rounded, color: _queue ? pal.accentA : null),
                onPressed: () => setState(() => _queue = !_queue),
              ),
              if (cur != null) ...[
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
            ],
          ),
          body: cur == null
              ? const Center(child: Text('Antrean kosong'))
              : LayoutBuilder(builder: (c, cs) {
                  final wide = cs.maxWidth >= 900;
                  final main = hub.currentIsVideo
                      ? Video(controller: hub.video)
                      : _audioUi(pal, cur);
                  final q = _queuePanel(pal);
                  return wide
                      ? Row(children: [
                          Expanded(child: main),
                          if (_queue) SizedBox(width: 340, child: q),
                        ])
                      : Column(children: [
                          Expanded(child: main),
                          if (_queue) SizedBox(height: 250, child: q),
                        ]);
                }),
        );
      },
    );
  }

  Widget _queuePanel(Pal pal) {
    final q = hub.queue;
    final idx = hub.index;
    return Material(
      color: pal.card,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 6, 2),
          child: Row(children: [
            Text('Antrean (${q.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(tooltip: 'Simpan sebagai playlist', icon: const Icon(Icons.playlist_add_rounded), onPressed: _saveAs),
            IconButton(
              tooltip: 'Hentikan & kosongkan',
              icon: const Icon(Icons.clear_all_rounded),
              onPressed: () async {
                await hub.stop();
                if (mounted) Navigator.pop(context);
              },
            ),
          ]),
        ),
        Divider(height: 1, color: pal.border),
        Expanded(
          child: ListView.builder(
            itemExtent: 46,
            itemCount: q.length,
            itemBuilder: (_, i) => ListTile(
              dense: true,
              selected: i == idx,
              selectedTileColor: pal.select,
              leading: i == idx
                  ? Icon(Icons.graphic_eq_rounded, color: pal.accentA)
                  : Text('${i + 1}', style: TextStyle(color: pal.muted)),
              title: Text(p.basename(q[i]), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => hub.removeAt(i),
              ),
              onTap: () => hub.jump(i),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _audioUi(Pal pal, String cur) {
    final player = hub.player;
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(gradient: pal.gradient, borderRadius: BorderRadius.circular(34)),
                child: const Icon(Icons.music_note_rounded, size: 88, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(p.basenameWithoutExtension(cur),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text('${hub.index + 1} dari ${hub.queue.length}', style: TextStyle(color: pal.muted)),
              const SizedBox(height: 10),
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
                        max: total <= 0 ? 1.0 : total,
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
                IconButton(
                  tooltip: 'Acak',
                  onPressed: hub.toggleShuffle,
                  icon: Icon(Icons.shuffle_rounded, color: hub.shuffle ? pal.accentA : pal.muted),
                ),
                IconButton(iconSize: 32, onPressed: player.previous, icon: const Icon(Icons.skip_previous_rounded)),
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
                IconButton(iconSize: 32, onPressed: player.next, icon: const Icon(Icons.skip_next_rounded)),
                IconButton(
                  tooltip: 'Ulangi',
                  onPressed: hub.cycleRepeat,
                  icon: Icon(
                    hub.mode == PlaylistMode.single ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                    color: hub.mode == PlaylistMode.none ? pal.muted : pal.accentA,
                  ),
                ),
              ]),
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
      ),
    );
  }
}
