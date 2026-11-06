import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/notify/notify.dart';
import '../../archive/archive_service.dart';
import '../../editor/code_editor_page.dart';
import '../../editor/image_editor_page.dart';
import '../../editor/media_studio_page.dart';
import '../../player/media_page.dart';
import '../../player/player_hub.dart';
import '../../vault/vault_page.dart';
import '../../viewer/office_page.dart';
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

/// Mendeteksi file teks walau ekstensinya tidak dikenal (cek 4 KB pertama).
Future<bool> looksLikeText(String path) async {
  try {
    final raf = await File(path).open();
    final b = await raf.read(4096);
    await raf.close();
    if (b.isEmpty) return true;
    if (b.contains(0)) return false;
    var bad = 0;
    for (final c in b) {
      if (c < 9 || (c > 13 && c < 32)) bad++;
    }
    return bad / b.length < 0.05;
  } catch (_) {
    return false;
  }
}

/// Router pembuka file: tiap jenis punya viewer bawaan; sisanya ke aplikasi default OS.
void openItem(BuildContext ctx, WidgetRef ref, FileItem it) {
  final c = ref.read(fmProvider.notifier);
  if (it.isDir) {
    c.open(it.path);
    return;
  }
  final st = ref.read(fmProvider);
  final ext = p.extension(it.path).toLowerCase().replaceFirst('.', '');
  void push(Widget w) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => w));
  List<String> sibs(FileCategory cat) =>
      [for (final i in st.visible) if (!i.isDir && i.category == cat) i.path];

  switch (it.category) {
    case FileCategory.image:
      push(ImageViewerPage(path: it.path, siblings: sibs(FileCategory.image)));
    case FileCategory.video:
      push(MediaPage(path: it.path, playlist: sibs(FileCategory.video)));
    case FileCategory.audio:
      push(MediaPage(path: it.path, playlist: sibs(FileCategory.audio), audio: true));
    case FileCategory.code:
      push(CodeEditorPage(path: it.path));
    case FileCategory.archive:
      c.extractHere(it.path);
    case FileCategory.document:
      if (officeExts.contains(ext)) {
        push(OfficePage(path: it.path));
      } else {
        openExternally(it.path);
      }
    default:
      looksLikeText(it.path).then((isText) {
        if (!ctx.mounted) return;
        isText ? push(CodeEditorPage(path: it.path)) : openExternally(it.path);
      });
  }
}

void openSelected(BuildContext ctx, WidgetRef ref) {
  final s = ref.read(fmProvider);
  if (s.selected.length == 1 && s.selectedItems.isNotEmpty) {
    openItem(ctx, ref, s.selectedItems.first);
  }
}

void openSelectedExternally(BuildContext ctx, WidgetRef ref) {
  final s = ref.read(fmProvider);
  if (s.selected.length == 1) openExternally(s.selected.first);
}

bool isMediaItem(FileItem i) =>
    !i.isDir && (i.category == FileCategory.audio || i.category == FileCategory.video);

/// Path audio/video dari item terpilih (urut sesuai daftar). Folder terpilih = isi medianya.
List<String> selectedMediaPaths(WidgetRef ref) {
  final s = ref.read(fmProvider);
  final out = <String>[];
  for (final it in s.visible) {
    if (!s.selected.contains(it.path)) continue;
    if (isMediaItem(it)) {
      out.add(it.path);
    } else if (it.isDir) {
      try {
        final files = Directory(it.path)
            .listSync(followLinks: false)
            .whereType<File>()
            .map((f) => f.path)
            .where((f) {
              final c = categoryOf(f);
              return c == FileCategory.audio || c == FileCategory.video;
            })
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        out.addAll(files);
      } catch (_) {}
    }
  }
  return out;
}

/// Putar item terpilih sebagai playlist (berurutan). Audio berjalan di latar (MiniPlayer).
Future<void> playSelection(BuildContext ctx, WidgetRef ref) async {
  final list = selectedMediaPaths(ref);
  if (list.isEmpty) {
    ref.read(notifsProvider.notifier).push('Pilih file audio/video dulu');
    return;
  }
  await ref.read(playerHubProvider).playAll(list);
  ref.read(notifsProvider.notifier).push('Memutar ${list.length} item', body: 'Kontrol ada di pemutar mini di bawah');
  if (ctx.mounted && categoryOf(list.first) == FileCategory.video) {
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => const MediaPage()));
  }
}

Future<void> enqueueSelection(BuildContext ctx, WidgetRef ref) async {
  final list = selectedMediaPaths(ref);
  if (list.isEmpty) {
    ref.read(notifsProvider.notifier).push('Pilih file audio/video dulu');
    return;
  }
  await ref.read(playerHubProvider).enqueue(list);
  ref.read(notifsProvider.notifier).push('Ditambahkan ke antrean', body: '${list.length} item', kind: NoteKind.success);
}

/// Edit sesuai jenis: gambar -> editor gambar, audio/video -> Studio Media, teks -> editor kode.
void editItem(BuildContext ctx, WidgetRef ref, FileItem it) {
  void push(Widget w) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => w));
  switch (it.category) {
    case FileCategory.image:
      push(ImageEditorPage(path: it.path));
    case FileCategory.video || FileCategory.audio:
      push(MediaStudioPage(path: it.path));
    case FileCategory.code:
      push(CodeEditorPage(path: it.path));
    default:
      ref.read(notifsProvider.notifier).push('Belum ada editor bawaan',
          body: 'Gunakan "Buka dengan aplikasi lain" untuk ${p.basename(it.path)}');
  }
}

void editSelected(BuildContext ctx, WidgetRef ref) {
  final s = ref.read(fmProvider);
  if (s.selected.length == 1 && s.selectedItems.isNotEmpty) {
    editItem(ctx, ref, s.selectedItems.first);
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
    ref.read(notifsProvider.notifier).push('Buka Vault terlebih dulu', body: 'Masuk ke tab Vault dan masukkan PIN');
    ref.read(navIndexProvider.notifier).set(2);
    return;
  }
  final c = ref.read(fmProvider.notifier);
  for (final path in ref.read(fmProvider).selected) {
    if (FileSystemEntity.typeSync(path) != FileSystemEntityType.file) continue;
    await v.addFile(path);
  }
  ref.read(notifsProvider.notifier).push('Dipindahkan ke Vault', kind: NoteKind.success);
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
  final first = single && s.selectedItems.isNotEmpty ? s.selectedItems.first : null;
  final isArchive = first?.category == FileCategory.archive;
  final editLabel = switch (first?.category) {
    FileCategory.image => 'Edit gambar',
    FileCategory.video || FileCategory.audio => 'Studio Media (konversi/potong)',
    FileCategory.code => 'Edit teks / kode',
    _ => null,
  };

  final hasMedia = s.selectedItems.any((i) => isMediaItem(i) || i.isDir);

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
      if (hasMedia) it('play', Icons.play_circle_outline_rounded, 'Putar sebagai playlist'),
      if (hasMedia) it('enqueue', Icons.queue_music_rounded, 'Tambah ke antrean'),
      if (editLabel != null) it('edit', Icons.auto_fix_high_rounded, editLabel),
      if (single && first != null && !first.isDir) it('ext', Icons.launch_rounded, 'Buka dengan aplikasi lain'),
      const PopupMenuDivider(),
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
    case 'play':
      playSelection(ctx, ref);
    case 'enqueue':
      enqueueSelection(ctx, ref);
    case 'edit':
      editSelected(ctx, ref);
    case 'ext':
      openSelectedExternally(ctx, ref);
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
