import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/file_manager/application/nav_state.dart';
import 'features/file_manager/presentation/home_shell.dart';

class MabFileApp extends ConsumerWidget {
  const MabFileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        title: 'MAB-File',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ref.watch(themeModeProvider),
        home: const HomeShell(),
      );
}
