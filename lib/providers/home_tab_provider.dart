// Home tab index shared between the shell, dashboard header and quick
// actions (lets any screen jump to another bottom-nav tab).

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom-nav tab indexes.
abstract final class HomeTab {
  static const int dashboard = 0;
  static const int budgets = 1;
  static const int chat = 2;
  static const int reports = 3;
  static const int settings = 4;
}

final StateProvider<int> homeTabIndexProvider =
    StateProvider<int>((Ref ref) => HomeTab.dashboard);
