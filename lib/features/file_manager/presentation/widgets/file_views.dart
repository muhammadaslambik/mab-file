import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../application/file_manager_state.dart';
import '../../domain/file_item.dart';
import '../file_actions.dart';
import 'glyph.dart';

/// Perilaku seleksi per platform:
/// - Desktop: klik = pilih, Ctrl/Cmd+klik = tambah, klik 2x = buka, klik kanan = menu.
/// - Mobile: ketuk = buka (atau pilih saat mode seleksi), tekan lama = pilih.
class ItemInteraction extends ConsumerWidget {
  const ItemInteraction({
    super.key,
    required this.item,
    required this.selected,
    required this.child,
    this.radius = 10,
  });

  final FileItem item;
  final bool selected;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = Pal.of(context);
    final c = ref.read(fmProvider.notifier);
    final desktop = isDesktopPlatform;

    void onDown(PointerDownEvent e) {
      if (!desktop) return;
      if (e.kind == PointerDeviceKind.mouse && e.buttons == kSecondaryMouseButton) {
        if (!selected) c.selectOnly(item.path);
        showItemMenu(context, ref, e.position);
        return;
      }
      final multi = HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      multi ? c.toggleSelect(item.path) : c.selectOnly(item.path);
    }

    return Listener(
      onPointerDown: onDown,
      child: Material(
        color: selected ? pal.select : Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          hoverColor: pal.hover,
          // Desktop: onTap kosong supaya menang atas klik "area kosong" di belakang.
          onTap: desktop
              ? () {}
              : () => ref.read(fmProvider).selecting
                  ? c.toggleSelect(item.path)
                  : openItem(context, ref, item),
          onLongPress: desktop ? null : () => c.toggleSelect(item.path),
          onDoubleTap: desktop ? () => openItem(context, ref, item) : null,
          child: child,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.searching});
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Opacity(opacity: 0.9, child: BrandLogo(size: 72)),
        const SizedBox(height: 12),
        Text(searching ? 'Tidak ada hasil' : 'Folder ini kosong',
            style: TextStyle(color: pal.muted, fontSize: 15)),
      ]),
    );
  }
}

// ---------------------------------------------------------------- DETAILS ---
class DetailsView extends ConsumerWidget {
  const DetailsView({super.key});

  static const _wDate = 160.0, _wType = 120.0, _wSize = 90.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(fmProvider);
    final c = ref.read(fmProvider.notifier);
    final pal = Pal.of(context);
    final items = s.visible;

    Widget head(String t, SortMode? m, double? w, {bool right = false}) {
      final active = m != null && s.sort == m;
      final label = Row(
        mainAxisAlignment: right ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Text(t,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: active ? Theme.of(context).colorScheme.primary : pal.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5)),
          ),
          if (active)
            Icon(s.asc ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                size: 16, color: Theme.of(context).colorScheme.primary),
        ],
      );
      final box = SizedBox(width: w, height: 34, child: Align(alignment: Alignment.centerLeft, child: label));
      final tap = InkWell(
        onTap: m == null ? null : () => c.setSort(m),
        hoverColor: pal.hover,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: box),
      );
      return w == null ? Expanded(child: tap) : tap;
    }

    return LayoutBuilder(builder: (ctx, cs) {
      final showType = cs.maxWidth > 760;
      final showDate = cs.maxWidth > 560;
      return Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            const SizedBox(width: 40),
            head('Nama', SortMode.name, null),
            if (showDate) head('Tanggal diubah', SortMode.date, _wDate),
            if (showType) head('Jenis', null, _wType),
            head('Ukuran', SortMode.size, _wSize, right: true),
          ]),
        ),
        Divider(height: 1, color: pal.border),
        Expanded(
          child: items.isEmpty && !s.loading
              ? EmptyState(searching: s.results != null)
              : GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: c.clearSelection,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    itemExtent: 44,
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final it = items[i];
                      return ItemInteraction(
                        item: it,
                        selected: s.selected.contains(it.path),
                        child: Row(children: [
                          const SizedBox(width: 8),
                          FileGlyph(it, size: 26),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(it.name, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          if (showDate)
                            SizedBox(
                              width: _wDate,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(formatDate(it.modified),
                                    style: TextStyle(color: pal.muted, fontSize: 12.5)),
                              ),
                            ),
                          if (showType)
                            SizedBox(
                              width: _wType,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(catLabel(it.category),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: pal.muted, fontSize: 12.5)),
                              ),
                            ),
                          SizedBox(
                            width: _wSize,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(it.isDir ? '' : formatBytes(it.size),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(color: pal.muted, fontSize: 12.5)),
                            ),
                          ),
                        ]),
                      );
                    },
                  ),
                ),
        ),
      ]);
    });
  }
}

// ------------------------------------------------------------------- GRID ---
class TilesView extends ConsumerWidget {
  const TilesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(fmProvider);
    final c = ref.read(fmProvider.notifier);
    final pal = Pal.of(context);
    final items = s.visible;
    if (items.isEmpty && !s.loading) return EmptyState(searching: s.results != null);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: c.clearSelection,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 150,
          mainAxisExtent: 148,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final it = items[i];
          final sel = s.selected.contains(it.path);
          return ItemInteraction(
            item: it,
            selected: sel,
            radius: 18,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: sel ? Theme.of(context).colorScheme.primary : pal.border,
                    width: sel ? 1.4 : 1),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
                child: Column(children: [
                  Expanded(child: Center(child: FileGlyph(it, size: 66, thumb: true))),
                  const SizedBox(height: 6),
                  Text(it.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, height: 1.15)),
                  const SizedBox(height: 2),
                  Text(it.isDir ? 'Folder' : formatBytes(it.size),
                      style: TextStyle(color: pal.muted, fontSize: 11)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------------- MOBILE LIST ---
class MobileList extends ConsumerWidget {
  const MobileList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(fmProvider);
    final pal = Pal.of(context);
    final cs = Theme.of(context).colorScheme;
    final items = s.visible;
    if (items.isEmpty && !s.loading) return EmptyState(searching: s.results != null);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
      itemExtent: 66,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        final sel = s.selected.contains(it.path);
        return ItemInteraction(
          item: it,
          selected: sel,
          radius: 16,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              FileGlyph(it, size: 46, thumb: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                          it.isDir
                              ? formatDate(it.modified)
                              : '${formatBytes(it.size)} • ${catLabel(it.category)}',
                          style: TextStyle(color: pal.muted, fontSize: 12.5)),
                    ]),
              ),
              if (s.selecting)
                Icon(sel ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: sel ? cs.primary : pal.muted),
            ]),
          ),
        );
      },
    );
  }
}
