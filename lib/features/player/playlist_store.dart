import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Playlist tersimpan (nama -> daftar path), disimpan lokal di playlists.json.
class PlaylistStore extends Notifier<Map<String, List<String>>> {
  @override
  Map<String, List<String>> build() {
    Future.microtask(_load);
    return const {};
  }

  Future<File> _file() async =>
      File(p.join((await getApplicationSupportDirectory()).path, 'playlists.json'));

  Future<void> _load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      state = {for (final e in j.entries) e.key: List<String>.from(e.value as List)};
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      await (await _file()).writeAsString(jsonEncode(state));
    } catch (_) {}
  }

  Future<void> save(String name, List<String> paths) async {
    state = {...state, name: List<String>.from(paths)};
    await _persist();
  }

  Future<void> remove(String name) async {
    state = {...state}..remove(name);
    await _persist();
  }
}

final playlistStoreProvider =
    NotifierProvider<PlaylistStore, Map<String, List<String>>>(PlaylistStore.new);
