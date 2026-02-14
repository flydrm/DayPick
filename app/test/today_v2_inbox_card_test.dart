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

domain.Task _task({required String id, required domain.TriageStatus triageStatus}) {
  final now = DateTime(2026, 1, 1);
  return domain.Task(
    id: id,
    title: domain.TaskTitle('task:$id'),
    status: domain.TaskStatus.todo,
    priority: domain.TaskPriority.medium,
    tags: const [],
    estimatedPomodoros: null,
    createdAt: now,
    updatedAt: now,
    triageStatus: triageStatus,
  );
}

domain.Note _note({required String id}) {
  final now = DateTime(2026, 1, 1);
  return domain.Note(
    id: id,
    title: domain.NoteTitle('note:$id'),
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
    notesStreamProvider.overrideWith((ref) => Stream.value(const <domain.Note>[])),
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
  testWidgets('Today v2：待处理负载卡 loading（局部进度）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final tasksController = StreamController<List<domain.Task>>();
    addTearDown(tasksController.close);
    final notesController = StreamController<List<domain.Note>>();
    addTearDown(notesController.close);

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
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          ..._baseTodayOverrides(
            tasksStream: tasksController.stream,
            unprocessedNotesStream: notesController.stream,
          ),
          featureFlagEnabledProvider.overrideWith((ref, key) {
            if (key == FeatureFlagKeys.todayV2) return Stream.value(true);
            return Stream.value(false);
          }),
        ],
        child: const DayPickApp(),
      ),
    );

    await tester.pump();
    final inboxCard = find.byKey(const ValueKey('today_v2_inbox_card'));
    expect(inboxCard, findsOneWidget);
    expect(
      find.descendant(of: inboxCard, matching: find.text('待处理负载加载中…')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: inboxCard, matching: find.byType(ShadProgress)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: inboxCard, matching: find.text('原因：正在读取本地数据。')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: inboxCard, matching: find.text('打开收件箱')),
    );
    await tester.pumpAndSettle();
    expect(find.text('inbox'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('Today v2：待处理负载卡 empty（仍可进入）', (tester) async {
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
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          ..._baseTodayOverrides(
            tasksStream: Stream.value(const <domain.Task>[]),
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
    await tester.pumpAndSettle();

    expect(find.text('待处理已清空'), findsOneWidget);

    await tester.tap(find.text('打开收件箱'));
    await tester.pumpAndSettle();
    expect(find.text('inbox'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('Today v2：待处理负载卡 non-empty（数量 + 摘要 + 可进入）', (tester) async {
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
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          ..._baseTodayOverrides(
            tasksStream: Stream.value([
              _task(id: 't1', triageStatus: domain.TriageStatus.inbox),
              _task(id: 't2', triageStatus: domain.TriageStatus.scheduledLater),
            ]),
            unprocessedNotesStream: Stream.value([_note(id: 'n1')]),
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

    expect(find.text('待处理：2'), findsOneWidget);
    expect(find.text('任务 + 闪念/长文'), findsOneWidget);

    await tester.tap(find.text('打开收件箱'));
    await tester.pumpAndSettle();
    expect(find.text('inbox'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('Today v2：待处理负载卡 error（卡片内错误 + 下一步仍可进入）', (tester) async {
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
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          ..._baseTodayOverrides(
            tasksStream: Stream.error(StateError('boom')),
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
    await tester.pumpAndSettle();

    expect(find.text('待处理负载读取失败'), findsOneWidget);
    expect(find.text('下一步：打开收件箱'), findsOneWidget);

    await tester.tap(find.text('下一步：打开收件箱'));
    await tester.pumpAndSettle();
    expect(find.text('inbox'), findsOneWidget);

    await disposeApp(tester);
  });
}
