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

List<Override> _baseOverrides({
  required Stream<List<domain.Task>> tasksStream,
  required Stream<List<String>> todayPlanIdsStream,
}) {
  return [
    appearanceConfigProvider.overrideWith(
      (ref) => Stream.value(const domain.AppearanceConfig(onboardingDone: true)),
    ),
    tasksStreamProvider.overrideWith((ref) => tasksStream),
    todayPlanTaskIdsProvider.overrideWith((ref) => todayPlanIdsStream),
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
  testWidgets('Top3 SSOT：Today Plan 不足 3 条时，用规则建议补位（草稿）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime(2026, 1, 1, 9);
    final today = DateTime(now.year, now.month, now.day);
    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(
          path: '/today',
          builder: (context, state) => const Scaffold(body: TodayEntryPoint()),
        ),
        GoRoute(
          path: '/tasks/:taskId',
          builder: (context, state) =>
              Scaffold(body: Text('task:${state.pathParameters['taskId']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          ..._baseOverrides(
            tasksStream: Stream.value([
              _task(id: 't1', title: '计划 1', now: now),
              _task(id: 't2', title: '计划 2', now: now),
              _task(
                id: 't3',
                title: '建议 3',
                now: now,
                dueAt: today.subtract(const Duration(days: 1)),
              ),
            ]),
            todayPlanIdsStream: Stream.value(['t1', 't2']),
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

    expect(find.byKey(const ValueKey('today_v2_top3:t1')), findsOneWidget);
    expect(find.byKey(const ValueKey('today_v2_top3:t2')), findsOneWidget);

    // 计划只有 2 条时，应补位第 3 条（来自规则建议，仍为草稿，不会自动写入计划）。
    expect(find.byKey(const ValueKey('today_v2_top3:t3')), findsOneWidget);

    // 点击仍可直达任务详情（不强制多层跳转）。
    await tester.tap(find.byKey(const ValueKey('today_v2_top3:t1')));
    await tester.pumpAndSettle();
    expect(find.text('task:t1'), findsOneWidget);

    await disposeApp(tester);
  });
}

