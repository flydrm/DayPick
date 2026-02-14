import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/feature_flags/feature_flag_keys.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/features/focus/providers/focus_providers.dart';
import 'package:daypick/features/notes/providers/note_providers.dart';
import 'package:daypick/features/tasks/providers/task_providers.dart';
import 'package:daypick/features/today/providers/today_plan_providers.dart';
import 'package:daypick/features/today/view/today_entry_point.dart';
import 'package:daypick/routing/app_router.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fakes/fake_today_plan_repository.dart';
import 'test_utils.dart';

domain.Task _task({required String id, required String title, required DateTime now}) {
  return domain.Task(
    id: id,
    title: domain.TaskTitle(title),
    status: domain.TaskStatus.todo,
    priority: domain.TaskPriority.medium,
    tags: const [],
    estimatedPomodoros: null,
    createdAt: now,
    updatedAt: now,
    triageStatus: domain.TriageStatus.scheduledLater,
  );
}

List<Override> _baseOverrides({required Stream<List<domain.Task>> tasksStream}) {
  return [
    appearanceConfigProvider.overrideWith(
      (ref) => Stream.value(const domain.AppearanceConfig(onboardingDone: true)),
    ),
    tasksStreamProvider.overrideWith((ref) => tasksStream),
    todayEveningPlanTaskIdsProvider.overrideWith((ref) => Stream.value(const [])),
    todayPlanTaskIdsForDayProvider.overrideWith(
      (ref, day) => Stream.value(const []),
    ),
    todayEveningPlanTaskIdsForDayProvider.overrideWith(
      (ref, day) => Stream.value(const []),
    ),
    notesStreamProvider.overrideWith((ref) => Stream.value(const <domain.Note>[])),
    unprocessedNotesStreamProvider.overrideWith(
      (ref) => Stream.value(const <domain.Note>[]),
    ),
    todayPomodoroSessionsProvider.overrideWith(
      (ref) => Stream.value(const <domain.PomodoroSession>[]),
    ),
    yesterdayPomodoroSessionsProvider.overrideWith(
      (ref) => Stream.value(const <domain.PomodoroSession>[]),
    ),
    anyPomodoroSessionCountProvider.overrideWith((ref) => Stream.value(0)),
    pomodoroConfigProvider.overrideWith(
      (ref) => Stream.value(const domain.PomodoroConfig()),
    ),
    activePomodoroProvider.overrideWith((ref) => Stream.value(null)),
  ];
}

void main() {
  testWidgets('Top3 编辑：拖拽排序前 3 条并立即持久化', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final day = DateTime(2026, 1, 1);
    final now = DateTime(2026, 1, 1, 9);

    final todayPlanRepo = FakeTodayPlanRepository();
    addTearDown(todayPlanRepo.dispose);
    await todayPlanRepo.replaceTasks(
      day: day,
      taskIds: const ['t1', 't2', 't3'],
      section: domain.TodayPlanSection.today,
    );

    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(
          path: '/today',
          builder: (context, state) => const Scaffold(body: TodayEntryPoint()),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          todayPlanRepositoryProvider.overrideWithValue(todayPlanRepo),
          todayDayProvider.overrideWith((ref) => Stream.value(day)),
          ..._baseOverrides(
            tasksStream: Stream.value([
              _task(id: 't1', title: '任务 1', now: now),
              _task(id: 't2', title: '任务 2', now: now),
              _task(id: 't3', title: '任务 3', now: now),
            ]),
          ),
          featureFlagEnabledProvider.overrideWith((ref, key) {
            if (key == FeatureFlagKeys.todayV2) return Stream.value(true);
            return Stream.value(false);
          }),
        ],
        child: const DayPickApp(),
      ),
    );
    final top1 = find.byKey(const ValueKey('today_v2_top3:t1'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (top1.evaluate().isNotEmpty) break;
    }
    expect(top1, findsOneWidget);

    // 初始顺序：t1 在上，t3 在下。
    final y1 = tester.getTopLeft(top1).dy;
    final y3 = tester.getTopLeft(find.byKey(const ValueKey('today_v2_top3:t3'))).dy;
    expect(y1 < y3, isTrue);

    // 打开编辑并将 t3 拖到最上面。
    await tester.tap(find.byKey(const ValueKey('today_v2_top3_edit')));
    await tester.pumpAndSettle();

    // 在 widget test 中直接调用 onReorder，避免拖拽手势的易碎性。
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorder(2, 0); // t3 -> top
    await tester.pumpAndSettle();

    expect(
      await todayPlanRepo.getTaskIdsForDay(
        day: day,
        section: domain.TodayPlanSection.today,
      ),
      ['t3', 't1', 't2'],
    );
    await tester.tap(find.byKey(const ValueKey('top3_edit_close')));
    await tester.pumpAndSettle();

    final y3After =
        tester.getTopLeft(find.byKey(const ValueKey('today_v2_top3:t3'))).dy;
    final y1After =
        tester.getTopLeft(find.byKey(const ValueKey('today_v2_top3:t1'))).dy;
    expect(y3After < y1After, isTrue);

    await disposeApp(tester);
  });
}
