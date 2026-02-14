import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/feature_flags/feature_flag_keys.dart';
import 'package:daypick/core/local_events/local_events_provider.dart';
import 'package:daypick/core/local_events/local_events_service.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/features/focus/providers/focus_providers.dart';
import 'package:daypick/features/notes/providers/note_providers.dart';
import 'package:daypick/features/tasks/providers/task_providers.dart';
import 'package:daypick/features/today/providers/today_plan_providers.dart';
import 'package:daypick/features/today/view/today_entry_point.dart';
import 'package:daypick/routing/app_router.dart';
import 'package:daypick/routing/home_shell.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'test_utils.dart';

class _RecordedEvent {
  const _RecordedEvent(this.eventName, this.metaJson);

  final String eventName;
  final Map<String, Object?> metaJson;
}

class _FakeLocalEventsService implements LocalEventsService {
  final events = <_RecordedEvent>[];

  @override
  Future<bool> record({
    required String eventName,
    required Map<String, Object?> metaJson,
  }) async {
    events.add(_RecordedEvent(eventName, Map<String, Object?>.from(metaJson)));
    return true;
  }
}

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
  required LocalEventsService localEventsService,
  domain.AppearanceConfig appearanceConfig = const domain.AppearanceConfig(
    onboardingDone: true,
  ),
}) {
  return [
    localEventsServiceProvider.overrideWithValue(localEventsService),
    appearanceConfigProvider.overrideWith(
      (ref) => Stream.value(appearanceConfig),
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
  testWidgets(
    'Today v2：进入 Focus 时记录 primary_action / effective_execution / clarity=ok',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fake = _FakeLocalEventsService();

      final router = GoRouter(
        initialLocation: '/today',
        routes: [
          GoRoute(
            path: '/today',
            builder: (context, state) =>
                const Scaffold(body: TodayEntryPoint()),
          ),
          GoRoute(
            path: '/focus',
            builder: (context, state) => const Scaffold(body: Text('focus')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            goRouterProvider.overrideWithValue(router),
            ..._baseOverrides(
              localEventsService: fake,
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

      final primary = fake.events.where(
        (e) => e.eventName == domain.LocalEventNames.primaryActionInvoked,
      );
      expect(primary.length, 1);
      expect(primary.first.metaJson['action'], 'start_focus');
      expect(primary.first.metaJson['elapsed_ms'], isA<int>());

      final effective = fake.events.where(
        (e) =>
            e.eventName ==
            domain.LocalEventNames.effectiveExecutionStateEntered,
      );
      expect(effective.length, 1);
      expect(effective.first.metaJson['source'], 'today_primary_cta');
      expect(effective.first.metaJson['kind'], 'focus');

      final clarity = fake.events.where(
        (e) => e.eventName == domain.LocalEventNames.todayClarityResult,
      );
      expect(clarity.length, 1);
      expect(clarity.first.metaJson['result'], 'ok');
      expect(clarity.first.metaJson['elapsed_ms'], isA<int>());

      await disposeApp(tester);
    },
  );

  testWidgets('Today v2：3 秒内未进入有效执行态则写入 clarity=fail timeout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeLocalEventsService();

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
            localEventsService: fake,
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

    await tester.pump(const Duration(milliseconds: 3100));
    await tester.pumpAndSettle();

    final clarity = fake.events.where(
      (e) => e.eventName == domain.LocalEventNames.todayClarityResult,
    );
    expect(clarity.length, 1);
    expect(clarity.first.metaJson['result'], 'fail');
    expect(clarity.first.metaJson['failure_bucket'], 'timeout');
    expect(clarity.first.metaJson['elapsed_ms'], 3000);

    await disposeApp(tester);
  });

  testWidgets('Today v2：primary_action_invoked 同一会话内去重（Today Plan 分支）', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeLocalEventsService();

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
            localEventsService: fake,
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
    // Dismiss bottom sheet.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('today_v2_primary_cta')));
    await tester.pumpAndSettle();

    final primary = fake.events.where(
      (e) => e.eventName == domain.LocalEventNames.primaryActionInvoked,
    );
    expect(primary.length, 1);
    expect(primary.first.metaJson['action'], 'open_today_plan');

    await disposeApp(tester);
  });

  testWidgets('Today v2：tab_switched 写入 + clarity=fail(tab_switch)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeLocalEventsService();

    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              HomeShell(navigationShell: navigationShell, state: state),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/ai',
                  builder: (context, state) => const Scaffold(body: Text('ai')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/notes',
                  builder: (context, state) =>
                      const Scaffold(body: Text('notes')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/today',
                  builder: (context, state) =>
                      const Scaffold(body: TodayEntryPoint()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/tasks',
                  builder: (context, state) =>
                      const Scaffold(body: Text('tasks')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/focus',
                  builder: (context, state) =>
                      const Scaffold(body: Text('focus')),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          ..._baseOverrides(
            localEventsService: fake,
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

    await tester.tap(find.text('笔记'));
    await tester.pumpAndSettle();

    final tabSwitched = fake.events.where(
      (e) => e.eventName == domain.LocalEventNames.tabSwitched,
    );
    expect(tabSwitched.length, 1);
    expect(tabSwitched.first.metaJson['from_tab'], 'today');
    expect(tabSwitched.first.metaJson['to_tab'], 'notes');

    final clarity = fake.events.where(
      (e) => e.eventName == domain.LocalEventNames.todayClarityResult,
    );
    expect(clarity.length, 1);
    expect(clarity.first.metaJson['result'], 'fail');
    expect(clarity.first.metaJson['failure_bucket'], 'tab_switch');

    await disposeApp(tester);
  });

  testWidgets('Today v2：打开收件箱记录 primary_action(open_inbox) + today_left', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeLocalEventsService();

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
          ..._baseOverrides(
            localEventsService: fake,
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

    await tester.tap(find.text('打开收件箱'));
    await tester.pumpAndSettle();
    expect(find.text('inbox'), findsOneWidget);

    final primary = fake.events.where(
      (e) => e.eventName == domain.LocalEventNames.primaryActionInvoked,
    );
    expect(primary.length, 1);
    expect(primary.first.metaJson['action'], 'open_inbox');

    final todayLeft = fake.events.where(
      (e) => e.eventName == domain.LocalEventNames.todayLeft,
    );
    expect(todayLeft.length, 1);
    expect(todayLeft.first.metaJson['destination'], 'route:inbox');

    final clarity = fake.events.where(
      (e) => e.eventName == domain.LocalEventNames.todayClarityResult,
    );
    expect(clarity.length, 1);
    expect(clarity.first.metaJson['result'], 'fail');
    expect(clarity.first.metaJson['failure_bucket'], 'leave_today');

    await disposeApp(tester);
  });

  testWidgets('Today v2：滚动触发 today_scrolled + clarity=fail(scroll)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeLocalEventsService();

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
            localEventsService: fake,
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

    await tester.drag(
      find.byKey(const ValueKey('today_v2_top3_card')),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 3100));
    await tester.pumpAndSettle();

    final scrolled = fake.events.where(
      (e) => e.eventName == domain.LocalEventNames.todayScrolled,
    );
    expect(scrolled.length, 1);
    expect(scrolled.first.metaJson['delta_px'], isA<int>());

    final clarity = fake.events.where(
      (e) => e.eventName == domain.LocalEventNames.todayClarityResult,
    );
    expect(clarity.length, 1);
    expect(clarity.first.metaJson['result'], 'fail');
    expect(clarity.first.metaJson['failure_bucket'], 'scroll');

    await disposeApp(tester);
  });

  testWidgets(
    'Today v2：滚动后切 tab，clarity bucket=scroll + failure_flags=[tab_switch]',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fake = _FakeLocalEventsService();

      final router = GoRouter(
        initialLocation: '/today',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) =>
                HomeShell(navigationShell: navigationShell, state: state),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/ai',
                    builder: (context, state) =>
                        const Scaffold(body: Text('ai')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/notes',
                    builder: (context, state) =>
                        const Scaffold(body: Text('notes')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/today',
                    builder: (context, state) =>
                        const Scaffold(body: TodayEntryPoint()),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/tasks',
                    builder: (context, state) =>
                        const Scaffold(body: Text('tasks')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/focus',
                    builder: (context, state) =>
                        const Scaffold(body: Text('focus')),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            goRouterProvider.overrideWithValue(router),
            ..._baseOverrides(
              localEventsService: fake,
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

      await tester.drag(
        find.byKey(const ValueKey('today_v2_top3_card')),
        const Offset(0, -80),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('笔记'));
      await tester.pumpAndSettle();

      final clarity = fake.events.where(
        (e) => e.eventName == domain.LocalEventNames.todayClarityResult,
      );
      expect(clarity.length, 1);
      expect(clarity.first.metaJson['failure_bucket'], 'scroll');
      expect(clarity.first.metaJson['failure_flags'], ['tab_switch']);

      await disposeApp(tester);
    },
  );

  testWidgets(
    'Today v2：timeboxing 触发 fullscreen_opened + clarity=fail(fullscreen)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fake = _FakeLocalEventsService();

      final router = GoRouter(
        initialLocation: '/today',
        routes: [
          GoRoute(
            path: '/today',
            builder: (context, state) =>
                const Scaffold(body: TodayEntryPoint()),
            routes: [
              GoRoute(
                path: 'timeboxing',
                builder: (context, state) =>
                    const Scaffold(body: Text('timeboxing')),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            goRouterProvider.overrideWithValue(router),
            ..._baseOverrides(
              localEventsService: fake,
              tasksStream: Stream.value(const []),
              todayPlanIdsStream: Stream.value(const []),
              activePomodoroStream: Stream.value(null),
              appearanceConfig: const domain.AppearanceConfig(
                onboardingDone: true,
                calendarConstraintsDismissed: true,
              ),
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

      await tester.tap(find.text('设置时间盒'));
      await tester.pumpAndSettle();
      expect(find.text('timeboxing'), findsOneWidget);

      final fullscreen = fake.events.where(
        (e) => e.eventName == domain.LocalEventNames.fullscreenOpened,
      );
      expect(fullscreen.length, 1);
      expect(fullscreen.first.metaJson['screen'], 'today_timeboxing');
      expect(fullscreen.first.metaJson['reason'], 'calendar_constraints');

      final clarity = fake.events.where(
        (e) => e.eventName == domain.LocalEventNames.todayClarityResult,
      );
      expect(clarity.length, 1);
      expect(clarity.first.metaJson['failure_bucket'], 'fullscreen');

      await disposeApp(tester);
    },
  );

  testWidgets('Today v2：打开设置触发 today_left + clarity=fail(leave_today)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeLocalEventsService();

    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(
          path: '/today',
          builder: (context, state) => const Scaffold(body: TodayEntryPoint()),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const Scaffold(body: Text('settings')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          ..._baseOverrides(
            localEventsService: fake,
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

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);

    final todayLeft = fake.events.where(
      (e) => e.eventName == domain.LocalEventNames.todayLeft,
    );
    expect(todayLeft.length, 1);
    expect(todayLeft.first.metaJson['destination'], 'route:settings');

    final clarity = fake.events.where(
      (e) => e.eventName == domain.LocalEventNames.todayClarityResult,
    );
    expect(clarity.length, 1);
    expect(clarity.first.metaJson['failure_bucket'], 'leave_today');

    await disposeApp(tester);
  });

  testWidgets('Today v2：点击「进入 Today Plan」记录 primary_action(open_today_plan)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeLocalEventsService();

    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(
          path: '/today',
          builder: (context, state) => const Scaffold(body: TodayEntryPoint()),
          routes: [
            GoRoute(
              path: 'plan',
              builder: (context, state) =>
                  const Scaffold(body: Text('today-plan')),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          ..._baseOverrides(
            localEventsService: fake,
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

    await tester.tap(find.text('进入 Today Plan'));
    await tester.pumpAndSettle();

    expect(find.text('today-plan'), findsOneWidget);

    final primary = fake.events.where(
      (e) => e.eventName == domain.LocalEventNames.primaryActionInvoked,
    );
    expect(primary.length, 1);
    expect(primary.first.metaJson['action'], 'open_today_plan');

    await disposeApp(tester);
  });

  testWidgets('Today v2：离开并回到 Today 后会话重建（dedup 不跨会话）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeLocalEventsService();

    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              HomeShell(navigationShell: navigationShell, state: state),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/ai',
                  builder: (context, state) => const Scaffold(body: Text('ai')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/notes',
                  builder: (context, state) =>
                      const Scaffold(body: Text('notes')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/today',
                  builder: (context, state) =>
                      const Scaffold(body: TodayEntryPoint()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/tasks',
                  builder: (context, state) =>
                      const Scaffold(body: Text('tasks')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/focus',
                  builder: (context, state) =>
                      const Scaffold(body: Text('focus')),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          ..._baseOverrides(
            localEventsService: fake,
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

    expect(
      fake.events
          .where(
            (e) => e.eventName == domain.LocalEventNames.todayFirstInteractive,
          )
          .length,
      1,
    );

    await tester.tap(find.text('笔记'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('笔记'));
    await tester.pumpAndSettle();

    expect(
      fake.events
          .where(
            (e) => e.eventName == domain.LocalEventNames.todayFirstInteractive,
          )
          .length,
      2,
    );
    expect(
      fake.events
          .where((e) => e.eventName == domain.LocalEventNames.tabSwitched)
          .length,
      2,
    );
    expect(
      fake.events
          .where(
            (e) => e.eventName == domain.LocalEventNames.todayClarityResult,
          )
          .length,
      2,
    );

    await disposeApp(tester);
  });

  testWidgets('Today v2：应用进入后台并恢复后会开启新会话', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeLocalEventsService();

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
            localEventsService: fake,
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

    expect(
      fake.events
          .where(
            (e) => e.eventName == domain.LocalEventNames.todayFirstInteractive,
          )
          .length,
      1,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(
      fake.events
          .where(
            (e) => e.eventName == domain.LocalEventNames.todayClarityResult,
          )
          .length,
      1,
    );
    expect(
      fake.events
          .where(
            (e) => e.eventName == domain.LocalEventNames.todayFirstInteractive,
          )
          .length,
      2,
    );

    await disposeApp(tester);
  });
}
