import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/features/focus/providers/focus_providers.dart';
import 'package:daypick/features/notes/providers/note_providers.dart';
import 'package:daypick/features/tasks/providers/task_providers.dart';
import 'package:daypick/features/today/providers/today_plan_providers.dart';
import 'package:daypick/features/today/view/today_page.dart';
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
  domain.TaskPriority priority = domain.TaskPriority.medium,
  domain.TaskStatus status = domain.TaskStatus.todo,
  DateTime? dueAt,
}) {
  return domain.Task(
    id: id,
    title: domain.TaskTitle(title),
    status: status,
    priority: priority,
    tags: const [],
    estimatedPomodoros: 1,
    createdAt: now,
    updatedAt: now,
    dueAt: dueAt,
    triageStatus: domain.TriageStatus.scheduledLater,
  );
}

void main() {
  testWidgets('Today 在没有计划时直接展示建议队列并可进入任务详情', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tasks = [
      _task(
        id: 't-overdue',
        title: '逾期任务',
        now: now,
        priority: domain.TaskPriority.low,
        dueAt: today.subtract(const Duration(days: 1)),
      ),
      _task(
        id: 't-today',
        title: '今日到期',
        now: now,
        priority: domain.TaskPriority.low,
        dueAt: today,
      ),
      _task(
        id: 't-high',
        title: '高优先级',
        now: now,
        priority: domain.TaskPriority.high,
      ),
      _task(
        id: 't-future',
        title: '未来到期',
        now: now,
        priority: domain.TaskPriority.medium,
        dueAt: today.add(const Duration(days: 5)),
      ),
    ];

    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(
          path: '/today',
          builder: (context, state) => const Scaffold(body: TodayPage()),
        ),
        GoRoute(
          path: '/tasks/:taskId',
          builder: (context, state) {
            final taskId = state.pathParameters['taskId']!;
            return Scaffold(body: Text('task:$taskId'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(
              const domain.AppearanceConfig(
                todayModules: [
                  domain.TodayWorkbenchModule.nextStep,
                  domain.TodayWorkbenchModule.todayPlan,
                  domain.TodayWorkbenchModule.yesterdayReview,
                ],
              ),
            ),
          ),
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
          anyPomodoroSessionCountProvider.overrideWith(
            (ref) => Stream.value(0),
          ),
          pomodoroConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.PomodoroConfig()),
          ),
          todayPlanTaskIdsProvider.overrideWith(
            (ref) => Stream.value(const <String>[]),
          ),
          todayEveningPlanTaskIdsProvider.overrideWith(
            (ref) => Stream.value(const <String>[]),
          ),
          todayPlanTaskIdsForDayProvider.overrideWith(
            (ref, day) => Stream.value(const <String>[]),
          ),
          todayEveningPlanTaskIdsForDayProvider.overrideWith(
            (ref, day) => Stream.value(const <String>[]),
          ),
          activePomodoroProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今天计划'), findsOneWidget);
    expect(find.text('还没有“今天计划”。'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('today_queue_suggested:t-overdue')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('today_queue_suggested:t-today')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('today_queue_suggested:t-high')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('today_queue_suggested:t-overdue')),
    );
    await tester.pumpAndSettle();
    expect(find.text('task:t-overdue'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('Today 在无任务时显示清晰空态（无弹窗）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(
          path: '/today',
          builder: (context, state) => const Scaffold(body: TodayPage()),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(
              const domain.AppearanceConfig(
                todayModules: [
                  domain.TodayWorkbenchModule.nextStep,
                  domain.TodayWorkbenchModule.todayPlan,
                  domain.TodayWorkbenchModule.yesterdayReview,
                ],
              ),
            ),
          ),
          tasksStreamProvider.overrideWith(
            (ref) => Stream.value(const <domain.Task>[]),
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
          anyPomodoroSessionCountProvider.overrideWith(
            (ref) => Stream.value(0),
          ),
          pomodoroConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.PomodoroConfig()),
          ),
          todayPlanTaskIdsProvider.overrideWith(
            (ref) => Stream.value(const <String>[]),
          ),
          todayEveningPlanTaskIdsProvider.overrideWith(
            (ref) => Stream.value(const <String>[]),
          ),
          todayPlanTaskIdsForDayProvider.overrideWith(
            (ref, day) => Stream.value(const <String>[]),
          ),
          todayEveningPlanTaskIdsForDayProvider.overrideWith(
            (ref, day) => Stream.value(const <String>[]),
          ),
          activePomodoroProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('下一步'), findsOneWidget);
    expect(find.text('还没有“下一步”。'), findsOneWidget);
    expect(find.text('今天计划'), findsOneWidget);
    expect(find.text('今天还没有可执行任务。去添加一条，或用 AI 拆任务更快。'), findsOneWidget);
    expect(find.text('昨天回顾'), findsOneWidget);

    await disposeApp(tester);
  });
}
