import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../archive/archive_service.dart';
import '../../vault/vault_page.dart';
import '../../viewer/viewers.dart';
import '../application/file_manager_state.dart';
import '../application/nav_state.dart';
import '../domain/file_item.dart';

bool get isDesktopPlatform =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

Future<String?> askText(BuildContext c, String title, {String initial = ''}) {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
    context: c,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctl,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(c, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('OK')),
      ],
    ),
  );
}

void openItem(BuildContext ctx, WidgetRef ref, FileItem it) {
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

void openSelected(BuildContext ctx, WidgetRef ref) {
  final s = ref.read(fmProvider);
  if (s.selected.length == 1 && s.selectedItems.isNotEmpty) {
    openItem(ctx, ref, s.selectedItems.first);
  }
}

Future<void> renameSelected(BuildContext ctx, WidgetRef ref) async {
  final s = ref.read(fmProvider);
  if (s.selected.length != 1) return;
  final path = s.selected.first;
  final n = await askText(ctx, 'Ganti nama', initial: p.basename(path));
  if (n != null && n.isNotEmpty) {
    await ref.read(fmProvider.notifier).rename(path, n);
  }
}

Future<void> deleteSelected(BuildContext ctx, WidgetRef ref) async {
  final n = ref.read(fmProvider).selected.length;
  if (n == 0) return;
  final ok = await showDialog<bool>(
    context: ctx,
    builder: (_) => AlertDialog(
      title: Text('Hapus $n item?'),
      content: const Text('Tindakan ini permanen dan tidak masuk Recycle Bin.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
      ],
    ),
  );
  if (ok == true) await ref.read(fmProvider.notifier).deleteSelected();
}

Future<void> moveToVault(BuildContext ctx, WidgetRef ref) async {
  final v = ref.read(vaultProvider);
  if (!v.unlocked) {
    ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Buka Vault terlebih dulu (tab Vault)')));
    ref.read(navIndexProvider.notifier).set(2);
    return;
  }
  final c = ref.read(fmProvider.notifier);
  for (final path in ref.read(fmProvider).selected) {
    if (FileSystemEntity.typeSync(path) != FileSystemEntityType.file) continue;
    await v.addFile(path);
  }
  await c.refresh();
}

Future<void> newItem(BuildContext ctx, WidgetRef ref, {required bool dir}) async {
  final n = await askText(ctx, dir ? 'Folder baru' : 'File baru');
  if (n == null || n.isEmpty) return;
  final c = ref.read(fmProvider.notifier);
  dir ? await c.newFolder(n) : await c.newFile(n);
}

/// Menu klik-kanan (desktop).
Future<void> showItemMenu(BuildContext ctx, WidgetRef ref, Offset pos) async {
  final s = ref.read(fmProvider);
  final c = ref.read(fmProvider.notifier);
  final single = s.selected.length == 1;
  final isArchive = single &&
      s.selectedItems.isNotEmpty &&
      s.selectedItems.first.category == FileCategory.archive;

  PopupMenuItem<String> it(String v, IconData i, String t) => PopupMenuItem(
        value: v,
        height: 40,
        child: Row(children: [Icon(i, size: 18), const SizedBox(width: 12), Text(t)]),
      );

  final overlay = Overlay.of(ctx).context.findRenderObject() as RenderBox;
  final v = await showMenu<String>(
    context: ctx,
    position: RelativeRect.fromRect(pos & const Size(1, 1), Offset.zero & overlay.size),
    items: [
      if (single) it('open', Icons.open_in_new_rounded, 'Buka'),
      it('copy', Icons.copy_rounded, 'Salin'),
      it('cut', Icons.content_cut_rounded, 'Potong'),
      if (s.clipboard.isNotEmpty) it('paste', Icons.paste_rounded, 'Tempel'),
      if (single) it('rename', Icons.drive_file_rename_outline_rounded, 'Ganti nama'),
      const PopupMenuDivider(),
      it('zip', Icons.folder_zip_outlined, 'Kompres ke ZIP'),
      if (isArchive) it('extract', Icons.unarchive_outlined, 'Ekstrak di sini'),
      it('vault', Icons.lock_outline_rounded, 'Pindah ke Vault'),
      const PopupMenuDivider(),
      it('delete', Icons.delete_outline_rounded, 'Hapus'),
    ],
  );
  if (v == null || !ctx.mounted) return;
  switch (v) {
    case 'open':
      openSelected(ctx, ref);
    case 'copy':
      c.copy();
    case 'cut':
      c.cutSelected();
    case 'paste':
      c.paste();
    case 'rename':
      renameSelected(ctx, ref);
    case 'zip':
      c.compress(ArchiveFormat.zip);
    case 'extract':
      c.extractHere(s.selected.first);
    case 'vault':
      moveToVault(ctx, ref);
    case 'delete':
      deleteSelected(ctx, ref);
  }
}
