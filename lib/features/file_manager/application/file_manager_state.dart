import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/paths.dart';
import '../../archive/archive_service.dart';
import '../data/file_service.dart';
import '../domain/file_item.dart';

enum SortMode { name, size, date }

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
    this.grid = false,
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
  final bool grid, showHidden, loading;
  final String? error;

  bool get selecting => selected.isNotEmpty;

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
    bool? grid,
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
        grid: grid ?? this.grid,
        showHidden: showHidden ?? this.showHidden,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

final fileServiceProvider = Provider<FileService>((_) => FileService());
final archiveServiceProvider = Provider<ArchiveService>((_) => ArchiveService());

final fmProvider = NotifierProvider<FmController, FmState>(FmController.new);

class FmController extends Notifier<FmState> {
  final List<String> _history = [];
  FileService get _fs => ref.read(fileServiceProvider);

  @override
  FmState build() {
    Future.microtask(() async => open(await defaultRoot(), push: false));
    return const FmState(loading: true);
  }

  // ---- navigasi ----
  Future<void> open(String path, {bool push = true}) async {
    if (push && state.path.isNotEmpty) _history.add(state.path);
    await _load(path);
  }

  Future<bool> back() async {
    if (_history.isEmpty) return false;
    await _load(_history.removeLast());
    return true;
  }

  Future<void> up() => open(p.dirname(state.path));
  Future<void> refresh() => _load(state.path);

  Future<void> _load(String path) async {
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
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Gagal membuka folder: $e');
    }
  }

  List<FileItem> _sorted(List<FileItem> l, SortMode m) {
    final c = [...l];
    c.sort((a, b) {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      switch (m) {
        case SortMode.size:
          return b.size.compareTo(a.size);
        case SortMode.date:
          return b.modified.compareTo(a.modified);
        case SortMode.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });
    return c;
  }

  void setSort(SortMode m) =>
      state = state.copyWith(sort: m, items: _sorted(state.items, m));
  void toggleGrid() => state = state.copyWith(grid: !state.grid);
  void toggleHidden() {
    state = state.copyWith(showHidden: !state.showHidden);
    refresh();
  }

  // ---- seleksi ----
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
        if (state.cut) state = state.copyWith(clipboard: []);
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
    state = c == null ? state.copyWith(clearFilter: true) : state.copyWith(filter: c);
    if (state.results != null) search(state.query);
  }

  // ---- arsip ----
  Future<void> compress(ArchiveFormat f) => _guard(() => ref
      .read(archiveServiceProvider)
      .compress(state.selected.toList(), state.path, f));

  Future<void> extractHere(String archivePath) => _guard(() => ref
      .read(archiveServiceProvider)
      .extract(archivePath, state.path));

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
