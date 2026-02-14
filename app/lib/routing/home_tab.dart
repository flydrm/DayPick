import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HomeTab { ai, notes, today, tasks, focus, other }

HomeTab homeTabForIndex(int index) {
  return switch (index) {
    0 => HomeTab.ai,
    1 => HomeTab.notes,
    2 => HomeTab.today,
    3 => HomeTab.tasks,
    4 => HomeTab.focus,
    _ => HomeTab.other,
  };
}

String homeTabName(HomeTab tab) {
  return switch (tab) {
    HomeTab.ai => 'ai',
    HomeTab.notes => 'notes',
    HomeTab.today => 'today',
    HomeTab.tasks => 'tasks',
    HomeTab.focus => 'focus',
    HomeTab.other => 'other',
  };
}

final homeTabIndexProvider = StateProvider<int>((ref) => 2);

