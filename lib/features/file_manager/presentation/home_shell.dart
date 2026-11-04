import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../storage/storage_analyzer.dart';
import '../../vault/vault_page.dart';
import '../application/nav_state.dart';
import 'files_page.dart';
import 'mobile_page.dart';
import 'widgets/sidebar.dart';

/// Adaptif: sidebar permanen (>= 900px) vs navigasi bawah (HP).
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = ref.watch(navIndexProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final pages = IndexedStack(index: idx, children: [
      wide ? const DesktopFilesPage() : const MobileFilesPage(),
      const StorageAnalyzerPage(),
      const VaultPage(),
    ]);

    if (wide) {
      return Scaffold(body: Row(children: [const Sidebar(), Expanded(child: pages)]));
    }
    return Scaffold(
      body: SafeArea(bottom: false, child: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: ref.read(navIndexProvider.notifier).set,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder_rounded),
              label: 'File'),
          NavigationDestination(
              icon: Icon(Icons.pie_chart_outline_rounded),
              selectedIcon: Icon(Icons.pie_chart_rounded),
              label: 'Storage'),
          NavigationDestination(
              icon: Icon(Icons.lock_outline_rounded),
              selectedIcon: Icon(Icons.lock_rounded),
              label: 'Vault'),
        ],
      ),
    );
  }
}
