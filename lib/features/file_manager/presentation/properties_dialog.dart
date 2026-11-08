import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/file_service.dart';
import '../domain/file_item.dart';
import 'widgets/glyph.dart';

/// Dialog Properti (Alt+Enter / menu klik-kanan). Ukuran folder dihitung di Isolate.
Future<void> showProperties(BuildContext context, List<FileItem> items) =>
    showDialog<void>(context: context, builder: (_) => _PropertiesDialog(items: items));

typedef _Totals = ({int files, int dirs, int bytes, bool capped});

class _PropertiesDialog extends StatefulWidget {
  const _PropertiesDialog({required this.items});
  final List<FileItem> items;

  @override
  State<_PropertiesDialog> createState() => _PropertiesDialogState();
}

class _PropertiesDialogState extends State<_PropertiesDialog> {
  late final Future<_Totals> _totals = _calc();

  Future<_Totals> _calc() async {
    final fs = FileService();
    var files = 0, dirs = 0, bytes = 0;
    var capped = false;
    for (final it in widget.items) {
      if (it.isDir) {
        final s = await fs.folderStats(it.path);
        files += s.files;
        dirs += s.dirs;
        bytes += s.bytes;
        capped = capped || s.capped;
      } else {
        files++;
        bytes += it.size;
      }
    }
    return (files: files, dirs: dirs, bytes: bytes, capped: capped);
  }

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final items = widget.items;
    final one = items.length == 1 ? items.first : null;

    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 96, child: Text(k, style: TextStyle(color: pal.muted, fontSize: 13))),
            Expanded(child: SelectableText(v, style: const TextStyle(fontSize: 13.5))),
          ]),
        );

    return AlertDialog(
      title: Text(one != null ? one.name : '${items.length} item',
          maxLines: 2, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<_Totals>(
          future: _totals,
          builder: (_, snap) {
            final t = snap.data;
            final size = snap.hasError
                ? 'Gagal menghitung'
                : t == null
                    ? 'Menghitung…'
                    : '${t.capped ? '≥ ' : ''}${formatBytes(t.bytes)}  (${t.bytes} B)';
            return Column(mainAxisSize: MainAxisSize.min, children: [
              if (one != null) ...[
                row('Jenis', catLabel(one.category)),
                row('Lokasi', p.dirname(one.path)),
                row('Diubah', formatDate(one.modified)),
              ],
              row('Ukuran', size),
              if (t != null && (one == null || one.isDir))
                row('Isi', '${t.files} file, ${t.dirs} folder'),
            ]);
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
      ],
    );
  }
}
