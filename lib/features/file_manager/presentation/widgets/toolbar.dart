import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/theme/app_theme.dart';
import '../../application/file_manager_state.dart';

/// Panah mundur / maju / naik, seperti Explorer.
class NavButtons extends ConsumerWidget {
  const NavButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(fmProvider);
    final c = ref.read(fmProvider.notifier);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
          tooltip: 'Kembali (Alt+←)',
          onPressed: s.canBack ? c.back : null,
          icon: const Icon(Icons.arrow_back_rounded, size: 20)),
      IconButton(
          tooltip: 'Maju (Alt+→)',
          onPressed: s.canForward ? c.forward : null,
          icon: const Icon(Icons.arrow_forward_rounded, size: 20)),
      IconButton(
          tooltip: 'Naik satu level (Alt+↑)',
          onPressed: p.dirname(s.path) == s.path ? null : c.up,
          icon: const Icon(Icons.arrow_upward_rounded, size: 20)),
    ]);
  }
}

/// Alamat berbentuk "pil" dengan segmen yang bisa diklik; klik area kosong = ketik manual.
class Breadcrumb extends ConsumerStatefulWidget {
  const Breadcrumb({super.key});
  @override
  ConsumerState<Breadcrumb> createState() => _BreadcrumbState();
}

class _BreadcrumbState extends ConsumerState<Breadcrumb> {
  bool _editing = false;
  final _ctl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = ref.watch(fmProvider.select((s) => s.path));
    final c = ref.read(fmProvider.notifier);
    final pal = Pal.of(context);
    final cs = Theme.of(context).colorScheme;

    final parts = path.isEmpty ? <String>[] : p.split(path);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _editing ? cs.primary : pal.border),
      ),
      child: _editing
          ? Row(children: [
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ctl,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                  onSubmitted: (v) {
                    setState(() => _editing = false);
                    c.openPath(v);
                  },
                  onTapOutside: (_) => setState(() => _editing = false),
                ),
              ),
            ])
          : Row(children: [
              Icon(Platform.isAndroid ? Icons.phone_android_rounded : Icons.computer_rounded,
                  size: 16, color: pal.muted),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() {
                    _ctl.text = path;
                    _editing = true;
                  }),
                  child: SingleChildScrollView(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (var i = 0; i < parts.length; i++) ...[
                        Icon(Icons.chevron_right_rounded, size: 18, color: pal.muted),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          hoverColor: pal.hover,
                          onTap: () => c.open(p.joinAll(parts.sublist(0, i + 1))),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Text(
                              parts[i].replaceAll(RegExp(r'[\\/]+$'), '').isEmpty
                                  ? parts[i]
                                  : parts[i].replaceAll(RegExp(r'[\\/]+$'), ''),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: i == parts.length - 1 ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
            ]),
    );
  }
}

/// Kolom pencarian (Enter = deep search rekursif).
class SearchField extends ConsumerStatefulWidget {
  const SearchField({super.key, this.hint = 'Cari di folder ini…'});
  final String hint;
  @override
  ConsumerState<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<SearchField> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    ref.listen(fmProvider.select((s) => s.query), (_, q) {
      if (q.isEmpty && _ctl.text.isNotEmpty) _ctl.clear();
    });
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Row(children: [
        Icon(Icons.search_rounded, size: 19, color: pal.muted),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _ctl,
            style: const TextStyle(fontSize: 13.5),
            textInputAction: TextInputAction.search,
            onSubmitted: ref.read(fmProvider.notifier).search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(color: pal.muted, fontSize: 13.5),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        if (_ctl.text.isNotEmpty)
          InkWell(
            onTap: () {
              _ctl.clear();
              ref.read(fmProvider.notifier).search('');
              setState(() {});
            },
            child: Icon(Icons.close_rounded, size: 18, color: pal.muted),
          ),
      ]),
    );
  }
}

/// Segmen Details | Grid.
class ViewToggle extends ConsumerWidget {
  const ViewToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(fmProvider.select((s) => s.view));
    final c = ref.read(fmProvider.notifier);
    final pal = Pal.of(context);

    Widget seg(ViewMode m, IconData i, String tip) => Tooltip(
          message: tip,
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => c.setView(m),
            child: Container(
              width: 36,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: v == m ? pal.gradient : null,
              ),
              child: Icon(i, size: 18, color: v == m ? Colors.white : pal.muted),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg(ViewMode.details, Icons.view_list_rounded, 'Rincian'),
        seg(ViewMode.grid, Icons.grid_view_rounded, 'Ubin'),
      ]),
    );
  }
}

class SortMenu extends ConsumerWidget {
  const SortMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(fmProvider);
    final c = ref.read(fmProvider.notifier);
    return PopupMenuButton<Object>(
      tooltip: 'Urutkan & opsi',
      icon: const Icon(Icons.tune_rounded, size: 20),
      onSelected: (v) {
        if (v is SortMode) c.setSort(v);
        if (v == 'hidden') c.toggleHidden();
      },
      itemBuilder: (_) => [
        for (final m in SortMode.values)
          CheckedPopupMenuItem<Object>(
            value: m,
            checked: s.sort == m,
            child: Text(switch (m) {
              SortMode.name => 'Nama',
              SortMode.size => 'Ukuran',
              SortMode.date => 'Tanggal diubah',
            }),
          ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem<Object>(
            value: 'hidden', checked: s.showHidden, child: const Text('File tersembunyi')),
      ],
    );
  }
}
