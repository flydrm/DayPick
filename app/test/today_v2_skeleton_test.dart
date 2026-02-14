import 'dart:async';

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
import 'package:shadcn_ui/shadcn_ui.dart';

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

domain.Note _note({required String id, required String title}) {
  final now = DateTime(2026, 1, 1);
  return domain.Note(
    id: id,
    title: domain.NoteTitle(title),
    body: '',
    tags: const [],
    createdAt: now,
    updatedAt: now,
    triageStatus: domain.TriageStatus.inbox,
  );
}

List<Override> _baseTodayOverrides({
  required Stream<List<domain.Task>> tasksStream,
  required Stream<List<domain.Note>> unprocessedNotesStream,
}) {
  return [
    appearanceConfigProvider.overrideWith(
      (ref) => Stream.value(
        const domain.AppearanceConfig(onboardingDone: true),
      ),
    ),
    tasksStreamProvider.overrideWith((ref) => tasksStream),
    notesStreamProvider.overrideWith(
      (ref) => Stream.value(const <domain.Note>[]),
    ),
    unprocessedNotesStreamProvider.overrideWith((ref) => unprocessedNotesStream),
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
    todayPlanTaskIdsProvider.overrideWith((ref) => Stream.value(const [])),
    todayEveningPlanTaskIdsProvider.overrideWith((ref) => Stream.value(const [])),
    todayPlanTaskIdsForDayProvider.overrideWith(
      (ref, day) => Stream.value(const []),
    ),
    todayEveningPlanTaskIdsForDayProvider.overrideWith(
      (ref, day) => Stream.value(const []),
    ),
    activePomodoroProvider.overrideWith((ref) => Stream.value(null)),
  ];
}

void main() {
  testWidgets('Today v2：首屏骨架（Top3/时间约束/待处理 + 主 CTA）无需滚动可见', (tester) async {
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
          path: '/inbox',
          builder: (context, state) => const Scaffold(body: Text('inbox')),
        ),
        GoRoute(
          path: '/today/timeboxing',
          builder: (context, state) =>
              const Scaffold(body: Text('timeboxing')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          ..._baseTodayOverrides(
            tasksStream: Stream.value([
              _task(id: 't1', title: '任务 1'),
              _task(id: 't2', title: '任务 2'),
              _task(id: 't3', title: '任务 3'),
            ]),
            unprocessedNotesStream: Stream.value([_note(id: 'n1', title: 'n')]),
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

    final top3 = find.byKey(const ValueKey('today_v2_top3_card'));
    final time = find.byKey(const ValueKey('today_v2_time_constraints_card'));
    final inbox = find.byKey(const ValueKey('today_v2_inbox_card'));
    final cta = find.byKey(const ValueKey('today_v2_primary_cta'));

    expect(top3, findsOneWidget);
    expect(time, findsOneWidget);
    expect(inbox, findsOneWidget);
    expect(cta, findsOneWidget);
    expect(find.text('开始第 1 件事'), findsOneWidget);
    expect(find.byType(Scrollable), findsNothing);

    final viewport = tester.binding.renderViews.single.size;
    for (final finder in [top3, time, inbox, cta]) {
      final rect = tester.getRect(finder);
      expect(rect.top >= 0, isTrue);
      expect(rect.bottom <= viewport.height, isTrue);
    }

    await disposeApp(tester);
  });

  testWidgets('Today v2：loading/error/empty 不全屏打断（局部卡片内反馈）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final tasksController = StreamController<List<domain.Task>>();
    addTearDown(tasksController.close);

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
          ..._baseTodayOverrides(
            tasksStream: tasksController.stream,
            unprocessedNotesStream: Stream.value(const <domain.Note>[]),
          ),
          featureFlagEnabledProvider.overrideWith((ref, key) {
            if (key == FeatureFlagKeys.todayV2) return Stream.value(true);
            return Stream.value(false);
          }),
        ],
        child: const DayPickApp(),
      ),
    );

    // loading：页面必须可见（存在骨架卡片），且局部卡片内反馈。
    await tester.pump();
    final top3Card = find.byKey(const ValueKey('today_v2_top3_card'));
    expect(top3Card, findsOneWidget);
    expect(
      find.descendant(of: top3Card, matching: find.byType(ShadProgress)),
      findsOneWidget,
    );

    // empty
    tasksController.add(const <domain.Task>[]);
    await tester.pumpAndSettle();
    expect(top3Card, findsOneWidget);
    expect(find.text('还没有可执行的 Top3。'), findsOneWidget);

    // error
    tasksController.addError('load failed');
    await tester.pumpAndSettle();
    expect(top3Card, findsOneWidget);
    expect(find.textContaining('加载失败'), findsOneWidget);

    await disposeApp(tester);
  });
}
