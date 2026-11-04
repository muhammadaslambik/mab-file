import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/formatters.dart';
import '../../archive/archive_service.dart';
import '../../vault/vault_page.dart';
import '../../viewer/viewers.dart';
import '../application/file_manager_state.dart';
import '../domain/file_item.dart';

IconData iconFor(FileCategory c) => switch (c) {
      FileCategory.folder => Icons.folder,
      FileCategory.image => Icons.image_outlined,
      FileCategory.video => Icons.movie_outlined,
      FileCategory.audio => Icons.audiotrack_outlined,
      FileCategory.apk => Icons.android,
      FileCategory.archive => Icons.archive_outlined,
      FileCategory.code => Icons.description_outlined,
      FileCategory.document => Icons.picture_as_pdf_outlined,
      FileCategory.other => Icons.insert_drive_file_outlined,
    };

Future<String?> askText(BuildContext c, String title, {String initial = ''}) {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
    context: c,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctl, autofocus: true, onSubmitted: (v) => Navigator.pop(c, v)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('OK')),
      ],
    ),
  );
}

class FilesPage extends ConsumerWidget {
  const FilesPage({super.key});

  void _open(BuildContext ctx, WidgetRef ref, FileItem it) {
    if (it.isDir) {
      ref.read(fmProvider.notifier).open(it.path);
      return;
    }
    Widget? page;
    switch (it.category) {
      case FileCategory.image:
        page = ImageViewerPage(path: it.path);
      case FileCategory.video || FileCategory.audio:
        page = MediaPage(path: it.path);
      case FileCategory.code:
        page = TextEditorPage(path: it.path);
      case FileCategory.archive:
        ref.read(fmProvider.notifier).extractHere(it.path);
        return;
      default:
        ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('Belum ada viewer bawaan untuk tipe ini')));
        return;
    }
    final target = page;
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => target));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(fmProvider);
    final c = ref.read(fmProvider.notifier);

    ref.listen(fmProvider.select((v) => v.error), (_, e) {
      if (e != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
        c.consumeError();
      }
    });

    Future<void> doRename() async {
      final path = s.selected.first;
      final n = await askText(context, 'Ganti nama', initial: p.basename(path));
      if (n != null && n.isNotEmpty) await c.rename(path, n);
    }

    Future<void> doDelete() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Hapus ${s.selected.length} item?'),
          content: const Text('Tindakan ini permanen.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
          ],
        ),
      );
      if (ok == true) await c.deleteSelected();
    }

    Future<void> toVault() async {
      final v = ref.read(vaultProvider);
      if (!v.unlocked) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Buka tab Vault terlebih dulu')));
        return;
      }
      for (final path in s.selected) {
        if (FileSystemEntity.typeSync(path) != FileSystemEntityType.file) continue;
        await v.addFile(path);
      }
      await c.refresh();
    }

    // Shortcut desktop (Ctrl/Cmd + C/X/V/A, Delete, F2, Backspace)
    Map<ShortcutActivator, VoidCallback> keys() {
      final m = <ShortcutActivator, VoidCallback>{};
      for (final (ctrl, meta) in [(true, false), (false, true)]) {
        m[SingleActivator(LogicalKeyboardKey.keyC, control: ctrl, meta: meta)] = () { if (s.selecting) c.copy(); };
        m[SingleActivator(LogicalKeyboardKey.keyX, control: ctrl, meta: meta)] = () { if (s.selecting) c.cutSelected(); };
        m[SingleActivator(LogicalKeyboardKey.keyV, control: ctrl, meta: meta)] = c.paste;
        m[SingleActivator(LogicalKeyboardKey.keyA, control: ctrl, meta: meta)] = c.selectAll;
      }
      m[const SingleActivator(LogicalKeyboardKey.delete)] = () { if (s.selecting) doDelete(); };
      m[const SingleActivator(LogicalKeyboardKey.f2)] = () { if (s.selected.length == 1) doRename(); };
      m[const SingleActivator(LogicalKeyboardKey.escape)] = c.clearSelection;
      return m;
    }

    final cs = Theme.of(context).colorScheme;
    final items = s.visible;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (s.selecting) {
          c.clearSelection();
        } else if (!await c.back() && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: CallbackShortcuts(
        bindings: keys(),
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: s.selecting
                ? AppBar(
                    leading: IconButton(icon: const Icon(Icons.close), onPressed: c.clearSelection),
                    title: Text('${s.selected.length} dipilih'),
                    actions: [
                      IconButton(tooltip: 'Salin', icon: const Icon(Icons.copy), onPressed: c.copy),
                      IconButton(tooltip: 'Potong', icon: const Icon(Icons.content_cut), onPressed: c.cutSelected),
                      if (s.selected.length == 1)
                        IconButton(tooltip: 'Ganti nama', icon: const Icon(Icons.drive_file_rename_outline), onPressed: doRename),
                      IconButton(tooltip: 'Hapus', icon: const Icon(Icons.delete_outline), onPressed: doDelete),
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          switch (v) {
                            case 'zip': c.compress(ArchiveFormat.zip);
                            case 'tar': c.compress(ArchiveFormat.tar);
                            case 'tgz': c.compress(ArchiveFormat.tarGz);
                            case 'all': c.selectAll();
                            case 'vault': toVault();
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'all', child: Text('Pilih semua')),
                          PopupMenuItem(value: 'zip', child: Text('Kompres ZIP')),
                          PopupMenuItem(value: 'tar', child: Text('Kompres TAR')),
                          PopupMenuItem(value: 'tgz', child: Text('Kompres TAR.GZ')),
                          PopupMenuItem(value: 'vault', child: Text('Pindah ke Vault')),
                        ],
                      ),
                    ],
                  )
                : AppBar(
                    leading: IconButton(icon: const Icon(Icons.arrow_upward), onPressed: c.up),
                    title: Text(s.path, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                    actions: [
                      IconButton(icon: Icon(s.grid ? Icons.view_list : Icons.grid_view), onPressed: c.toggleGrid),
                      PopupMenuButton<SortMode>(
                        icon: const Icon(Icons.sort),
                        onSelected: c.setSort,
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: SortMode.name, child: Text('Nama')),
                          PopupMenuItem(value: SortMode.size, child: Text('Ukuran')),
                          PopupMenuItem(value: SortMode.date, child: Text('Tanggal')),
                        ],
                      ),
                      IconButton(
                          tooltip: 'File tersembunyi',
                          icon: Icon(s.showHidden ? Icons.visibility : Icons.visibility_off),
                          onPressed: c.toggleHidden),
                      IconButton(icon: const Icon(Icons.refresh), onPressed: c.refresh),
                    ],
                  ),
            floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
              if (s.clipboard.isNotEmpty)
                FloatingActionButton.small(
                  heroTag: 'paste',
                  tooltip: 'Tempel (${s.clipboard.length})',
                  onPressed: c.paste,
                  child: const Icon(Icons.paste),
                ),
              const SizedBox(height: 8),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  final n = await askText(context, v == 'dir' ? 'Folder baru' : 'File baru');
                  if (n == null || n.isEmpty) return;
                  v == 'dir' ? c.newFolder(n) : c.newFile(n);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'dir', child: Text('Folder baru')),
                  PopupMenuItem(value: 'file', child: Text('File baru')),
                ],
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.add, color: cs.onPrimary),
                ),
              ),
            ]),
            body: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: SearchBar(
                  hintText: 'Deep search di folder ini…',
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  onSubmitted: c.search,
                  trailing: [
                    if (s.query.isNotEmpty)
                      IconButton(icon: const Icon(Icons.close), onPressed: () => c.search('')),
                  ],
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
                  for (final cat in const <FileCategory?>[null, FileCategory.document, FileCategory.image, FileCategory.video, FileCategory.audio, FileCategory.apk, FileCategory.archive])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat == null ? 'Semua' : cat.name),
                        selected: s.filter == cat,
                        onSelected: (_) => c.setFilter(cat),
                      ),
                    ),
                ]),
              ),
              if (s.loading) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: items.isEmpty && !s.loading
                    ? const Center(child: Text('Kosong'))
                    : s.grid
                        ? GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 120, mainAxisSpacing: 8, crossAxisSpacing: 8),
                            itemCount: items.length,
                            itemBuilder: (_, i) => _tile(context, ref, s, items[i], grid: true),
                          )
                        : ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (_, i) => _tile(context, ref, s, items[i]),
                          ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext ctx, WidgetRef ref, FmState s, FileItem it, {bool grid = false}) {
    final c = ref.read(fmProvider.notifier);
    final sel = s.selected.contains(it.path);
    final cs = Theme.of(ctx).colorScheme;
    final icon = Icon(iconFor(it.category), size: grid ? 36 : null, color: it.isDir ? cs.primary : cs.secondary);

    void tap() => s.selecting ? c.toggleSelect(it.path) : _open(ctx, ref, it);

    if (grid) {
      return GestureDetector(
        onTap: tap,
        onLongPress: () => c.toggleSelect(it.path),
        onSecondaryTap: () => c.toggleSelect(it.path),
        child: Container(
          decoration: BoxDecoration(
            color: sel ? cs.primaryContainer : cs.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            icon,
            const SizedBox(height: 6),
            Text(it.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
          ]),
        ),
      );
    }
    return GestureDetector(
      onSecondaryTap: () => c.toggleSelect(it.path), // klik kanan (desktop)
      child: ListTile(
        selected: sel,
        selectedTileColor: cs.primaryContainer,
        leading: icon,
        title: Text(it.name, overflow: TextOverflow.ellipsis),
        subtitle: Text(it.isDir ? formatDate(it.modified) : '${formatBytes(it.size)} • ${formatDate(it.modified)}'),
        trailing: s.selecting ? Checkbox(value: sel, onChanged: (_) => c.toggleSelect(it.path)) : null,
        onTap: tap,
        onLongPress: () => c.toggleSelect(it.path),
      ),
    );
  }
}
