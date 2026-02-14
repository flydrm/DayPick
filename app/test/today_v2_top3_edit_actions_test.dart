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
  testWidgets('Top3 编辑：替换指定槽位并立即持久化', (tester) async {
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
              _task(id: 't4', title: '任务 4', now: now),
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
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('today_v2_top3_edit')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('top3_edit_replace:t2')));
    await tester.pumpAndSettle();

    expect(find.text('选择任务'), findsOneWidget);
    await tester.tap(find.text('任务 4'));
    await tester.pumpAndSettle();

    expect(
      await todayPlanRepo.getTaskIdsForDay(
        day: day,
        section: domain.TodayPlanSection.today,
      ),
      ['t1', 't4', 't3', 't2'],
    );

    await disposeApp(tester);
  });

  testWidgets('Top3 编辑：移除后可撤销（至少一次）', (tester) async {
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
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('today_v2_top3_edit')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('top3_edit_remove:t1')));
    await tester.pumpAndSettle();

    expect(
      await todayPlanRepo.getTaskIdsForDay(
        day: day,
        section: domain.TodayPlanSection.today,
      ),
      ['t2', 't3'],
    );

    expect(find.text('撤销'), findsOneWidget);
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();

    expect(
      await todayPlanRepo.getTaskIdsForDay(
        day: day,
        section: domain.TodayPlanSection.today,
      ),
      ['t1', 't2', 't3'],
    );

    await disposeApp(tester);
  });

  testWidgets('Top3 编辑：固定/取消固定会置顶并立即持久化', (tester) async {
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
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('today_v2_top3_edit')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('top3_edit_pin:t2')));
    await tester.pumpAndSettle();
    expect(
      await todayPlanRepo.getTaskIdsForDay(
        day: day,
        section: domain.TodayPlanSection.today,
      ),
      ['t2', 't1', 't3'],
    );

    await tester.tap(find.byKey(const ValueKey('top3_edit_pin:t2')));
    await tester.pumpAndSettle();
    expect(
      await todayPlanRepo.getTaskIdsForDay(
        day: day,
        section: domain.TodayPlanSection.today,
      ),
      ['t1', 't2', 't3'],
    );

    await disposeApp(tester);
  });
}

