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

domain.Task _task({
  required String id,
  required String title,
  required DateTime now,
  DateTime? dueAt,
}) {
  return domain.Task(
    id: id,
    title: domain.TaskTitle(title),
    status: domain.TaskStatus.todo,
    priority: domain.TaskPriority.medium,
    tags: const [],
    estimatedPomodoros: null,
    createdAt: now,
    updatedAt: now,
    dueAt: dueAt,
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
  testWidgets('Top3 建议：草稿态 + Adopt/Ignore/Undo + 预览→确认写入', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final day = DateTime(2026, 1, 1);
    final now = DateTime(2026, 1, 1, 9);

    final todayPlanRepo = FakeTodayPlanRepository();
    addTearDown(todayPlanRepo.dispose);
    await todayPlanRepo.replaceTasks(
      day: day,
      taskIds: const ['t1'],
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
              _task(id: 't1', title: '计划 1', now: now),
              _task(
                id: 't2',
                title: '建议 2',
                now: now,
                dueAt: DateTime(2020, 1, 1), // 保证逾期 → 进入 TodayQueueRule
              ),
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

    expect(find.byKey(const ValueKey('today_v2_top3:t2')), findsOneWidget);
    expect(find.byKey(const ValueKey('today_v2_top3_adopt:t2')), findsOneWidget);
    expect(find.byKey(const ValueKey('today_v2_top3_ignore:t2')), findsOneWidget);

    // Ignore + Undo
    await tester.tap(find.byKey(const ValueKey('today_v2_top3_ignore:t2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today_v2_top3:t2')), findsNothing);
    expect(find.text('撤销'), findsOneWidget);
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today_v2_top3:t2')), findsOneWidget);

    // Adopt：必须先预览→确认；取消不写入。
    await tester.tap(find.byKey(const ValueKey('today_v2_top3_adopt:t2')));
    await tester.pumpAndSettle();
    expect(find.text('采用建议？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(
      await todayPlanRepo.getTaskIdsForDay(
        day: day,
        section: domain.TodayPlanSection.today,
      ),
      ['t1'],
    );

    // 确认后才写入 Today Plan。
    await tester.tap(find.byKey(const ValueKey('today_v2_top3_adopt:t2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认写入'));
    await tester.pumpAndSettle();
    expect(
      await todayPlanRepo.getTaskIdsForDay(
        day: day,
        section: domain.TodayPlanSection.today,
      ),
      ['t1', 't2'],
    );

    await disposeApp(tester);
  });
}

