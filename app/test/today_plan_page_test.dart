import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/features/tasks/providers/task_providers.dart';
import 'package:daypick/features/today/providers/today_plan_providers.dart';
import 'package:daypick/features/today/view/today_plan_page.dart';
import 'package:daypick/routing/app_router.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'test_utils.dart';

domain.Task _task({required String id, required String title}) {
  final now = DateTime(2026, 2, 8, 9);
  return domain.Task(
    id: id,
    title: domain.TaskTitle(title),
    status: domain.TaskStatus.todo,
    priority: domain.TaskPriority.medium,
    tags: const [],
    estimatedPomodoros: 1,
    triageStatus: domain.TriageStatus.plannedToday,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('TodayPlanPage：按 day_key 展示 Today 与 This Evening 全量计划', (
    tester,
  ) async {
    final targetDay = DateTime(2026, 2, 8);
    final router = GoRouter(
      initialLocation: '/today/plan?day=2026-02-08',
      routes: [
        GoRoute(
          path: '/today/plan',
          builder: (context, state) =>
              TodayPlanPage(rawDayKey: state.uri.queryParameters['day']),
        ),
        GoRoute(
          path: '/tasks/:taskId',
          builder: (context, state) =>
              Text('task:${state.pathParameters['taskId']}'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.AppearanceConfig()),
          ),
          tasksStreamProvider.overrideWith(
            (ref) => Stream.value([
              _task(id: 't-1', title: '今天任务'),
              _task(id: 't-2', title: '今晚任务'),
            ]),
          ),
          todayPlanTaskIdsForDayProvider.overrideWith((ref, day) {
            if (day == targetDay) return Stream.value(const <String>['t-1']);
            return Stream.value(const <String>[]);
          }),
          todayEveningPlanTaskIdsForDayProvider.overrideWith((ref, day) {
            if (day == targetDay) return Stream.value(const <String>['t-2']);
            return Stream.value(const <String>[]);
          }),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('day_key: 2026-02-08'), findsOneWidget);
    expect(find.byKey(const ValueKey('today_plan_item:t-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('today_plan_item:t-2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('today_plan_item:t-1')));
    await tester.pumpAndSettle();

    expect(find.text('task:t-1'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('TodayPlanPage：空态显示可恢复入口', (tester) async {
    final router = GoRouter(
      initialLocation: '/today/plan',
      routes: [
        GoRoute(
          path: '/today/plan',
          builder: (context, state) =>
              TodayPlanPage(rawDayKey: state.uri.queryParameters['day']),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.AppearanceConfig()),
          ),
          tasksStreamProvider.overrideWith(
            (ref) => Stream.value(const <domain.Task>[]),
          ),
          todayPlanTaskIdsForDayProvider.overrideWith(
            (ref, day) => Stream.value(const <String>[]),
          ),
          todayEveningPlanTaskIdsForDayProvider.overrideWith(
            (ref, day) => Stream.value(const <String>[]),
          ),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('today_plan_empty_state')),
      findsOneWidget,
    );
    await disposeApp(tester);
  });

  testWidgets('TodayPlanPage：错误态提供重试动作', (tester) async {
    final router = GoRouter(
      initialLocation: '/today/plan',
      routes: [
        GoRoute(
          path: '/today/plan',
          builder: (context, state) =>
              TodayPlanPage(rawDayKey: state.uri.queryParameters['day']),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.AppearanceConfig()),
          ),
          tasksStreamProvider.overrideWith(
            (ref) => Stream<List<domain.Task>>.error('boom'),
          ),
          todayPlanTaskIdsForDayProvider.overrideWith(
            (ref, day) => Stream.value(const <String>[]),
          ),
          todayEveningPlanTaskIdsForDayProvider.overrideWith(
            (ref, day) => Stream.value(const <String>[]),
          ),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('today_plan_error_notice')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('today_plan_retry')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('today_plan_retry')));
    await tester.pump();

    await disposeApp(tester);
  });
}
