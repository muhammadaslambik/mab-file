import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings.dart';
import '../../../core/widgets/live_backdrop.dart';
import '../../player/mini_player.dart';
import '../../player/playlists_page.dart';
import '../../storage/storage_analyzer.dart';
import '../../vault/vault_page.dart';
import '../application/nav_state.dart';
import 'files_page.dart';
import 'mobile_page.dart';
import 'widgets/sidebar.dart';

/// IndexedStack yang membangun tab HANYA saat pertama kali dibuka (lalu dipertahankan).
/// Sebelumnya semua tab dibangun saat startup, termasuk pemindaian file terbesar -> berat.
class _LazyStack extends StatefulWidget {
  const _LazyStack({required this.index, required this.builders});
  final int index;
  final List<WidgetBuilder> builders;

  @override
  State<_LazyStack> createState() => _LazyStackState();
}

class _LazyStackState extends State<_LazyStack> {
  final _seen = <int>{};

  @override
  Widget build(BuildContext context) {
    _seen.add(widget.index);
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.builders.length; i++)
          _seen.contains(i) ? Builder(builder: widget.builders[i]) : const SizedBox.shrink(),
      ],
    );
  }
}

/// Adaptif: sidebar permanen (>= 900px) vs navigasi bawah (HP).
/// Indeks tab: 0 File, 1 Storage, 2 Vault, 3 Playlist.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = ref.watch(navIndexProvider);
    final animated = ref.watch(settingsProvider.select((s) => s.animated));
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final pages = _LazyStack(index: idx, builders: [
      (_) => wide ? const DesktopFilesPage() : const MobileFilesPage(),
      (_) => const StorageAnalyzerPage(),
      (_) => const VaultPage(),
      (_) => const PlaylistsPage(),
    ]);

    final backdrop = animated ? const LiveBackdrop() : const SizedBox.shrink();

    if (wide) {
      return Scaffold(
        body: Column(children: [
          Expanded(
            child: Stack(children: [
              Positioned.fill(child: backdrop),
              Row(children: [const Sidebar(), Expanded(child: pages)]),
            ]),
          ),
          const MiniPlayer(),
        ]),
      );
    }
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: backdrop),
        SafeArea(bottom: false, child: pages),
      ]),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        const MiniPlayer(),
        NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: ref.read(navIndexProvider.notifier).set,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder_rounded),
                label: 'File'),
            NavigationDestination(
                icon: Icon(Icons.pie_chart_outline_rounded),
                selectedIcon: Icon(Icons.pie_chart_rounded),
                label: 'Storage'),
            NavigationDestination(
                icon: Icon(Icons.lock_outline_rounded),
                selectedIcon: Icon(Icons.lock_rounded),
                label: 'Vault'),
            NavigationDestination(
                icon: Icon(Icons.queue_music_outlined),
                selectedIcon: Icon(Icons.queue_music_rounded),
                label: 'Playlist'),
          ],
        ),
      ]),
    );
  }
}
