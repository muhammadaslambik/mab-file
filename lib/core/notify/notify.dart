import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

enum NoteKind { info, success, error }

class AppNote {
  const AppNote(this.title, this.body, this.kind, this.time, {this.read = false});
  final String title, body;
  final NoteKind kind;
  final DateTime time;
  final bool read;
  AppNote asRead() => AppNote(title, body, kind, time, read: true);
}

/// Kunci global agar toast bisa ditampilkan dari mana saja (tanpa BuildContext).
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

class NotifController extends Notifier<List<AppNote>> {
  @override
  List<AppNote> build() => const [];

  void push(String title, {String body = '', NoteKind kind = NoteKind.info, bool toast = true}) {
    state = [AppNote(title, body, kind, DateTime.now()), ...state].take(100).toList();
    if (!toast) return;
    final m = rootMessengerKey.currentState;
    if (m == null) return;
    final desktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    m
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        width: desktop ? 380 : null,
        margin: desktop ? null : const EdgeInsets.fromLTRB(16, 0, 16, 90),
        duration: const Duration(seconds: 3),
        // Builder: konteks di dalam Scaffold sudah berada di bawah Theme (warna tema benar)
        content: Builder(builder: (c) {
          final pal = Pal.of(c);
          final (icon, color) = switch (kind) {
            NoteKind.success => (Icons.check_circle_rounded, const Color(0xFF34D399)),
            NoteKind.error => (Icons.error_rounded, const Color(0xFFFF5C7A)),
            NoteKind.info => (Icons.info_rounded, pal.accentA),
          };
          return Row(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: pal.text, fontWeight: FontWeight.w700)),
                  if (body.isNotEmpty)
                    Text(body, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: pal.muted, fontSize: 12.5)),
                ],
              ),
            ),
          ]);
        }),
      ));
  }

  void markAllRead() => state = [for (final n in state) n.asRead()];
  void clear() => state = const [];
}

final notifsProvider = NotifierProvider<NotifController, List<AppNote>>(NotifController.new);

/// Ikon lonceng + badge; ketuk untuk melihat riwayat notifikasi.
class NotifBell extends ConsumerWidget {
  const NotifBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notifsProvider).where((n) => !n.read).length;
    return IconButton(
      tooltip: 'Notifikasi',
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Pal.of(context).card,
          constraints: const BoxConstraints(maxWidth: 520),
          builder: (_) => const _NotifSheet(),
        );
        ref.read(notifsProvider.notifier).markAllRead();
      },
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_none_rounded, size: 21),
      ),
    );
  }
}

class _NotifSheet extends ConsumerWidget {
  const _NotifSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(notifsProvider);
    final pal = Pal.of(context);
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
          child: Row(children: [
            const Text('Notifikasi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton(onPressed: ref.read(notifsProvider.notifier).clear, child: const Text('Bersihkan')),
          ]),
        ),
        Flexible(
          child: list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text('Belum ada notifikasi', style: TextStyle(color: pal.muted)))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final n = list[i];
                    final icon = switch (n.kind) {
                      NoteKind.success => Icons.check_circle_rounded,
                      NoteKind.error => Icons.error_rounded,
                      NoteKind.info => Icons.info_rounded,
                    };
                    return ListTile(
                      leading: Icon(icon, color: n.kind == NoteKind.error ? const Color(0xFFFF5C7A)
                          : n.kind == NoteKind.success ? const Color(0xFF34D399) : pal.accentA),
                      title: Text(n.title),
                      subtitle: n.body.isEmpty ? null : Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Text(
                        '${n.time.hour.toString().padLeft(2, '0')}:${n.time.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(color: pal.muted, fontSize: 12),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
