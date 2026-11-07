import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppSettings {
  const AppSettings({
    this.themeId = 'aurora',
    this.animated = false,
    this.ffmpegPath = '',
    this.editorFont = 14,
    this.videoMode = 'auto',
  });

  final String themeId;
  final bool animated;
  final String ffmpegPath;
  final double editorFont;

  /// 'auto' = pemutar sistem di desktop, pemutar bawaan di HP; 'system' / 'builtin' = pilihan pengguna.
  final String videoMode;

  /// Video dibuka dengan aplikasi default sistem (paling hemat CPU/GPU di desktop).
  bool get videoUsesSystemPlayer =>
      videoMode == 'system' ||
      (videoMode == 'auto' && (Platform.isWindows || Platform.isLinux || Platform.isMacOS));

  AppSettings copyWith({
    String? themeId,
    bool? animated,
    String? ffmpegPath,
    double? editorFont,
    String? videoMode,
  }) =>
      AppSettings(
        themeId: themeId ?? this.themeId,
        animated: animated ?? this.animated,
        ffmpegPath: ffmpegPath ?? this.ffmpegPath,
        editorFont: editorFont ?? this.editorFont,
        videoMode: videoMode ?? this.videoMode,
      );

  Map<String, dynamic> toJson() => {
        'themeId': themeId,
        'animated': animated,
        'ffmpegPath': ffmpegPath,
        'editorFont': editorFont,
        'videoMode': videoMode,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        themeId: j['themeId'] as String? ?? 'aurora',
        animated: j['animated'] as bool? ?? false,
        ffmpegPath: j['ffmpegPath'] as String? ?? '',
        editorFont: (j['editorFont'] as num?)?.toDouble() ?? 14,
        videoMode: j['videoMode'] as String? ?? 'auto',
      );
}

/// Pengaturan disimpan sebagai settings.json di folder data aplikasi (lokal, tanpa paket tambahan).
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    Future.microtask(_load);
    return const AppSettings();
  }

  Future<File> _file() async {
    final d = await getApplicationSupportDirectory();
    return File(p.join(d.path, 'settings.json'));
  }

  Future<void> _load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        state = AppSettings.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      await (await _file()).writeAsString(jsonEncode(state.toJson()));
    } catch (_) {}
  }

  void update(AppSettings s) {
    state = s;
    _save();
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
