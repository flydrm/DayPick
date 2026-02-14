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
  testWidgets('Top3：展示来源/原因，并可打开 Why Sheet（非全屏）', (tester) async {
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
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          ..._baseOverrides(
            tasksStream: Stream.value([
              _task(id: 't1', title: '计划 1', now: now),
              _task(
                id: 't2',
                title: '建议 2',
                now: now,
                dueAt: today.subtract(const Duration(days: 1)),
              ),
            ]),
            todayPlanIdsStream: Stream.value(['t1']),
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

    // 来源/原因：至少包含「今天计划」「建议」「已逾期」等可解释线索。
    expect(find.text('今天计划'), findsOneWidget);
    expect(find.text('建议'), findsOneWidget);
    expect(find.textContaining('已逾期'), findsOneWidget);

    // Why sheet：可打开查看更详细说明（不默认全屏打断）。
    await tester.tap(find.byKey(const ValueKey('today_v2_top3_why:t2')));
    await tester.pumpAndSettle();
    expect(find.text('为什么是这条'), findsOneWidget);

    await disposeApp(tester);
  });
}
