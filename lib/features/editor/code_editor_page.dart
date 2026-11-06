import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/notify/notify.dart';
import '../../core/settings/settings.dart';
import '../../core/theme/app_theme.dart';
import '../viewer/markdown_view.dart';
import '../viewer/viewers.dart';
import 'highlighter.dart';

/// Editor teks/kode: highlight sintaks, nomor baris, Tab, Ctrl+S, pratinjau Markdown,
/// buka HTML di browser, dan tombol Run untuk skrip (desktop).
class CodeEditorPage extends ConsumerStatefulWidget {
  const CodeEditorPage({super.key, required this.path});
  final String path;

  @override
  ConsumerState<CodeEditorPage> createState() => _CodeEditorPageState();
}

class _CodeEditorPageState extends ConsumerState<CodeEditorPage> {
  late final String _ext = p.extension(widget.path).toLowerCase().replaceFirst('.', '');
  CodeController? _c;
  final _focus = FocusNode();
  bool _loaded = false, _dirty = false, _preview = false, _running = false;
  String? _err;
  String _out = '';
  double _font = 14;

  bool get _isMd => _ext == 'md' || _ext == 'markdown';
  bool get _isHtml => _ext == 'html' || _ext == 'htm';
  (String, List<String>)? get _runner {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return null;
    return switch (_ext) {
      'py' => (Platform.isWindows ? 'python' : 'python3', const <String>[]),
      'js' || 'mjs' => ('node', const <String>[]),
      'dart' => ('dart', const ['run']),
      'sh' => ('bash', const <String>[]),
      'bat' || 'cmd' => ('cmd', const ['/c']),
      'ps1' => ('powershell', const ['-NoProfile', '-File']),
      'rb' => ('ruby', const <String>[]),
      'php' => ('php', const <String>[]),
      _ => null,
    };
  }

  @override
  void initState() {
    super.initState();
    _font = ref.read(settingsProvider).editorFont;
    _load();
  }

  @override
  void dispose() {
    _c?.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final f = File(widget.path);
      if (await f.length() > 5 * 1024 * 1024) throw 'File lebih dari 5 MB — dibuka dengan aplikasi lain saja';
      final text = utf8.decode(await f.readAsBytes(), allowMalformed: true);
      if (!mounted) return;
      final dark = Theme.of(context).brightness == Brightness.dark;
      setState(() {
        _c = CodeController(text: text, lang: Highlighter.langFor(_ext), dark: dark);
        _loaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  Future<void> _save() async {
    final c = _c;
    if (c == null) return;
    await File(widget.path).writeAsString(c.text);
    if (!mounted) return;
    setState(() => _dirty = false);
    ref.read(notifsProvider.notifier).push('Tersimpan', body: p.basename(widget.path), kind: NoteKind.success);
  }

  void _insertTab() {
    final c = _c!;
    final s = c.selection;
    if (!s.isValid) return;
    c.value = c.value.copyWith(
      text: c.text.replaceRange(s.start, s.end, '  '),
      selection: TextSelection.collapsed(offset: s.start + 2),
    );
    setState(() => _dirty = true);
  }

  Future<void> _run() async {
    final r = _runner;
    if (r == null) return;
    if (_dirty) await _save();
    setState(() {
      _running = true;
      _out = '\$ ${r.$1} ${[...r.$2, p.basename(widget.path)].join(' ')}\n';
    });
    try {
      final proc = await Process.start(r.$1, [...r.$2, p.basename(widget.path)],
          workingDirectory: p.dirname(widget.path), runInShell: Platform.isWindows);
      void add(String s) {
        if (mounted) setState(() => _out += s);
      }
      proc.stdout.transform(utf8.decoder).listen(add);
      proc.stderr.transform(utf8.decoder).listen(add);
      final code = await proc.exitCode.timeout(const Duration(seconds: 60), onTimeout: () {
        proc.kill();
        return -1;
      });
      add('\n[selesai, kode keluar $code]\n');
    } catch (e) {
      if (mounted) setState(() => _out += 'Gagal menjalankan: $e\n(pastikan interpreter terpasang & ada di PATH)\n');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Widget _editor(Pal pal) {
    final c = _c!;
    final style = TextStyle(fontFamily: 'Consolas', fontFamilyFallback: const ['Menlo', 'monospace'],
        fontSize: _font, height: 1.45);
    final strut = StrutStyle(fontSize: _font, height: 1.45, forceStrutHeight: true);
    return LayoutBuilder(builder: (ctx, cs) {
      final lines = c.text.split('\n');
      final charW = _font * 0.6;
      final longest = lines.fold<int>(0, (m, l) => max(m, l.length));
      final gutterW = lines.length.toString().length * charW + 28;
      final width = max(cs.maxWidth - gutterW, (longest + 6) * charW);
      return SingleChildScrollView(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: gutterW,
            padding: const EdgeInsets.fromLTRB(0, 12, 10, 12),
            color: pal.side,
            child: Text(
              List.generate(lines.length, (i) => '${i + 1}').join('\n'),
              textAlign: TextAlign.right,
              style: style.copyWith(color: pal.muted),
              strutStyle: strut,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: TextField(
                  controller: c,
                  focusNode: _focus,
                  maxLines: null,
                  style: style,
                  strutStyle: strut,
                  cursorColor: Theme.of(context).colorScheme.primary,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(8, 12, 12, 12),
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
              ),
            ),
          ),
        ]),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final canRun = _runner != null;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
        if (_loaded) const SingleActivator(LogicalKeyboardKey.tab): _insertTab,
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${p.basename(widget.path)}${_dirty ? '  •' : ''}', style: const TextStyle(fontSize: 15)),
          actions: [
            IconButton(
              tooltip: 'Perkecil',
              icon: const Icon(Icons.text_decrease_rounded),
              onPressed: () => setState(() => _font = (_font - 1).clamp(10.0, 28.0).toDouble()),
            ),
            IconButton(
              tooltip: 'Perbesar',
              icon: const Icon(Icons.text_increase_rounded),
              onPressed: () => setState(() => _font = (_font + 1).clamp(10.0, 28.0).toDouble()),
            ),
            if (_isMd)
              IconButton(
                tooltip: _preview ? 'Edit' : 'Pratinjau Markdown',
                icon: Icon(_preview ? Icons.edit_rounded : Icons.visibility_rounded),
                onPressed: () => setState(() => _preview = !_preview),
              ),
            if (_isHtml)
              IconButton(
                tooltip: 'Buka di browser',
                icon: const Icon(Icons.language_rounded),
                onPressed: () async {
                  if (_dirty) await _save();
                  await openExternally(widget.path);
                },
              ),
            if (canRun)
              IconButton(
                tooltip: 'Jalankan',
                icon: _running
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow_rounded),
                onPressed: _running ? null : _run,
              ),
            IconButton(
              tooltip: 'Simpan (Ctrl+S)',
              icon: const Icon(Icons.save_rounded),
              onPressed: _dirty ? _save : null,
            ),
          ],
        ),
        body: _err != null
            ? Center(child: Text(_err!))
            : !_loaded
                ? const Center(child: CircularProgressIndicator())
                : Column(children: [
                    Expanded(child: _preview ? MarkdownView(_c!.text) : _editor(pal)),
                    if (_out.isNotEmpty)
                      Container(
                        height: 170,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: pal.side,
                          border: Border(top: BorderSide(color: pal.border)),
                        ),
                        child: Stack(children: [
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: SelectableText(_out, style: const TextStyle(fontFamily: 'Consolas', fontFamilyFallback: ['monospace'], fontSize: 12.5)),
                          ),
                          Positioned(
                            right: 4,
                            top: 2,
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => setState(() => _out = ''),
                            ),
                          ),
                        ]),
                      ),
                  ]),
      ),
    );
  }
}
