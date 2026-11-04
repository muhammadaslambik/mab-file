import 'package:flutter/material.dart';

import '../../storage/storage_analyzer.dart';
import '../../vault/vault_page.dart';
import 'files_page.dart';

/// Adaptif: NavigationRail (desktop/tablet >= 800px) vs NavigationBar (HP).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;
  static const _pages = [FilesPage(), StorageAnalyzerPage(), VaultPage()];
  static const _dest = [
    (Icons.folder_outlined, Icons.folder, 'Files'),
    (Icons.pie_chart_outline, Icons.pie_chart, 'Storage'),
    (Icons.lock_outline, Icons.lock, 'Vault'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final body = IndexedStack(index: _i, children: _pages);
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _i,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (v) => setState(() => _i = v),
            destinations: [
              for (final d in _dest)
                NavigationRailDestination(
                    icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: [
          for (final d in _dest)
            NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
        ],
      ),
    );
  }
}
