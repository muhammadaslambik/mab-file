import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/file_manager/presentation/home_shell.dart';

class MabFileApp extends StatelessWidget {
  const MabFileApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'mab-file',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.soft(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const HomeShell(),
      );
}
