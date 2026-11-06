import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notify/notify.dart';
import 'core/settings/settings.dart';
import 'core/theme/app_theme.dart';
import 'features/file_manager/presentation/home_shell.dart';

class MabFileApp extends ConsumerWidget {
  const MabFileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(settingsProvider.select((s) => s.themeId));
    final ThemeData light, dark;
    final ThemeMode mode;
    if (id == 'auto') {
      light = AppTheme.build(themeById('porcelain'));
      dark = AppTheme.build(themeById('aurora'));
      mode = ThemeMode.system;
    } else {
      light = dark = AppTheme.build(themeById(id));
      mode = ThemeMode.light;
    }
    return MaterialApp(
      title: 'MAB-File',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootMessengerKey,
      theme: light,
      darkTheme: dark,
      themeMode: mode,
      home: const HomeShell(),
    );
  }
}
