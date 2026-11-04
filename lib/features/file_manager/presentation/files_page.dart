import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../archive/archive_service.dart';
import '../../storage/storage_analyzer.dart';
import '../application/file_manager_state.dart';
import 'file_actions.dart';
import 'widgets/file_views.dart';
import 'widgets/toolbar.dart';

/// Tata letak desktop: toolbar -> command bar -> isi -> status bar.
class DesktopFilesPage extends ConsumerWidget {
  const DesktopFilesPage({super.key});

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

    Map<ShortcutActivator, VoidCallback> keys() {
      final m = <ShortcutActivator, VoidCallback>{};
      for (final (ctrl, meta) in [(true, false), (false, true)]) {
        m[SingleActivator(LogicalKeyboardKey.keyC, control: ctrl, meta: meta)] = () { if (s.selecting) c.copy(); };
        m[SingleActivator(LogicalKeyboardKey.keyX, control: ctrl, meta: meta)] = () { if (s.selecting) c.cutSelected(); };
        m[SingleActivator(LogicalKeyboardKey.keyV, control: ctrl, meta: meta)] = c.paste;
        m[SingleActivator(LogicalKeyboardKey.keyA, control: ctrl, meta: meta)] = c.selectAll;
      }
      m[const SingleActivator(LogicalKeyboardKey.delete)] = () => deleteSelected(context, ref);
      m[const SingleActivator(LogicalKeyboardKey.f2)] = () => renameSelected(context, ref);
      m[const SingleActivator(LogicalKeyboardKey.f5)] = c.refresh;
      m[const SingleActivator(LogicalKeyboardKey.enter)] = () => openSelected(context, ref);
      m[const SingleActivator(LogicalKeyboardKey.escape)] = c.clearSelection;
      m[const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true)] = c.back;
      m[const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true)] = c.forward;
      m[const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true)] = c.up;
      return m;
    }

    return CallbackShortcuts(
      bindings: keys(),
      child: Focus(
        autofocus: true,
        child: DecoratedBox(
          // cahaya halus dari warna logo di pojok kiri-atas (statis -> ringan)
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-1.0, -1.25),
              radius: 1.15,
              colors: [Brand.blue.withValues(alpha: 0.10), Colors.transparent],
            ),
          ),
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 10, 16, 4),
              child: _TopBar(),
            ),
            const _CommandBar(),
            SizedBox(
              height: 2,
              child: s.loading ? const LinearProgressIndicator(minHeight: 2) : null,
            ),
            Expanded(
              child: s.view == ViewMode.grid ? const TilesView() : const DetailsView(),
            ),
            _StatusBar(pal: pal),
          ]),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) => const Row(children: [
        NavButtons(),
        Expanded(flex: 5, child: Breadcrumb()),
        SizedBox(width: 12),
        Expanded(flex: 3, child: SearchField()),
        SizedBox(width: 12),
        ViewToggle(),
        SortMenu(),
      ]);
}

class _CommandBar extends ConsumerWidget {
  const _CommandBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(fmProvider);
    final c = ref.read(fmProvider.notifier);
    final pal = Pal.of(context);
    final sel = s.selecting;
    final single = s.selected.length == 1;

    Widget cmd(IconData i, String label, VoidCallback? on) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: TextButton.icon(
            onPressed: on,
            icon: Icon(i, size: 18),
            label: Text(label, style: const TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(
              foregroundColor: pal.text,
              disabledForegroundColor: pal.muted.withValues(alpha: 0.45),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );

    Widget sep() => Container(
        width: 1, height: 20, margin: const EdgeInsets.symmetric(horizontal: 6), color: pal.border);

    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          PopupMenuButton<bool>(
            tooltip: 'Buat baru',
            onSelected: (dir) => newItem(context, ref, dir: dir),
            itemBuilder: (_) => const [
              PopupMenuItem(value: true, child: Text('Folder baru')),
              PopupMenuItem(value: false, child: Text('File baru')),
            ],
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: Brand.gradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(children: [
                Icon(Icons.add_rounded, size: 18, color: Colors.white),
                SizedBox(width: 6),
                Text('Baru',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
          ),
          sep(),
          cmd(Icons.content_cut_rounded, 'Potong', sel ? c.cutSelected : null),
          cmd(Icons.copy_rounded, 'Salin', sel ? c.copy : null),
          cmd(Icons.paste_rounded, 'Tempel${s.clipboard.isEmpty ? '' : ' (${s.clipboard.length})'}',
              s.clipboard.isEmpty ? null : c.paste),
          cmd(Icons.drive_file_rename_outline_rounded, 'Ganti nama',
              single ? () => renameSelected(context, ref) : null),
          cmd(Icons.delete_outline_rounded, 'Hapus', sel ? () => deleteSelected(context, ref) : null),
          sep(),
          PopupMenuButton<ArchiveFormat>(
            enabled: sel,
            tooltip: 'Kompres',
            onSelected: c.compress,
            itemBuilder: (_) => const [
              PopupMenuItem(value: ArchiveFormat.zip, child: Text('ZIP')),
              PopupMenuItem(value: ArchiveFormat.tar, child: Text('TAR')),
              PopupMenuItem(value: ArchiveFormat.tarGz, child: Text('TAR.GZ')),
            ],
            child: IgnorePointer(
              child: cmd(Icons.folder_zip_outlined, 'Kompres', sel ? () {} : null),
            ),
          ),
          cmd(Icons.lock_outline_rounded, 'Ke Vault', sel ? () => moveToVault(context, ref) : null),
          if (s.filter != null) ...[
            sep(),
            cmd(Icons.filter_alt_off_rounded, 'Hapus filter', () => c.setFilter(s.filter)),
          ],
        ]),
      ),
    );
  }
}

class _StatusBar extends ConsumerWidget {
  const _StatusBar({required this.pal});
  final Pal pal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(fmProvider);
    final drives = ref.watch(drivesProvider).valueOrNull ?? const <DriveInfo>[];
    final d = driveFor(drives, s.path);
    final n = s.visible.length;
    final selSize = s.selectedItems.fold<int>(0, (a, e) => a + (e.isDir ? 0 : e.size));
    final style = TextStyle(color: pal.muted, fontSize: 12);

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: pal.side,
        border: Border(top: BorderSide(color: pal.border)),
      ),
      child: Row(children: [
        Text('$n item', style: style),
        if (s.selecting) Text('  •  ${s.selected.length} dipilih • ${formatBytes(selSize)}', style: style),
        if (s.results != null) Text('  •  hasil pencarian', style: style),
        const Spacer(),
        if (d != null) ...[
          SizedBox(width: 90, child: UsageBar(d.frac, height: 4)),
          const SizedBox(width: 10),
          Text('${formatBytes(d.free)} kosong dari ${formatBytes(d.total)}', style: style),
        ],
      ]),
    );
  }
}
