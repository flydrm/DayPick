import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/features/focus/providers/focus_providers.dart';
import 'package:daypick/features/notes/providers/note_providers.dart';
import 'package:daypick/features/tasks/providers/task_providers.dart';
import 'package:daypick/features/tasks/view/task_filters_sheet.dart';
import 'package:daypick/features/today/providers/today_plan_providers.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'test_utils.dart';

domain.Task _task({
  required String id,
  required String title,
  required DateTime now,
  domain.TriageStatus triageStatus = domain.TriageStatus.scheduledLater,
}) {
  return domain.Task(
    id: id,
    title: domain.TaskTitle(title),
    description: null,
    status: domain.TaskStatus.todo,
    priority: domain.TaskPriority.medium,
    dueAt: null,
    tags: const [],
    estimatedPomodoros: 1,
    triageStatus: triageStatus,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('Tasks: includeInbox filter shows Clear in active filters bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime(2026, 1, 10, 12);
    final tasks = [
      _task(id: 't-1', title: 'Task A', now: now),
      _task(
        id: 't-inbox',
        title: 'Task Inbox',
        now: now,
        triageStatus: domain.TriageStatus.inbox,
      ),
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
            (ref) => Stream.value(const <String>[]),
          ),
          todayPlanTaskIdsForDayProvider.overrideWith(
            (ref, day) => Stream.value(const <String>[]),
          ),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.AppearanceConfig()),
          ),
          activePomodoroProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    final bottomNav = find.byKey(const ValueKey('bottom_navigation'));
    await tester.tap(find.descendant(of: bottomNav, matching: find.text('任务')));
    await tester.pumpAndSettle();

    expect(find.text('Task A'), findsOneWidget);
    expect(find.text('Task Inbox'), findsNothing);

    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskFiltersSheet), findsOneWidget);

    final includeInboxSwitch = find.descendant(
      of: find.byType(TaskFiltersSheet),
      matching: find.widgetWithText(ShadSwitch, '包含待处理（Inbox）'),
    );
    final switchWidget = tester.widget<ShadSwitch>(includeInboxSwitch);
    switchWidget.onChanged?.call(true);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(TaskFiltersSheet),
        matching: find.widgetWithText(ShadButton, '应用'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('含待处理'), findsOneWidget);
    expect(find.widgetWithText(ShadButton, '清除'), findsOneWidget);
    expect(find.text('Task Inbox'), findsOneWidget);

    await tester.tap(find.widgetWithText(ShadButton, '清除'));
    await tester.pumpAndSettle();

    expect(find.text('含待处理'), findsNothing);
    expect(find.widgetWithText(ShadButton, '清除'), findsNothing);
    expect(find.text('Task Inbox'), findsNothing);
    await disposeApp(tester);
  });
}
