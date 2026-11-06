import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Renderer Markdown ringan (tanpa paket): judul, daftar, kutipan, kode, garis, tebal/miring/kode/tautan.
class MarkdownView extends StatelessWidget {
  const MarkdownView(this.data, {super.key});
  final String data;

  static final _heading = RegExp(r'^(#{1,6})\s+(.*)$');
  static final _hr = RegExp(r'^\s*([-*_])(\s*\1){2,}\s*$');
  static final _item = RegExp(r'^(\s*)([-*+]|\d+\.)\s+(.*)$');
  static final _inline = RegExp(r'(\*\*[^*]+\*\*|__[^_]+__|\*[^*\n]+\*|`[^`\n]+`|\[[^\]]+\]\([^)]+\))');

  bool _startsBlock(String l) =>
      l.trimLeft().startsWith('```') || _heading.hasMatch(l) || _hr.hasMatch(l) ||
      _item.hasMatch(l) || l.startsWith('>');

  TextSpan _spans(String s, Pal pal, Color link) {
    final out = <InlineSpan>[];
    var last = 0;
    for (final m in _inline.allMatches(s)) {
      if (m.start > last) out.add(TextSpan(text: s.substring(last, m.start)));
      final t = m[0]!;
      if (t.startsWith('**') || t.startsWith('__')) {
        out.add(TextSpan(text: t.substring(2, t.length - 2), style: const TextStyle(fontWeight: FontWeight.w700)));
      } else if (t.startsWith('`')) {
        out.add(TextSpan(
          text: t.substring(1, t.length - 1),
          style: TextStyle(fontFamily: 'monospace', backgroundColor: pal.hover, color: link),
        ));
      } else if (t.startsWith('[')) {
        final end = t.indexOf('](');
        out.add(TextSpan(
          text: t.substring(1, end),
          style: TextStyle(color: link, decoration: TextDecoration.underline),
        ));
      } else {
        out.add(TextSpan(text: t.substring(1, t.length - 1), style: const TextStyle(fontStyle: FontStyle.italic)));
      }
      last = m.end;
    }
    if (last < s.length) out.add(TextSpan(text: s.substring(last)));
    return TextSpan(children: out);
  }

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final link = Theme.of(context).colorScheme.primary;
    final lines = data.split('\n');
    final out = <Widget>[];
    var i = 0;

    while (i < lines.length) {
      final l = lines[i];
      if (l.trimLeft().startsWith('```')) {
        final buf = <String>[];
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
          buf.add(lines[i]);
          i++;
        }
        i++;
        out.add(Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: pal.side, borderRadius: BorderRadius.circular(12), border: Border.all(color: pal.border)),
          child: SelectableText(buf.join('\n'), style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.45)),
        ));
        continue;
      }
      final h = _heading.firstMatch(l);
      if (h != null) {
        final lvl = h[1]!.length;
        const sizes = [30.0, 24.0, 20.0, 17.0, 15.0, 14.0];
        out.add(Padding(
          padding: EdgeInsets.only(top: lvl <= 2 ? 18 : 12, bottom: 6),
          child: Text.rich(_spans(h[2]!, pal, link),
              style: TextStyle(fontSize: sizes[lvl - 1], fontWeight: FontWeight.w800, height: 1.25)),
        ));
        i++;
        continue;
      }
      if (_hr.hasMatch(l)) {
        out.add(Divider(height: 28, color: pal.border));
        i++;
        continue;
      }
      if (l.startsWith('>')) {
        final buf = <String>[];
        while (i < lines.length && lines[i].startsWith('>')) {
          buf.add(lines[i].replaceFirst(RegExp(r'^>\s?'), ''));
          i++;
        }
        out.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: link, width: 3))),
          child: Text.rich(_spans(buf.join(' '), pal, link), style: TextStyle(color: pal.muted, height: 1.5)),
        ));
        continue;
      }
      final it = _item.firstMatch(l);
      if (it != null) {
        final bullet = RegExp(r'^\d').hasMatch(it[2]!) ? it[2]! : '•';
        out.add(Padding(
          padding: EdgeInsets.only(left: 6.0 + (it[1]!.length ~/ 2) * 16, top: 2, bottom: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 22, child: Text(bullet, style: TextStyle(color: pal.muted))),
            Expanded(child: Text.rich(_spans(it[3]!, pal, link), style: const TextStyle(height: 1.5))),
          ]),
        ));
        i++;
        continue;
      }
      if (l.trim().isEmpty) {
        i++;
        continue;
      }
      final buf = [l];
      i++;
      while (i < lines.length && lines[i].trim().isNotEmpty && !_startsBlock(lines[i])) {
        buf.add(lines[i]);
        i++;
      }
      out.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Text.rich(_spans(buf.join(' '), pal, link), style: const TextStyle(height: 1.6, fontSize: 15)),
      ));
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: SelectionArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 12, 24, 40), children: out),
        ),
      ),
    );
  }
}
