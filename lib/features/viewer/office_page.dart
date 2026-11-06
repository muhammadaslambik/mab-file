import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../../core/theme/app_theme.dart';
import 'markdown_view.dart';
import 'viewers.dart';

class SheetData {
  const SheetData(this.name, this.rows);
  final String name;
  final List<List<String>> rows;
}

class OfficeDoc {
  const OfficeDoc(this.markdown, this.sheets);
  final String markdown;
  final List<SheetData> sheets;
}

const officeExts = {'docx', 'xlsx', 'pptx', 'odt', 'ods', 'odp'};

String? _read(Archive a, String name) {
  final f = a.findFile(name);
  return f == null ? null : utf8.decode(f.content as List<int>, allowMalformed: true);
}

Iterable<XmlElement> _els(XmlNode n, String local) =>
    n.descendants.whereType<XmlElement>().where((e) => e.name.local == local);

String _text(XmlNode n, {Set<String> textTags = const {'t'}}) {
  final b = StringBuffer();
  for (final e in n.descendants.whereType<XmlElement>()) {
    final l = e.name.local;
    if (textTags.contains(l) && e.children.whereType<XmlText>().isNotEmpty) {
      b.write(e.innerText);
    } else if (l == 'tab') {
      b.write('\t');
    } else if (l == 'br') {
      b.write('\n');
    }
  }
  return b.toString();
}

int _colIndex(String ref) {
  var n = 0;
  for (final c in ref.codeUnits) {
    if (c >= 65 && c <= 90) {
      n = n * 26 + (c - 64);
    } else {
      break;
    }
  }
  return n - 1;
}

int _num(String s) => int.tryParse(RegExp(r'(\d+)').firstMatch(s)?[1] ?? '') ?? 0;

/// Pratinjau teks dari docx/xlsx/pptx/odt/ods/odp (format asli: ZIP + XML). Berjalan di Isolate.
OfficeDoc parseOffice(String path) {
  final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
  final a = ZipDecoder().decodeBytes(File(path).readAsBytesSync());

  switch (ext) {
    case 'docx':
      final xml = _read(a, 'word/document.xml');
      if (xml == null) throw 'document.xml tidak ditemukan';
      final doc = XmlDocument.parse(xml);
      final body = _els(doc, 'body').first;
      final md = StringBuffer();
      for (final n in body.children.whereType<XmlElement>()) {
        if (n.name.local == 'p') {
          final t = _text(n).trim();
          if (t.isEmpty) continue;
          final style = _els(n, 'pStyle').map((e) => e.getAttribute('w:val') ?? e.getAttribute('val') ?? '').firstOrNull ?? '';
          final h = RegExp(r'[Hh]eading(\d)').firstMatch(style);
          final isList = _els(n, 'numPr').isNotEmpty;
          if (h != null) {
            md.writeln('${'#' * (int.parse(h[1]!).clamp(1, 6).toInt())} $t\n');
          } else if (style == 'Title') {
            md.writeln('# $t\n');
          } else if (isList) {
            md.writeln('- $t');
          } else {
            md.writeln('$t\n');
          }
        } else if (n.name.local == 'tbl') {
          for (final tr in _els(n, 'tr')) {
            md.writeln(_els(tr, 'tc').map((c) => _text(c).trim()).join('  |  '));
          }
          md.writeln();
        }
      }
      return OfficeDoc(md.toString(), const []);

    case 'pptx':
      final slides = a.files
          .where((f) => RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(f.name))
          .toList()
        ..sort((x, y) => _num(x.name).compareTo(_num(y.name)));
      final md = StringBuffer();
      var n = 1;
      for (final f in slides) {
        final doc = XmlDocument.parse(utf8.decode(f.content as List<int>, allowMalformed: true));
        md.writeln('## Slide $n\n');
        for (final para in _els(doc, 'p')) {
          final t = _text(para).trim();
          if (t.isNotEmpty) md.writeln('- $t');
        }
        md.writeln();
        n++;
      }
      return OfficeDoc(md.toString(), const []);

    case 'xlsx':
      final shared = <String>[];
      final ss = _read(a, 'xl/sharedStrings.xml');
      if (ss != null) {
        for (final si in _els(XmlDocument.parse(ss), 'si')) {
          shared.add(_text(si));
        }
      }
      final names = <String>[];
      final wb = _read(a, 'xl/workbook.xml');
      if (wb != null) {
        for (final s in _els(XmlDocument.parse(wb), 'sheet')) {
          names.add(s.getAttribute('name') ?? 'Sheet');
        }
      }
      final files = a.files
          .where((f) => RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(f.name))
          .toList()
        ..sort((x, y) => _num(x.name).compareTo(_num(y.name)));
      final sheets = <SheetData>[];
      for (var i = 0; i < files.length; i++) {
        final doc = XmlDocument.parse(utf8.decode(files[i].content as List<int>, allowMalformed: true));
        final rows = <List<String>>[];
        for (final r in _els(doc, 'row')) {
          if (rows.length >= 500) break;
          final row = <String>[];
          for (final c in _els(r, 'c')) {
            final idx = _colIndex(c.getAttribute('r') ?? 'A1').clamp(0, 60).toInt();
            while (row.length <= idx) {
              row.add('');
            }
            final t = c.getAttribute('t');
            final v = _els(c, 'v').map((e) => e.innerText).firstOrNull ?? '';
            if (t == 's') {
              final k = int.tryParse(v) ?? -1;
              row[idx] = (k >= 0 && k < shared.length) ? shared[k] : '';
            } else if (t == 'inlineStr') {
              row[idx] = _text(c);
            } else {
              row[idx] = v;
            }
          }
          rows.add(row);
        }
        sheets.add(SheetData(i < names.length ? names[i] : 'Sheet ${i + 1}', rows));
      }
      return OfficeDoc('', sheets);

    case 'odt' || 'odp' || 'ods':
      final xml = _read(a, 'content.xml');
      if (xml == null) throw 'content.xml tidak ditemukan';
      final doc = XmlDocument.parse(xml);
      if (ext == 'ods') {
        final sheets = <SheetData>[];
        for (final t in _els(doc, 'table')) {
          final rows = <List<String>>[];
          for (final r in _els(t, 'table-row')) {
            if (rows.length >= 500) break;
            rows.add([for (final c in _els(r, 'table-cell')) _els(c, 'p').map((e) => e.innerText).join(' ')]);
          }
          sheets.add(SheetData(t.getAttribute('table:name') ?? 'Sheet', rows));
        }
        return OfficeDoc('', sheets);
      }
      final md = StringBuffer();
      for (final e in doc.descendants.whereType<XmlElement>()) {
        if (e.name.local == 'h') md.writeln('## ${e.innerText}\n');
        if (e.name.local == 'p' && e.parent is XmlElement && (e.parent as XmlElement).name.local != 'table-cell') {
          final t = e.innerText.trim();
          if (t.isNotEmpty) md.writeln('$t\n');
        }
      }
      return OfficeDoc(md.toString(), const []);
  }
  throw 'Format tidak didukung';
}

class OfficePage extends StatelessWidget {
  const OfficePage({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(path), style: const TextStyle(fontSize: 15)),
        actions: [
          TextButton.icon(
            onPressed: () => openExternally(path),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Buka di aplikasi Office'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<OfficeDoc>(
        future: Isolate.run(() => parseOffice(path)),
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Gagal membaca dokumen: ${snap.error}'));
          }
          final d = snap.data!;
          return Column(children: [
            Container(
              width: double.infinity,
              color: pal.select,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Pratinjau teks — gambar, grafik, dan format lengkap hanya tampil di aplikasi Office.',
                  style: TextStyle(color: pal.muted, fontSize: 12.5)),
            ),
            Expanded(
              child: d.sheets.isNotEmpty
                  ? DefaultTabController(
                      length: d.sheets.length,
                      child: Column(children: [
                        TabBar(isScrollable: true, tabs: [for (final s in d.sheets) Tab(text: s.name)]),
                        Expanded(child: TabBarView(children: [for (final s in d.sheets) _SheetTable(s)])),
                      ]),
                    )
                  : MarkdownView(d.markdown.isEmpty ? '_(dokumen kosong)_' : d.markdown),
            ),
          ]);
        },
      ),
    );
  }
}

class _SheetTable extends StatelessWidget {
  const _SheetTable(this.s);
  final SheetData s;

  static String _letter(int i) {
    var n = i + 1;
    var out = '';
    while (n > 0) {
      out = String.fromCharCode(65 + (n - 1) % 26) + out;
      n = (n - 1) ~/ 26;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final cols = s.rows.fold<int>(1, (m, r) => r.length > m ? r.length : m);
    const w = 130.0;
    Widget cell(String t, {bool head = false}) => Container(
          width: w,
          height: 32,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: head ? pal.side : null,
            border: Border(right: BorderSide(color: pal.border), bottom: BorderSide(color: pal.border)),
          ),
          child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: head ? FontWeight.w700 : FontWeight.w400,
                  color: head ? pal.muted : null)),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: cols * w + 1,
        child: Column(children: [
          Row(children: [for (var c = 0; c < cols; c++) cell(_letter(c), head: true)]),
          Expanded(
            child: ListView.builder(
              itemExtent: 32,
              itemCount: s.rows.length,
              itemBuilder: (_, r) => Row(children: [
                for (var c = 0; c < cols; c++) cell(c < s.rows[r].length ? s.rows[r][c] : ''),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
