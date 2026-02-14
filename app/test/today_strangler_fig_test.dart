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

import 'test_utils.dart';

void main() {
  domain.Task task({required String id, required String title}) {
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

  List<Override> baseTodayOverrides({
    required Stream<List<domain.Task>> tasksStream,
  }) {
    return [
      appearanceConfigProvider.overrideWith(
        (ref) => Stream.value(
          const domain.AppearanceConfig(
            onboardingDone: true,
            todayModules: [domain.TodayWorkbenchModule.nextStep],
          ),
        ),
      ),
      tasksStreamProvider.overrideWith((ref) => tasksStream),
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
    ];
  }

  testWidgets('TodayEntryPoint：flag 未就绪/开启/关闭都能安全切换', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = StreamController<bool>.broadcast();
    addTearDown(controller.close);

    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(
          path: '/today',
          builder: (context, state) => const Scaffold(body: TodayEntryPoint()),
        ),
        GoRoute(
          path: '/settings/flags',
          builder: (context, state) =>
              const Scaffold(body: Text('flags_settings')),
        ),
      ],
    );

    final tasks = [task(id: 't1', title: '测试任务')];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          ...baseTodayOverrides(tasksStream: Stream.value(tasks)),
          featureFlagEnabledProvider.overrideWith((ref, key) {
            if (key == FeatureFlagKeys.todayV2) return controller.stream;
            return Stream.value(false);
          }),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    // flag 未就绪：必须安全回退到旧路径（无 v2 标识）
    expect(find.byKey(const ValueKey('today_v2_top3_card')), findsNothing);
    expect(find.text('测试任务'), findsOneWidget);

    // flag 开启：进入新入口（有 v2 标识），且数据仍可见
    controller.add(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today_v2_top3_card')), findsOneWidget);
    expect(find.byKey(const ValueKey('today_v2_primary_cta')), findsOneWidget);
    expect(find.text('测试任务'), findsOneWidget);

    // flag 关闭：回到旧路径（v2 标识消失），且数据仍可见
    controller.add(false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today_v2_top3_card')), findsNothing);
    expect(find.text('测试任务'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('TodayEntryPoint：读取失败时回退到旧路径', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
          ...baseTodayOverrides(
            tasksStream: Stream.value(const <domain.Task>[]),
          ),
          featureFlagEnabledProvider.overrideWith((ref, key) {
            if (key == FeatureFlagKeys.todayV2) {
              return Stream.error('read failed');
            }
            return Stream.value(false);
          }),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('today_v2_top3_card')), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('TodayEntryPoint：flag on 新增数据后回退仍一致可见', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(
          path: '/today',
          builder: (context, state) => const Scaffold(body: TodayEntryPoint()),
        ),
      ],
    );

    final flagController = StreamController<bool>.broadcast();
    addTearDown(flagController.close);

    final tasksController = StreamController<List<domain.Task>>();
    addTearDown(tasksController.close);
    tasksController.add(const <domain.Task>[]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          ...baseTodayOverrides(tasksStream: tasksController.stream),
          featureFlagEnabledProvider.overrideWith((ref, key) {
            if (key == FeatureFlagKeys.todayV2) return flagController.stream;
            return Stream.value(false);
          }),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    // flag ON：进入新入口
    flagController.add(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today_v2_top3_card')), findsOneWidget);

    // “创建/编辑数据”：tasks 流新增一条任务（模拟新路径写入）
    tasksController.add([task(id: 't_new', title: '新建任务')]);
    await tester.pumpAndSettle();
    expect(find.text('新建任务'), findsOneWidget);

    // flag OFF：回到旧路径，同一份数据仍可见
    flagController.add(false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today_v2_top3_card')), findsNothing);
    expect(find.text('新建任务'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('TodayEntryPoint：kill-switch 强制回退', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = _InMemoryFeatureFlagRepository();
    addTearDown(repo.dispose);

    await repo.ensureAllFlags([
      domain.FeatureFlag(
        key: FeatureFlagKeys.todayV2,
        owner: 'today',
        expiryAt: DateTime.utc(2099, 1, 1),
        defaultValue: false,
        killSwitch: false,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
    ]);
    await repo.setOverrideValue(FeatureFlagKeys.todayV2, true);

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
          ...baseTodayOverrides(
            tasksStream: Stream.value(const <domain.Task>[]),
          ),
          featureFlagRepositoryProvider.overrideWithValue(repo),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('today_v2_top3_card')), findsOneWidget);

    await repo.setKillSwitch(FeatureFlagKeys.todayV2, true);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('today_v2_top3_card')), findsNothing);

    await disposeApp(tester);
  });
}

class _InMemoryFeatureFlagRepository implements domain.FeatureFlagRepository {
  final _flags = <String, domain.FeatureFlag>{};
  final _controller = StreamController<List<domain.FeatureFlag>>.broadcast();

  void dispose() {
    _controller.close();
  }

  @override
  Stream<List<domain.FeatureFlag>> watchAllFlags() async* {
    yield _snapshot();
    yield* _controller.stream;
  }

  @override
  Future<List<domain.FeatureFlag>> getAllFlags() async => _snapshot();

  @override
  Future<void> ensureAllFlags(List<domain.FeatureFlag> seeds) async {
    for (final seed in seeds) {
      final existing = _flags[seed.key];
      if (existing == null) {
        _flags[seed.key] = seed;
        continue;
      }
      _flags[seed.key] = existing.copyWith(
        owner: seed.owner,
        expiryAt: seed.expiryAt,
        defaultValue: seed.defaultValue,
      );
    }
    _emit();
  }

  @override
  Future<void> setOverrideValue(String key, bool? value) async {
    final existing = _flags[key];
    if (existing == null) return;
    _flags[key] = existing.copyWith(
      overrideValue: value,
      updatedAt: DateTime.now().toUtc(),
    );
    _emit();
  }

  @override
  Future<void> setKillSwitch(String key, bool value) async {
    final existing = _flags[key];
    if (existing == null) return;
    _flags[key] = existing.copyWith(
      killSwitch: value,
      updatedAt: DateTime.now().toUtc(),
    );
    _emit();
  }

  List<domain.FeatureFlag> _snapshot() {
    final rows = _flags.values.toList();
    rows.sort((a, b) => a.key.compareTo(b.key));
    return rows;
  }

  void _emit() {
    _controller.add(_snapshot());
  }
}
