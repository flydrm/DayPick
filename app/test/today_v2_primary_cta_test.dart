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

domain.Task _task({required String id, required String title}) {
  final now = DateTime(2026, 1, 1);
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

List<Override> _baseOverrides({
  required Stream<List<domain.Task>> tasksStream,
  required Stream<List<String>> todayPlanIdsStream,
  required Stream<domain.ActivePomodoro?> activePomodoroStream,
}) {
  return [
    appearanceConfigProvider.overrideWith(
      (ref) =>
          Stream.value(const domain.AppearanceConfig(onboardingDone: true)),
    ),
    tasksStreamProvider.overrideWith((ref) => tasksStream),
    todayPlanTaskIdsProvider.overrideWith((ref) => todayPlanIdsStream),
    todayEveningPlanTaskIdsProvider.overrideWith(
      (ref) => Stream.value(const []),
    ),
    todayPlanTaskIdsForDayProvider.overrideWith(
      (ref, day) => Stream.value(const []),
    ),
    todayEveningPlanTaskIdsForDayProvider.overrideWith(
      (ref, day) => Stream.value(const []),
    ),
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
    anyPomodoroSessionCountProvider.overrideWith((ref) => Stream.value(0)),
    pomodoroConfigProvider.overrideWith(
      (ref) => Stream.value(const domain.PomodoroConfig()),
    ),
    activePomodoroProvider.overrideWith((ref) => activePomodoroStream),
  ];
}

void main() {
  testWidgets('Today v2 主 CTA：有进行中 Focus 时优先继续', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(
          path: '/today',
          builder: (context, state) => const Scaffold(body: TodayEntryPoint()),
        ),
        GoRoute(
          path: '/focus',
          builder: (context, state) => const Scaffold(body: Text('focus')),
        ),
      ],
    );

    final active = domain.ActivePomodoro(
      taskId: 't_focus',
      status: domain.ActivePomodoroStatus.running,
      startAt: DateTime(2026, 1, 1, 9),
      endAt: DateTime(2026, 1, 1, 9, 25),
      updatedAt: DateTime(2026, 1, 1, 9),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          ..._baseOverrides(
            tasksStream: Stream.value([_task(id: 't1', title: '任务 1')]),
            todayPlanIdsStream: Stream.value(const []),
            activePomodoroStream: Stream.value(active),
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

    await tester.tap(find.byKey(const ValueKey('today_v2_primary_cta')));
    await tester.pumpAndSettle();

    expect(find.text('focus'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('Today v2 主 CTA：无 active Focus 时以 Top3 首条进入 Focus', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(
          path: '/today',
          builder: (context, state) => const Scaffold(body: TodayEntryPoint()),
        ),
        GoRoute(
          path: '/focus',
          builder: (context, state) {
            final taskId = state.uri.queryParameters['taskId'];
            return Scaffold(body: Text('focus:$taskId'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          ..._baseOverrides(
            tasksStream: Stream.value([_task(id: 't_plan', title: '计划任务')]),
            todayPlanIdsStream: Stream.value(['t_plan']),
            activePomodoroStream: Stream.value(null),
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

    await tester.tap(find.byKey(const ValueKey('today_v2_primary_cta')));
    await tester.pumpAndSettle();

    expect(find.text('focus:t_plan'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('Today v2 主 CTA：无可执行条目时降级到 Today Plan', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(
          path: '/today',
          builder: (context, state) => const Scaffold(body: TodayEntryPoint()),
        ),
        GoRoute(
          path: '/today/plan',
          builder: (context, state) =>
              const Scaffold(body: Text('today-plan-page')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          ..._baseOverrides(
            tasksStream: Stream.value(const []),
            todayPlanIdsStream: Stream.value(const []),
            activePomodoroStream: Stream.value(null),
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

    await tester.tap(find.byKey(const ValueKey('today_v2_primary_cta')));
    await tester.pumpAndSettle();

    expect(find.text('today-plan-page'), findsOneWidget);
    await disposeApp(tester);
  });
}
