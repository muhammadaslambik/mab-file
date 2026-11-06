import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/notify/notify.dart';
import '../../../core/utils/paths.dart';
import '../../archive/archive_service.dart';
import '../data/file_service.dart';
import '../domain/file_item.dart';

enum SortMode { name, size, date }

enum ViewMode { details, grid }

class FmState {
  const FmState({
    this.path = '',
    this.items = const [],
    this.results,
    this.selected = const {},
    this.clipboard = const [],
    this.cut = false,
    this.sort = SortMode.name,
    this.filter,
    this.query = '',
    this.view = ViewMode.details,
    this.asc = true,
    this.canBack = false,
    this.canForward = false,
    this.showHidden = false,
    this.loading = false,
    this.error,
  });

  final String path;
  final List<FileItem> items;
  final List<FileItem>? results; // hasil deep search (null = mode browse)
  final Set<String> selected;
  final List<String> clipboard;
  final bool cut;
  final SortMode sort;
  final FileCategory? filter;
  final String query;
  final ViewMode view;
  final bool asc, canBack, canForward, showHidden, loading;
  final String? error;

  bool get selecting => selected.isNotEmpty;

  List<FileItem> get selectedItems =>
      visible.where((i) => selected.contains(i.path)).toList();

  List<FileItem> get visible {
    final base = results ?? items;
    if (filter == null) return base;
    return base
        .where((i) => i.category == filter || (i.isDir && results == null))
        .toList();
  }

  FmState copyWith({
    String? path,
    List<FileItem>? items,
    List<FileItem>? results,
    bool clearResults = false,
    Set<String>? selected,
    List<String>? clipboard,
    bool? cut,
    SortMode? sort,
    FileCategory? filter,
    bool clearFilter = false,
    String? query,
    ViewMode? view,
    bool? asc,
    bool? canBack,
    bool? canForward,
    bool? showHidden,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      FmState(
        path: path ?? this.path,
        items: items ?? this.items,
        results: clearResults ? null : (results ?? this.results),
        selected: selected ?? this.selected,
        clipboard: clipboard ?? this.clipboard,
        cut: cut ?? this.cut,
        sort: sort ?? this.sort,
        filter: clearFilter ? null : (filter ?? this.filter),
        query: query ?? this.query,
        view: view ?? this.view,
        asc: asc ?? this.asc,
        canBack: canBack ?? this.canBack,
        canForward: canForward ?? this.canForward,
        showHidden: showHidden ?? this.showHidden,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

final fileServiceProvider = Provider<FileService>((_) => FileService());
final archiveServiceProvider = Provider<ArchiveService>((_) => ArchiveService());

final fmProvider = NotifierProvider<FmController, FmState>(FmController.new);

class FmController extends Notifier<FmState> {
  final List<String> _back = [];
  final List<String> _fwd = [];
  FileService get _fs => ref.read(fileServiceProvider);

  @override
  FmState build() {
    Future.microtask(() async => open(await defaultRoot(), push: false));
    return const FmState(loading: true);
  }

  // ---- navigasi ----
  Future<void> open(String path, {bool push = true}) async {
    final from = state.path;
    if (!await _load(path)) return;
    if (push && from.isNotEmpty && from != path) {
      _back.add(from);
      _fwd.clear();
    }
    _syncNav();
  }

  Future<bool> back() async {
    if (_back.isEmpty) return false;
    final from = state.path;
    if (await _load(_back.last)) {
      _back.removeLast();
      _fwd.add(from);
      _syncNav();
    }
    return true;
  }

  Future<void> forward() async {
    if (_fwd.isEmpty) return;
    final from = state.path;
    if (await _load(_fwd.last)) {
      _fwd.removeLast();
      _back.add(from);
      _syncNav();
    }
  }

  void _syncNav() => state =
      state.copyWith(canBack: _back.isNotEmpty, canForward: _fwd.isNotEmpty);

  /// Dari kolom alamat yang diketik manual.
  Future<void> openPath(String text) async {
    final t = text.trim();
    if (t.isNotEmpty && await Directory(t).exists()) {
      await open(t);
    } else {
      state = state.copyWith(error: 'Folder tidak ditemukan: $t');
    }
  }

  Future<void> up() => open(p.dirname(state.path));
  Future<void> refresh() => _load(state.path);

  Future<bool> _load(String path) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final items = await _fs.list(path, showHidden: state.showHidden);
      state = state.copyWith(
        path: path,
        items: _sorted(items, state.sort),
        selected: {},
        loading: false,
        clearResults: true,
        query: '',
      );
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Gagal membuka folder: $e');
      return false;
    }
  }

  List<FileItem> _sorted(List<FileItem> l, SortMode m) {
    final c = [...l];
    c.sort((a, b) {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      final r = switch (m) {
        SortMode.size => a.size.compareTo(b.size),
        SortMode.date => a.modified.compareTo(b.modified),
        SortMode.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      };
      return state.asc ? r : -r;
    });
    return c;
  }

  void setSort(SortMode m) {
    // klik kolom yang sama -> balik arah (seperti Explorer)
    final asc = m == state.sort ? !state.asc : (m == SortMode.name);
    state = state.copyWith(sort: m, asc: asc);
    state = state.copyWith(items: _sorted(state.items, m));
  }

  void setView(ViewMode v) => state = state.copyWith(view: v);
  void toggleHidden() {
    state = state.copyWith(showHidden: !state.showHidden);
    refresh();
  }

  // ---- seleksi ----
  void selectOnly(String path) => state = state.copyWith(selected: {path});

  void toggleSelect(String path) {
    final s = {...state.selected};
    s.contains(path) ? s.remove(path) : s.add(path);
    state = state.copyWith(selected: s);
  }

  void selectAll() =>
      state = state.copyWith(selected: state.visible.map((e) => e.path).toSet());
  void clearSelection() => state = state.copyWith(selected: {});

  // ---- clipboard ----
  void copy() => state = state.copyWith(
      clipboard: state.selected.toList(), cut: false, selected: {});
  void cutSelected() => state = state.copyWith(
      clipboard: state.selected.toList(), cut: true, selected: {});

  Future<void> paste() => _guard(() async {
        for (final s in state.clipboard) {
          state.cut ? await _fs.move(s, state.path) : await _fs.copy(s, state.path);
        }
        final n = state.clipboard.length;
        if (state.cut) state = state.copyWith(clipboard: []);
        ref.read(notifsProvider.notifier).push(state.cut ? 'Dipindahkan' : 'Disalin',
            body: '$n item', kind: NoteKind.success, toast: false);
      });

  // ---- operasi dasar ----
  Future<void> deleteSelected() => _guard(() async {
        for (final s in state.selected) {
          await _fs.delete(s);
        }
      });

  Future<void> rename(String path, String newName) =>
      _guard(() => _fs.rename(path, newName));
  Future<void> newFolder(String name) =>
      _guard(() => _fs.createFolder(state.path, name));
  Future<void> newFile(String name) =>
      _guard(() => _fs.createFile(state.path, name));

  // ---- pencarian & filter ----
  Future<void> search(String q) async {
    if (q.trim().isEmpty) {
      state = state.copyWith(clearResults: true, query: '');
      return;
    }
    state = state.copyWith(loading: true, query: q);
    try {
      final r = await _fs.search(state.path, query: q, category: state.filter);
      state = state.copyWith(results: r, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: '$e');
    }
  }

  void setFilter(FileCategory? c) {
    if (c == state.filter) c = null; // tap lagi = matikan filter
    state = c == null ? state.copyWith(clearFilter: true) : state.copyWith(filter: c);
    if (state.results != null) search(state.query);
  }

  // ---- arsip ----
  Future<void> compress(ArchiveFormat f) => _guard(() async {
        final out = await ref
            .read(archiveServiceProvider)
            .compress(state.selected.toList(), state.path, f);
        ref.read(notifsProvider.notifier).push('Arsip dibuat', body: p.basename(out), kind: NoteKind.success);
      });

  Future<void> extractHere(String archivePath) => _guard(() async {
        final out = await ref.read(archiveServiceProvider).extract(archivePath, state.path);
        ref.read(notifsProvider.notifier).push('Ekstrak selesai', body: p.basename(out), kind: NoteKind.success);
      });

  Future<void> _guard(Future<void> Function() job) async {
    try {
      await job();
      await refresh();
    } catch (e) {
      state = state.copyWith(error: '$e', loading: false);
    }
  }

  void consumeError() => state = state.copyWith(clearError: true);
}
