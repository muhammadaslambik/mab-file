import 'package:path/path.dart' as p;

enum FileCategory { folder, document, image, video, audio, apk, archive, code, other }

const _ext = <FileCategory, Set<String>>{
  FileCategory.document: {'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods', 'odp', 'rtf', 'epub', 'pages', 'numbers', 'key'},
  FileCategory.image: {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'wbmp', 'heic', 'heif', 'avif', 'svg', 'ico', 'tif', 'tiff', 'tga', 'psd', 'raw', 'dng', 'cr2', 'nef'},
  FileCategory.video: {'mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', 'wmv', '3gp', 'm4v', 'mpg', 'mpeg', 'm2ts', 'mts', 'ogv', 'vob', 'divx', 'rm', 'rmvb', 'asf'},
  FileCategory.audio: {'mp3', 'wav', 'flac', 'aac', 'ogg', 'oga', 'm4a', 'opus', 'wma', 'aiff', 'aif', 'amr', 'mid', 'midi', 'ape', 'alac', 'ac3', 'mka', 'wv'},
  FileCategory.apk: {'apk', 'xapk', 'aab'},
  FileCategory.archive: {'zip', 'rar', '7z', 'tar', 'gz', 'tgz', 'bz2', 'xz', 'zst', 'iso', 'cab'},
  FileCategory.code: {
    'txt', 'md', 'markdown', 'rst', 'log', 'csv', 'tsv', 'json', 'jsonc', 'yaml', 'yml', 'toml', 'xml', 'ini', 'cfg', 'conf', 'env', 'properties',
    'html', 'htm', 'css', 'scss', 'less', 'js', 'mjs', 'cjs', 'jsx', 'ts', 'tsx', 'vue', 'svelte',
    'dart', 'py', 'java', 'kt', 'kts', 'swift', 'c', 'h', 'cpp', 'cc', 'hpp', 'cs', 'go', 'rs', 'rb', 'php', 'lua', 'r', 'pl', 'sql', 'gradle',
    'sh', 'bash', 'zsh', 'bat', 'cmd', 'ps1', 'gitignore', 'dockerfile', 'makefile', 'lock', 'tex', 'srt', 'vtt',
  },
};

FileCategory categoryOf(String path, {bool isDir = false}) {
  if (isDir) return FileCategory.folder;
  final e = p.extension(path).replaceFirst('.', '').toLowerCase();
  for (final entry in _ext.entries) {
    if (entry.value.contains(e)) return entry.key;
  }
  return FileCategory.other;
}

class FileItem {
  const FileItem({
    required this.path,
    required this.isDir,
    required this.size,
    required this.modified,
  });

  final String path;
  final bool isDir;
  final int size;
  final DateTime modified;

  String get name => p.basename(path);
  FileCategory get category => categoryOf(path, isDir: isDir);
}
