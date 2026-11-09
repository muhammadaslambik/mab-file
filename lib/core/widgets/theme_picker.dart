import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_info.dart';
import '../notify/notify.dart';
import '../settings/settings.dart';
import '../theme/app_theme.dart';
import '../utils/app_log.dart';

Future<void> showThemePicker(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => const Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(16),
        child: _PickerBody(),
      ),
    );

String _videoChoice(String m) {
  if (m == 'native') return Platform.isWindows ? 'native' : 'auto';
  return const {'auto', 'system', 'builtin'}.contains(m) ? m : 'auto';
}

String _hwdecChoice(String m) =>
    const {'default', 'auto', 'd3d11va', 'd3d11va-copy', 'no'}.contains(m) ? m : 'default';

class _PickerBody extends ConsumerWidget {
  const _PickerBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final pal = Pal.of(context);
    final ctl = ref.read(settingsProvider.notifier);

    void pick(String id) {
      final t = id == 'auto' ? null : themeById(id);
      ctl.update(s.copyWith(themeId: id, animated: t?.animated ?? false));
    }

    Widget section(String title, Iterable<MabTheme> list) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
              child: Text(title, style: TextStyle(color: pal.muted, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ),
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (final t in list)
                _Preview(t: t, selected: s.themeId == t.id, onTap: () => pick(t.id)),
            ]),
          ],
        );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
      child: Material(
        color: pal.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: pal.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Text('Tema', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ]),
          Flexible(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => pick('auto'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: s.themeId == 'auto' ? Theme.of(context).colorScheme.primary : pal.border,
                            width: s.themeId == 'auto' ? 1.6 : 1),
                      ),
                      child: Row(children: [
                        const Icon(Icons.brightness_auto_rounded),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Otomatis — Porcelain (siang) / Aurora (malam), ikut sistem')),
                        if (s.themeId == 'auto') const Icon(Icons.check_circle_rounded),
                      ]),
                    ),
                  ),
                ),
                section('GELAP', kThemes.where((t) => t.dark && !t.animated)),
                section('TERANG', kThemes.where((t) => !t.dark && !t.animated)),
                section('ANIMASI (latar bergerak halus)', kThemes.where((t) => t.animated)),
              ]),
            ),
          ),
          const Divider(),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Animasi latar'),
            subtitle: Text('Matikan untuk performa & baterai maksimal', style: TextStyle(color: pal.muted, fontSize: 12)),
            value: s.animated,
            onChanged: (v) => ctl.update(s.copyWith(animated: v)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Pemutar video'),
                  Text('Otomatis: mesin Windows di Windows, pemutar sistem di Linux/macOS, MAB (mpv) di HP.',
                      style: TextStyle(color: pal.muted, fontSize: 12)),
                ]),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _videoChoice(s.videoMode),
                underline: const SizedBox.shrink(),
                onChanged: (v) {
                  if (v != null) ctl.update(s.copyWith(videoMode: v));
                },
                items: [
                  const DropdownMenuItem(value: 'auto', child: Text('Otomatis')),
                  const DropdownMenuItem(value: 'system', child: Text('Pemutar sistem')),
                  const DropdownMenuItem(value: 'builtin', child: Text('MAB (mpv)')),
                  if (Platform.isWindows) const DropdownMenuItem(value: 'native', child: Text('Windows asli (hemat)')),
                ],
              ),
            ]),
          ),
          if (Platform.isWindows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Dekode video mpv (eksperimen)'),
                    Text('Hanya jalur mpv. Hasilnya terlihat di CPU/GPU Task Manager dan di info diagnostik.',
                        style: TextStyle(color: pal.muted, fontSize: 12)),
                  ]),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _hwdecChoice(s.mpvHwdec),
                  underline: const SizedBox.shrink(),
                  onChanged: (v) {
                    if (v != null) ctl.update(s.copyWith(mpvHwdec: v));
                  },
                  items: const [
                    DropdownMenuItem(value: 'default', child: Text('Bawaan')),
                    DropdownMenuItem(value: 'auto', child: Text('Otomatis mpv')),
                    DropdownMenuItem(value: 'd3d11va', child: Text('D3D11 langsung')),
                    DropdownMenuItem(value: 'd3d11va-copy', child: Text('D3D11 + salin')),
                    DropdownMenuItem(value: 'no', child: Text('Perangkat lunak')),
                  ],
                ),
              ]),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(spacing: 8, children: [
              TextButton.icon(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'MAB-File',
                  applicationVersion: kAppVersion,
                ),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('Lisensi pihak ketiga'),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: AppLog.diagnostics()));
                  ref.read(notifsProvider.notifier).push('Info diagnostik disalin',
                      body: 'Periksa isinya (bisa memuat nama folder) sebelum dibagikan.',
                      kind: NoteKind.success);
                },
                icon: const Icon(Icons.bug_report_outlined, size: 18),
                label: const Text('Salin info diagnostik'),
              ),
            ]),
          ),
        ]),
        ),
      ),
    );
  }
}

/// Kartu pratinjau mini: sidebar + baris file + pil aksen, memakai palet tema itu sendiri.
class _Preview extends StatelessWidget {
  const _Preview({required this.t, required this.selected, required this.onTap});
  final MabTheme t;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = t.pal;
    Widget bar(double w, [Color? c]) => Container(
        width: w, height: 6, margin: const EdgeInsets.only(bottom: 5),
        decoration: BoxDecoration(color: c ?? p.muted.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(3)));
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 186,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 96,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: p.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected ? t.primary : p.border, width: selected ? 2 : 1),
            ),
            child: Row(children: [
              Container(
                width: 52, color: p.side, padding: const EdgeInsets.all(8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 14, height: 14, margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(gradient: p.gradient, borderRadius: BorderRadius.circular(4))),
                  bar(30, t.primary), bar(24), bar(28),
                ]),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 40, height: 10, margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(gradient: p.gradient, borderRadius: BorderRadius.circular(5))),
                    for (var i = 0; i < 3; i++)
                      Container(
                        height: 12, margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: i == 1 ? p.select : p.card, borderRadius: BorderRadius.circular(4)),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
            child: Row(children: [
              Expanded(child: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700))),
              if (selected) Icon(Icons.check_circle_rounded, size: 18, color: t.primary),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(t.tag, style: TextStyle(fontSize: 11, color: Pal.of(context).muted)),
          ),
        ]),
      ),
    );
  }
}
