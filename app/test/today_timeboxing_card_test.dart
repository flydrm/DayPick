import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/features/focus/providers/focus_providers.dart';
import 'package:daypick/features/notes/providers/note_providers.dart';
import 'package:daypick/features/tasks/providers/task_providers.dart';
import 'package:daypick/features/today/providers/today_plan_providers.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

domain.Task _task({
  required String id,
  required String title,
  required DateTime now,
  int? estimatedPomodoros,
}) {
  return domain.Task(
    id: id,
    title: domain.TaskTitle(title),
    status: domain.TaskStatus.todo,
    priority: domain.TaskPriority.medium,
    dueAt: null,
    tags: const [],
    estimatedPomodoros: estimatedPomodoros,
    triageStatus: domain.TriageStatus.scheduledLater,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('Today timeboxing module renders and opens start time picker', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final tasks = [
      _task(id: 't1', title: '任务 A', now: now, estimatedPomodoros: 2),
      _task(id: 't2', title: '任务 B', now: now, estimatedPomodoros: 1),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksStreamProvider.overrideWith((ref) => Stream.value(tasks)),
          notesStreamProvider.overrideWith(
            (ref) => Stream.value(const <domain.Note>[]),
          ),
          unprocessedNotesStreamProvider.overrideWith(
            (ref) => Stream.value(const <domain.Note>[]),
          ),
          todayPomodoroSessionsProvider.overrideWith(
            (ref) => Stream.value(const <domain.PomodoroSession>[]),
          ),
          yesterdayPomodoroSessionsProvider.overrideWith(
            (ref) => Stream.value(const <domain.PomodoroSession>[]),
          ),
          pomodoroConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.PomodoroConfig()),
          ),
          todayPlanTaskIdsProvider.overrideWith(
            (ref) => Stream.value(const <String>['t1', 't2']),
          ),
          todayPlanTaskIdsForDayProvider.overrideWith(
            (ref, day) => Stream.value(const <String>[]),
          ),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(
              const domain.AppearanceConfig(
                todayModules: [domain.TodayWorkbenchModule.timeboxing],
              ),
            ),
          ),
          activePomodoroProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('时间轴'), findsOneWidget);
    expect(find.text('3 番茄'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.schedule_outlined));
    await tester.pumpAndSettle();

    expect(find.text('时间轴开始时间'), findsOneWidget);
    await disposeApp(tester);
  });
}
