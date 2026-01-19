import 'package:domain/domain.dart' as domain;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';

final activePomodoroProvider = StreamProvider<domain.ActivePomodoro?>((ref) {
  return ref.watch(activePomodoroRepositoryProvider).watch();
});

final pomodoroSessionsByTaskProvider =
    StreamProvider.family<List<domain.PomodoroSession>, String>((ref, taskId) {
      return ref.watch(pomodoroSessionRepositoryProvider).watchByTaskId(taskId);
    });

final pomodoroCountByTaskProvider = StreamProvider.family<int, String>((
  ref,
  taskId,
) {
  return ref
      .watch(pomodoroSessionRepositoryProvider)
      .watchCountByTaskId(taskId);
});

final todayPomodoroCountProvider = StreamProvider<int>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1));
  return ref
      .watch(pomodoroSessionRepositoryProvider)
      .watchCountBetween(start, end);
});

final todayPomodoroSessionsProvider =
    StreamProvider<List<domain.PomodoroSession>>((ref) {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      return ref
          .watch(pomodoroSessionRepositoryProvider)
          .watchBetween(start, end);
    });

final yesterdayPomodoroSessionsProvider =
    StreamProvider<List<domain.PomodoroSession>>((ref) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final start = todayStart.subtract(const Duration(days: 1));
      final end = todayStart;
      return ref
          .watch(pomodoroSessionRepositoryProvider)
          .watchBetween(start, end);
    });

final anyPomodoroSessionCountProvider = StreamProvider<int>((ref) {
  return ref
      .watch(pomodoroSessionRepositoryProvider)
      .watchCountBetween(
        DateTime.fromMillisecondsSinceEpoch(0),
        DateTime(3000),
      );
});
