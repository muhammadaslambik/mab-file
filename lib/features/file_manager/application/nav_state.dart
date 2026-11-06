import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavIndex extends Notifier<int> {
  @override
  int build() => 0;
  void set(int v) => state = v;
}

final navIndexProvider = NotifierProvider<NavIndex, int>(NavIndex.new);
