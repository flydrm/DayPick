import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/features/tasks/providers/task_providers.dart';
import 'package:daypick/features/today/providers/today_plan_providers.dart';
import 'package:daypick/features/today/view/today_plan_edit_sheet.dart';
import 'package:daypick/routing/app_router.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'test_utils.dart';

class _FakeTodayPlanRepository implements domain.TodayPlanRepository {
  final List<List<String>> replaceCalls = [];

  @override
  Stream<List<String>> watchTaskIdsForDay({
    required DateTime day,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) => Stream.value(const <String>[]);

  @override
  Future<List<String>> getTaskIdsForDay({
    required DateTime day,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async => const <String>[];

  @override
  Future<void> addTask({
    required DateTime day,
    required String taskId,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async {}

  @override
  Future<void> removeTask({
    required DateTime day,
    required String taskId,
  }) async {}

  @override
  Future<void> replaceTasks({
    required DateTime day,
    required List<String> taskIds,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async {
    replaceCalls.add(taskIds);
  }

  @override
  Future<void> clearDay({
    required DateTime day,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async {}

  @override
  Future<void> clearAll({required DateTime day}) async {}

  @override
  Future<void> moveTaskToSection({
    required DateTime day,
    required String taskId,
    required domain.TodayPlanSection section,
    int? toIndex,
  }) async {}
}

domain.Task _task({
  required String id,
  required String title,
  required DateTime now,
  domain.TaskPriority priority = domain.TaskPriority.medium,
  DateTime? dueAt,
}) {
  return domain.Task(
    id: id,
    title: domain.TaskTitle(title),
    status: domain.TaskStatus.todo,
    priority: priority,
    dueAt: dueAt,
    tags: const [],
    estimatedPomodoros: 1,
    triageStatus: domain.TriageStatus.scheduledLater,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('TodayPlanEditSheet can append suggested tasks', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tasks = [
      _task(
        id: 't-1',
        title: '逾期任务',
        now: now,
        priority: domain.TaskPriority.low,
        dueAt: today.subtract(const Duration(days: 1)),
      ),
      _task(
        id: 't-2',
        title: '今日到期',
        now: now,
        priority: domain.TaskPriority.low,
        dueAt: today,
      ),
      _task(
        id: 't-3',
        title: '高优先级',
        now: now,
        priority: domain.TaskPriority.high,
      ),
    ];
    final repo = _FakeTodayPlanRepository();
    final router = GoRouter(
      initialLocation: '/sheet',
      routes: [
        GoRoute(
          path: '/sheet',
          builder: (context, state) =>
              const Scaffold(body: TodayPlanEditSheet()),
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
          tasksStreamProvider.overrideWith((ref) => Stream.value(tasks)),
          todayPlanTaskIdsProvider.overrideWith(
            (ref) => Stream.value(const <String>[]),
          ),
          todayPlanRepositoryProvider.overrideWithValue(repo),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('建议候选'), findsOneWidget);
    final addAllButton = find.widgetWithText(ShadButton, '全部加入今天');
    expect(addAllButton, findsOneWidget);

    await tester.tap(addAllButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('today_plan_item:t-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('today_plan_item:t-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('today_plan_item:t-3')), findsOneWidget);
    expect(repo.replaceCalls, isNotEmpty);
    expect(repo.replaceCalls.last, ['t-1', 't-2', 't-3']);
    await disposeApp(tester);
  });

  testWidgets('TodayPlanEditSheet prunes missing task ids from provider', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final task = _task(id: 't-1', title: '存在的任务', now: now);
    final repo = _FakeTodayPlanRepository();
    final router = GoRouter(
      initialLocation: '/sheet',
      routes: [
        GoRoute(
          path: '/sheet',
          builder: (context, state) =>
              const Scaffold(body: TodayPlanEditSheet()),
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
          tasksStreamProvider.overrideWith((ref) => Stream.value([task])),
          todayPlanTaskIdsProvider.overrideWith(
            (ref) => Stream.value(const <String>['missing', 't-1']),
          ),
          todayEveningPlanTaskIdsProvider.overrideWith(
            (ref) => Stream.value(const <String>[]),
          ),
          todayPlanRepositoryProvider.overrideWithValue(repo),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.replaceCalls, isNotEmpty);
    expect(repo.replaceCalls, contains(equals(<String>['t-1'])));
    await disposeApp(tester);
  });
}
