import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavIndex extends Notifier<int> {
  @override
  int build() => 0;
  void set(int v) => state = v;
}

final navIndexProvider = NotifierProvider<NavIndex, int>(NavIndex.new);

class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void cycle() => state = switch (state) {
        ThemeMode.dark => ThemeMode.light,
        ThemeMode.light => ThemeMode.system,
        ThemeMode.system => ThemeMode.dark,
      };
}

final themeModeProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);
