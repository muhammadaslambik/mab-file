import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../archive/archive_service.dart';
import '../../storage/storage_analyzer.dart';
import '../application/file_manager_state.dart';
import '../../../core/notify/notify.dart';
import '../../../core/widgets/theme_picker.dart';
import '../application/nav_state.dart';
import '../domain/file_item.dart';
import 'file_actions.dart';
import 'widgets/file_views.dart';
import 'widgets/glyph.dart';
import 'widgets/toolbar.dart';

/// Tata letak HP: header merek, kartu storage, chip jenis file, daftar, FAB gradien.
class MobileFilesPage extends ConsumerWidget {
  const MobileFilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(fmProvider);
    final c = ref.read(fmProvider.notifier);
    final pal = Pal.of(context);

    ref.listen(fmProvider.select((v) => v.error), (_, e) {
      if (e != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
        c.consumeError();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (s.selecting) {
          c.clearSelection();
        } else if (!await c.back() && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: _Fab(),
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            s.selecting ? _SelectionBar() : const _Header(),
            if (!s.selecting) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SearchField(hint: 'Cari di MAB-File'),
              ),
              const _StorageCard(),
              const _Chips(),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 12, 4),
                child: Row(children: [
                  NavButtons(),
                  Expanded(child: Breadcrumb()),
                ]),
              ),
            ],
            SizedBox(
              height: 2,
              child: s.loading ? const LinearProgressIndicator(minHeight: 2) : null,
            ),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: pal.border.withValues(alpha: 0.0))),
                ),
                child: s.view == ViewMode.grid ? const TilesView() : const MobileList(),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(fmProvider.notifier);
    final view = ref.watch(fmProvider.select((s) => s.view));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 6),
      child: Row(children: [
        const BrandLogo(size: 34),
        const SizedBox(width: 10),
        const GradientText('MAB-File',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
        const Spacer(),
        const NotifBell(),
        IconButton(
          tooltip: 'Tema',
          onPressed: () => showThemePicker(context),
          icon: const Icon(Icons.palette_outlined),
        ),
        IconButton(
          tooltip: 'Tampilan',
          onPressed: () => c.setView(view == ViewMode.grid ? ViewMode.details : ViewMode.grid),
          icon: Icon(view == ViewMode.grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
        ),
        const SortMenu(),
      ]),
    );
  }
}

class _SelectionBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(fmProvider);
    final c = ref.read(fmProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.close_rounded), onPressed: c.clearSelection),
        Expanded(
            child: Text('${s.selected.length} dipilih',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
        IconButton(tooltip: 'Salin', icon: const Icon(Icons.copy_rounded), onPressed: c.copy),
        IconButton(tooltip: 'Potong', icon: const Icon(Icons.content_cut_rounded), onPressed: c.cutSelected),
        if (s.selected.length == 1)
          IconButton(
              tooltip: 'Ganti nama',
              icon: const Icon(Icons.drive_file_rename_outline_rounded),
              onPressed: () => renameSelected(context, ref)),
        IconButton(
            tooltip: 'Hapus',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => deleteSelected(context, ref)),
        PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'all':
                c.selectAll();
              case 'zip':
                c.compress(ArchiveFormat.zip);
              case 'tar':
                c.compress(ArchiveFormat.tar);
              case 'tgz':
                c.compress(ArchiveFormat.tarGz);
              case 'vault':
                moveToVault(context, ref);
              case 'play':
                playSelection(context, ref);
              case 'enqueue':
                enqueueSelection(context, ref);
              case 'edit':
                editSelected(context, ref);
              case 'ext':
                openSelectedExternally(context, ref);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'all', child: Text('Pilih semua')),
            PopupMenuItem(value: 'zip', child: Text('Kompres ZIP')),
            PopupMenuItem(value: 'tar', child: Text('Kompres TAR')),
            PopupMenuItem(value: 'tgz', child: Text('Kompres TAR.GZ')),
            PopupMenuItem(value: 'vault', child: Text('Pindah ke Vault')),
            PopupMenuItem(value: 'play', child: Text('Putar sebagai playlist')),
            PopupMenuItem(value: 'enqueue', child: Text('Tambah ke antrean')),
            PopupMenuItem(value: 'edit', child: Text('Edit / Studio')),
            PopupMenuItem(value: 'ext', child: Text('Buka dengan aplikasi lain')),
          ],
        ),
      ]),
    );
  }
}

class _StorageCard extends ConsumerWidget {
  const _StorageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = driveFor(ref.watch(drivesProvider).valueOrNull ?? const [],
        ref.watch(fmProvider.select((s) => s.path)));
    if (d == null) return const SizedBox.shrink();
    final pal = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => ref.read(navIndexProvider.notifier).set(1),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: pal.border),
            gradient: LinearGradient(colors: [
              pal.accentA.withValues(alpha: 0.16),
              pal.accentB.withValues(alpha: 0.16),
            ]),
          ),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: Text('${formatBytes(d.total)} • ${(d.frac * 100).round()}% terpakai',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text('Detail', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ]),
            const SizedBox(height: 10),
            UsageBar(d.frac, height: 7),
          ]),
        ),
      ),
    );
  }
}

class _Chips extends ConsumerWidget {
  const _Chips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(fmProvider.select((s) => s.filter));
    final c = ref.read(fmProvider.notifier);
    final pal = Pal.of(context);
    const cats = [
      FileCategory.image,
      FileCategory.video,
      FileCategory.audio,
      FileCategory.document,
      FileCategory.apk,
      FileCategory.archive,
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final k in cats)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: CircleAvatar(radius: 4, backgroundColor: catColor(k)),
                label: Text(catLabel(k), style: const TextStyle(fontSize: 12.5)),
                selected: f == k,
                showCheckmark: false,
                side: BorderSide(color: pal.border),
                onSelected: (_) => c.setFilter(k),
              ),
            ),
        ],
      ),
    );
  }
}

class _Fab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(fmProvider);
    final pal = Pal.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (s.clipboard.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FloatingActionButton.small(
            heroTag: 'paste',
            onPressed: ref.read(fmProvider.notifier).paste,
            child: const Icon(Icons.paste_rounded),
          ),
        ),
      PopupMenuButton<bool>(
        onSelected: (dir) => newItem(context, ref, dir: dir),
        itemBuilder: (_) => const [
          PopupMenuItem(value: true, child: Text('Folder baru')),
          PopupMenuItem(value: false, child: Text('File baru')),
        ],
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
                colors: [pal.accentA, pal.accentB],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            boxShadow: [
              BoxShadow(
                  color: pal.accentB.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5)),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    ]);
  }
}
