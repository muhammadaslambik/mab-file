import 'package:path/path.dart' as p;

enum FileCategory { folder, document, image, video, audio, apk, archive, code, other }

const _ext = <FileCategory, Set<String>>{
  FileCategory.document: {'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods', 'rtf', 'epub'},
  FileCategory.image: {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'svg'},
  FileCategory.video: {'mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', 'wmv', '3gp'},
  FileCategory.audio: {'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'opus'},
  FileCategory.apk: {'apk', 'xapk', 'aab'},
  FileCategory.archive: {'zip', 'rar', '7z', 'tar', 'gz', 'tgz', 'bz2', 'xz'},
  FileCategory.code: {'txt', 'md', 'json', 'yaml', 'yml', 'xml', 'csv', 'log', 'ini', 'dart', 'py', 'js', 'ts', 'html', 'css', 'java', 'kt', 'rs', 'go', 'c', 'cpp', 'h', 'sh'},
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
