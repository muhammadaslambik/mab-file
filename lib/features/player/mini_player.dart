import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_theme.dart';
import 'media_page.dart';
import 'player_hub.dart';

/// Pemutar mini yang selalu tampil selama ada antrean, sehingga musik/video
/// bisa berputar di latar belakang sambil Anda menjelajah file.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(playerHubProvider);
    return ListenableBuilder(
      listenable: hub,
      builder: (ctx, _) {
        if (!hub.hasQueue) return const SizedBox.shrink();
        final pal = Pal.of(context);
        final cur = hub.current;
        final player = hub.player;
        void open() => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaPage()));

        return Material(
          color: pal.side,
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: pal.border))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: 2,
                child: StreamBuilder<Duration>(
                  stream: player.stream.position,
                  builder: (_, pos) => StreamBuilder<Duration>(
                    stream: player.stream.duration,
                    builder: (_, dur) {
                      final total = (dur.data ?? player.state.duration).inMilliseconds;
                      final now = (pos.data ?? player.state.position).inMilliseconds;
                      final v = total <= 0 ? 0.0 : (now / total).clamp(0.0, 1.0).toDouble();
                      return LinearProgressIndicator(value: v, minHeight: 2, backgroundColor: pal.border);
                    },
                  ),
                ),
              ),
              SizedBox(
                height: 58,
                child: LayoutBuilder(builder: (_, cs) {
                  final narrow = cs.maxWidth < 560;
                  return Row(children: [
                    InkWell(
                      onTap: open,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 12, 0),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(gradient: pal.gradient, borderRadius: BorderRadius.circular(10)),
                          child: Icon(hub.currentIsVideo ? Icons.movie_rounded : Icons.music_note_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: open,
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(cur == null ? '' : p.basenameWithoutExtension(cur),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                          Text('${hub.index + 1} / ${hub.queue.length}',
                              style: TextStyle(color: pal.muted, fontSize: 11.5)),
                        ]),
                      ),
                    ),
                    if (!narrow)
                      IconButton(
                        tooltip: 'Acak',
                        onPressed: hub.toggleShuffle,
                        icon: Icon(Icons.shuffle_rounded, size: 19, color: hub.shuffle ? pal.accentA : pal.muted),
                      ),
                    IconButton(onPressed: player.previous, icon: const Icon(Icons.skip_previous_rounded)),
                    StreamBuilder<bool>(
                      stream: player.stream.playing,
                      builder: (_, s) => IconButton.filled(
                        onPressed: player.playOrPause,
                        icon: Icon((s.data ?? player.state.playing) ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      ),
                    ),
                    IconButton(onPressed: player.next, icon: const Icon(Icons.skip_next_rounded)),
                    if (!narrow)
                      IconButton(
                        tooltip: 'Ulangi',
                        onPressed: hub.cycleRepeat,
                        icon: Icon(
                          hub.mode == PlaylistMode.single ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                          size: 19,
                          color: hub.mode == PlaylistMode.none ? pal.muted : pal.accentA,
                        ),
                      ),
                    IconButton(
                      tooltip: 'Tutup pemutar',
                      onPressed: hub.stop,
                      icon: const Icon(Icons.close_rounded, size: 19),
                    ),
                  ]);
                }),
              ),
            ]),
          ),
        );
      },
    );
  }
}
