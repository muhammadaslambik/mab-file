import 'package:flutter/material.dart';

/// Pewarna sintaks ringan berbasis regex (tanpa paket). Cukup untuk
/// komentar, string, angka, tag HTML, dan kata kunci populer.
class Highlighter {
  static const _dq = r'"(?:\\.|[^"\\\n])*"';
  static const _sq = r"'(?:\\.|[^'\\\n])*'";
  static const _bt = r'`(?:\\.|[^`\\])*`';
  static const _cLike = r'//[^\n]*|/\*[\s\S]*?\*/';
  static const _hash = r'#[^\n]*';
  static const _num = r'\b\d+(?:\.\d+)?\b|\b0x[0-9a-fA-F]+\b';
  static const _word = r'[A-Za-z_$][A-Za-z0-9_$]*';

  static const _kwJs = {
    'const', 'let', 'var', 'function', 'return', 'if', 'else', 'for', 'while', 'do', 'switch', 'case', 'break',
    'continue', 'new', 'class', 'extends', 'import', 'export', 'from', 'default', 'async', 'await', 'try', 'catch',
    'finally', 'throw', 'typeof', 'instanceof', 'this', 'super', 'null', 'undefined', 'true', 'false', 'interface',
    'type', 'enum', 'implements', 'public', 'private', 'protected', 'static', 'readonly', 'of', 'in', 'yield',
  };
  static const _kwDart = {
    'abstract', 'as', 'async', 'await', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default', 'do',
    'else', 'enum', 'extends', 'extension', 'factory', 'false', 'final', 'finally', 'for', 'get', 'if', 'implements',
    'import', 'in', 'is', 'late', 'library', 'mixin', 'new', 'null', 'on', 'override', 'part', 'required', 'return',
    'set', 'static', 'super', 'switch', 'this', 'throw', 'true', 'try', 'typedef', 'var', 'void', 'while', 'with',
    'yield', 'int', 'double', 'String', 'bool', 'dynamic',
  };
  static const _kwPy = {
    'and', 'as', 'assert', 'async', 'await', 'break', 'class', 'continue', 'def', 'del', 'elif', 'else', 'except',
    'finally', 'for', 'from', 'global', 'if', 'import', 'in', 'is', 'lambda', 'None', 'nonlocal', 'not', 'or',
    'pass', 'raise', 'return', 'True', 'False', 'try', 'while', 'with', 'yield', 'self', 'print',
  };
  static const _kwC = {
    'abstract', 'auto', 'bool', 'break', 'byte', 'case', 'catch', 'char', 'class', 'const', 'continue', 'default',
    'do', 'double', 'else', 'enum', 'extends', 'false', 'final', 'finally', 'float', 'for', 'fn', 'func', 'go', 'if',
    'impl', 'import', 'in', 'int', 'interface', 'let', 'long', 'match', 'mut', 'namespace', 'new', 'null', 'nil',
    'package', 'private', 'protected', 'pub', 'public', 'return', 'short', 'static', 'struct', 'super', 'switch',
    'this', 'throw', 'throws', 'true', 'try', 'typedef', 'use', 'using', 'val', 'var', 'void', 'volatile', 'while',
    'fun', 'object', 'when',
  };
  static const _kwSh = {
    'if', 'then', 'else', 'elif', 'fi', 'for', 'while', 'do', 'done', 'case', 'esac', 'function', 'in', 'echo',
    'export', 'return', 'exit', 'true', 'false', 'null', 'yes', 'no', 'on', 'off',
  };
  static const _kwSql = {
    'select', 'from', 'where', 'insert', 'into', 'values', 'update', 'set', 'delete', 'create', 'table', 'drop',
    'alter', 'join', 'left', 'right', 'inner', 'outer', 'on', 'group', 'by', 'order', 'having', 'limit', 'and',
    'or', 'not', 'null', 'as', 'distinct', 'union', 'index', 'primary', 'key', 'foreign', 'references',
  };

  /// Peta ekstensi -> bahasa.
  static String langFor(String ext) => switch (ext) {
        'js' || 'mjs' || 'cjs' || 'jsx' => 'js',
        'ts' || 'tsx' => 'js',
        'dart' => 'dart',
        'py' => 'py',
        'java' || 'kt' || 'kts' || 'swift' || 'c' || 'h' || 'cpp' || 'cc' || 'hpp' || 'cs' || 'go' || 'rs' || 'gradle' || 'php' => 'c',
        'css' || 'scss' || 'less' => 'css',
        'html' || 'htm' || 'xml' || 'svg' || 'vue' || 'svelte' => 'html',
        'json' || 'jsonc' => 'json',
        'yaml' || 'yml' || 'toml' || 'ini' || 'cfg' || 'conf' || 'env' || 'properties' || 'sh' || 'bash' || 'zsh' || 'rb' || 'ps1' => 'sh',
        'sql' => 'sql',
        _ => 'plain',
      };

  static final _cache = <String, RegExp>{};

  static RegExp _re(String lang) => _cache.putIfAbsent(lang, () {
        final str = lang == 'py' ? '"""[\\s\\S]*?"""|\'\'\'[\\s\\S]*?\'\'\'|$_dq|$_sq' : (lang == 'js' || lang == 'c' || lang == 'dart') ? '$_dq|$_sq|$_bt' : '$_dq|$_sq';
        final com = switch (lang) {
          'js' || 'c' || 'dart' || 'css' => _cLike,
          'py' || 'sh' => _hash,
          'html' => r'<!--[\s\S]*?-->',
          'sql' => r'--[^\n]*|/\*[\s\S]*?\*/',
          _ => '(?!)',
        };
        final tag = lang == 'html' ? r'</?[A-Za-z][\w:-]*|/?>' : '(?!)';
        final css = lang == 'css' ? r'|#[0-9a-fA-F]{3,8}\b' : '';
        return RegExp('(?<c>$com)|(?<s>$str)|(?<t>$tag)|(?<n>$_num$css)|(?<w>$_word)');
      });

  static Set<String> _kw(String lang) => switch (lang) {
        'js' => _kwJs,
        'dart' => _kwDart,
        'py' => _kwPy,
        'c' => _kwC,
        'sh' => _kwSh,
        'sql' => _kwSql,
        'json' => const {'true', 'false', 'null'},
        _ => const {},
      };

  static List<TextSpan> spans(String src, String lang, bool dark) {
    final re = _re(lang);
    final kw = _kw(lang);
    final sql = lang == 'sql';
    final cComment = dark ? const Color(0xFF6A9955) : const Color(0xFF6B8E5A);
    final cString = dark ? const Color(0xFFCE9178) : const Color(0xFFB5502A);
    final cNum = dark ? const Color(0xFFB5CEA8) : const Color(0xFF2E8B57);
    final cTag = dark ? const Color(0xFF4FC1FF) : const Color(0xFF0B6FB8);
    final cKw = dark ? const Color(0xFFC586C0) : const Color(0xFF9B3FA8);
    final cType = dark ? const Color(0xFF4EC9B0) : const Color(0xFF1F8A75);

    final out = <TextSpan>[];
    var last = 0;
    for (final m in re.allMatches(src)) {
      if (m.start > last) out.add(TextSpan(text: src.substring(last, m.start)));
      final t = m[0]!;
      Color? col;
      if (m.namedGroup('c') != null) {
        col = cComment;
      } else if (m.namedGroup('s') != null) {
        col = cString;
      } else if (m.namedGroup('t') != null) {
        col = cTag;
      } else if (m.namedGroup('n') != null) {
        col = cNum;
      } else if (kw.contains(sql ? t.toLowerCase() : t)) {
        col = cKw;
      } else if (lang != 'json' && lang != 'plain' && t.codeUnitAt(0) >= 65 && t.codeUnitAt(0) <= 90) {
        col = cType;
      }
      out.add(TextSpan(text: t, style: col == null ? null : TextStyle(color: col)));
      last = m.end;
    }
    if (last < src.length) out.add(TextSpan(text: src.substring(last)));
    return out;
  }
}

/// TextEditingController yang mewarnai teks sambil mengetik.
class CodeController extends TextEditingController {
  CodeController({super.text, required this.lang, required this.dark});
  String lang;
  bool dark;

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (lang == 'plain' || text.length > 200000) return TextSpan(style: style, text: text);
    return TextSpan(style: style, children: Highlighter.spans(text, lang, dark));
  }
}
