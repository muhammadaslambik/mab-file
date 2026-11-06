import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/notify/notify.dart';
import '../../core/theme/app_theme.dart';
import '../file_manager/presentation/file_actions.dart';
import 'media_page.dart';
import 'player_hub.dart';
import 'playlist_store.dart';

class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(playerHubProvider);
    final lists = ref.watch(playlistStoreProvider);
    final pal = Pal.of(context);

    Future<void> playSaved(String name, List<String> paths) async {
      final ok = paths.where((f) => File(f).existsSync()).toList();
      if (ok.isEmpty) {
        ref.read(notifsProvider.notifier).push('File playlist tidak ditemukan', kind: NoteKind.error);
        return;
      }
      await hub.playAll(ok);
      ref.read(notifsProvider.notifier).push('Memutar "$name"', body: '${ok.length} item');
    }

    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Playlist', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('Pilih beberapa file audio/video di tab File, lalu tekan "Putar" atau "Antrean".',
          style: TextStyle(color: pal.muted, fontSize: 12.5)),
      const SizedBox(height: 18),
      ListenableBuilder(
        listenable: hub,
        builder: (_, __) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: pal.border),
            gradient: LinearGradient(colors: [
              pal.accentA.withValues(alpha: 0.14),
              pal.accentB.withValues(alpha: 0.14),
            ]),
          ),
          child: Row(children: [
            const Icon(Icons.graphic_eq_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: hub.hasQueue
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Sedang diputar (${hub.queue.length} item)', style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(hub.current == null ? '' : p.basename(hub.current!),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: pal.muted, fontSize: 12.5)),
                    ])
                  : Text('Belum ada antrean', style: TextStyle(color: pal.muted)),
            ),
            if (hub.hasQueue) ...[
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaPage())),
                child: const Text('Buka'),
              ),
              TextButton(
                onPressed: () async {
                  final name = await askText(context, 'Simpan sebagai playlist', initial: 'Playlist baru');
                  if (name == null || name.trim().isEmpty) return;
                  await ref.read(playlistStoreProvider.notifier).save(name.trim(), hub.queue);
                  ref.read(notifsProvider.notifier).push('Playlist disimpan', body: name.trim(), kind: NoteKind.success);
                },
                child: const Text('Simpan'),
              ),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 24),
      Text('Playlist tersimpan', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      if (lists.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text('Belum ada playlist tersimpan.', style: TextStyle(color: pal.muted)),
        ),
      for (final e in lists.entries)
        ListTile(
          leading: const Icon(Icons.queue_music_rounded),
          title: Text(e.key),
          subtitle: Text('${e.value.length} item'),
          onTap: () => playSaved(e.key, e.value),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: 'Putar',
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: () => playSaved(e.key, e.value),
            ),
            IconButton(
              tooltip: 'Hapus',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => ref.read(playlistStoreProvider.notifier).remove(e.key),
            ),
          ]),
        ),
    ]);
  }
}
