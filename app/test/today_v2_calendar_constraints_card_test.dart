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

import 'fakes/fake_calendar_constraints_repository.dart';
import 'fakes/fake_appearance_config_repository.dart';
import 'test_utils.dart';

List<Override> _baseTodayOverrides({
  required domain.AppearanceConfig appearance,
}) {
  return [
    todayDayProvider.overrideWith(
      (ref) => Stream.value(DateTime(2026, 1, 1)),
    ),
    appearanceConfigProvider.overrideWith((ref) => Stream.value(appearance)),
    tasksStreamProvider.overrideWith((ref) => Stream.value(const <domain.Task>[])),
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

class _DelayedTitledEventsCalendarConstraintsRepository
    implements domain.CalendarConstraintsRepository {
  _DelayedTitledEventsCalendarConstraintsRepository({
    required this.summary,
    required List<Completer<List<domain.CalendarTitledEvent>>> titledEventsCompleters,
  }) : _titledEventsCompleters = List.of(titledEventsCompleters);

  final domain.CalendarBusyFreeSummary summary;
  final List<Completer<List<domain.CalendarTitledEvent>>> _titledEventsCompleters;

  int getTitledEventsCalls = 0;

  @override
  Future<domain.CalendarPermissionState> getPermissionState() async {
    return domain.CalendarPermissionState.granted;
  }

  @override
  Future<domain.CalendarPermissionState> requestPermission() async {
    return domain.CalendarPermissionState.granted;
  }

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<domain.CalendarBusyFreeSummary> getBusyFreeSummaryForDay({
    required DateTime dayLocal,
  }) async {
    return summary;
  }

  @override
  Future<List<domain.CalendarTitledEvent>> getTitledEventsForDay({
    required DateTime dayLocal,
  }) async {
    getTitledEventsCalls++;
    if (_titledEventsCompleters.isEmpty) return const [];
    return _titledEventsCompleters.removeAt(0).future;
  }

  @override
  Future<domain.CalendarBusyFreeSummary> computeBusyFreeSummary({
    required DateTime dayLocal,
    required List<domain.CalendarDateTimeRange> busyRangesLocal,
  }) async {
    return const domain.CalendarBusyFreeCalculator().summarize(
      day: dayLocal,
      busyRangesLocal: busyRangesLocal,
    );
  }
}

void main() {
  testWidgets('时间约束卡：未授权 → pre-permission + 连接/跳过（不自动弹权限）', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = FakeCalendarConstraintsRepository(
      permissionState: domain.CalendarPermissionState.unknown,
    );

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
          calendarConstraintsRepositoryProvider.overrideWithValue(repo),
          ..._baseTodayOverrides(
            appearance: const domain.AppearanceConfig(onboardingDone: true),
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

    expect(find.text('用于帮你看清今天的时间约束（忙/闲与空档）'), findsOneWidget);
    expect(find.text('默认只读取忙闲与空档，不读取标题；你可随时开启/关闭'), findsOneWidget);
    expect(find.text('可跳过；拒绝也不影响使用'), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar_constraints_connect')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar_constraints_skip')), findsOneWidget);

    // 首屏不得触发系统权限弹窗：只能在点击“连接日历”后 requestPermission。
    expect(repo.requestPermissionCalls, 0);

    await disposeApp(tester);
  });

  testWidgets('时间约束卡：已授权 → busy/free 概览 + 空档段数（默认不展示标题）', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = FakeCalendarConstraintsRepository(
      permissionState: domain.CalendarPermissionState.granted,
      summary: const domain.CalendarBusyFreeSummary(
        dayKey: '2026-01-01',
        busyIntervals: [domain.CalendarBusyInterval(startMinute: 60, endMinute: 120)],
        freeSlotsCount: 2,
      ),
    );

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
          calendarConstraintsRepositoryProvider.overrideWithValue(repo),
          ..._baseTodayOverrides(
            appearance: const domain.AppearanceConfig(onboardingDone: true),
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

    expect(find.text('仅忙闲（推荐）'), findsOneWidget);
    expect(find.text('今日空档 2 段'), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar_constraints_connect')), findsNothing);
    expect(find.byKey(const ValueKey('calendar_constraints_skip')), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('时间约束卡：显示标题开启时，仅展示轻提示（不展示内容）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = FakeCalendarConstraintsRepository(
      permissionState: domain.CalendarPermissionState.granted,
      summary: const domain.CalendarBusyFreeSummary(
        dayKey: '2026-01-01',
        busyIntervals: [domain.CalendarBusyInterval(startMinute: 60, endMinute: 120)],
        freeSlotsCount: 2,
      ),
    );

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
          calendarConstraintsRepositoryProvider.overrideWithValue(repo),
          ..._baseTodayOverrides(
            appearance: const domain.AppearanceConfig(
              onboardingDone: true,
              calendarShowEventTitles: true,
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

    expect(find.text('标题已开启'), findsOneWidget);
    expect(find.text('Standup'), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('时间约束卡：denied/revoked → 降级态 + 去设置/继续无约束', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = FakeCalendarConstraintsRepository(
      permissionState: domain.CalendarPermissionState.denied,
    );

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
          calendarConstraintsRepositoryProvider.overrideWithValue(repo),
          ..._baseTodayOverrides(
            appearance: const domain.AppearanceConfig(onboardingDone: true),
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

    expect(find.text('未获得日历权限'), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar_constraints_open_settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar_constraints_continue_without')), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('时间约束卡：error → 错误态可重试（不全屏打断）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = FakeCalendarConstraintsRepository(
      permissionState: domain.CalendarPermissionState.granted,
      readError: Exception('read failed'),
    );

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
          calendarConstraintsRepositoryProvider.overrideWithValue(repo),
          ..._baseTodayOverrides(
            appearance: const domain.AppearanceConfig(onboardingDone: true),
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

    expect(find.text('日历读取失败'), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar_constraints_retry')), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('时间约束卡：已跳过 → 不再提示 pre-permission', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = FakeCalendarConstraintsRepository(
      permissionState: domain.CalendarPermissionState.unknown,
    );

    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(
          path: '/today',
          builder: (context, state) => const Scaffold(body: TodayEntryPoint()),
        ),
        GoRoute(
          path: '/today/timeboxing',
          builder: (context, state) => const Scaffold(body: Text('timeboxing')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          calendarConstraintsRepositoryProvider.overrideWithValue(repo),
          ..._baseTodayOverrides(
            appearance: const domain.AppearanceConfig(
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

    expect(find.text('已跳过日历约束'), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar_constraints_timeboxing')), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('时间约束 Sheet：默认不展示标题（开关默认关闭）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final appearanceRepo = FakeAppearanceConfigRepository(
      const domain.AppearanceConfig(onboardingDone: true),
    );
    addTearDown(appearanceRepo.dispose);

    final repo = FakeCalendarConstraintsRepository(
      permissionState: domain.CalendarPermissionState.granted,
      summary: const domain.CalendarBusyFreeSummary(
        dayKey: '2026-01-01',
        busyIntervals: [domain.CalendarBusyInterval(startMinute: 60, endMinute: 120)],
        freeSlotsCount: 2,
      ),
      titledEvents: [
        domain.CalendarTitledEvent(
          start: DateTime(2026, 1, 1, 9),
          end: DateTime(2026, 1, 1, 10),
          title: 'Standup',
        ),
      ],
    );

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
          calendarConstraintsRepositoryProvider.overrideWithValue(repo),
          ..._baseTodayOverrides(
            appearance: const domain.AppearanceConfig(
              onboardingDone: true,
              calendarShowEventTitles: false,
            ),
          ),
          appearanceConfigRepositoryProvider.overrideWithValue(appearanceRepo),
          appearanceConfigProvider.overrideWith((ref) => appearanceRepo.watch()),
          featureFlagEnabledProvider.overrideWith((ref, key) {
            if (key == FeatureFlagKeys.todayV2) return Stream.value(true);
            return Stream.value(false);
          }),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 打开 sheet
    await tester.tap(find.text('仅忙闲（推荐）'));
    await tester.pumpAndSettle();

    final switchWidget = tester.widget<ShadSwitch>(
      find.byKey(const ValueKey('calendar_constraints_show_titles_switch')),
    );
    expect(switchWidget.value, false);
    expect(find.text('Standup'), findsNothing);
    expect(repo.getTitledEventsCalls, 0);

    await disposeApp(tester);
  });

  testWidgets('时间约束 Sheet：打开显示标题 → 展示标题；关闭 → 立即隐藏', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final appearanceRepo = FakeAppearanceConfigRepository(
      const domain.AppearanceConfig(onboardingDone: true),
    );
    addTearDown(appearanceRepo.dispose);

    final repo = FakeCalendarConstraintsRepository(
      permissionState: domain.CalendarPermissionState.granted,
      summary: const domain.CalendarBusyFreeSummary(
        dayKey: '2026-01-01',
        busyIntervals: [domain.CalendarBusyInterval(startMinute: 60, endMinute: 120)],
        freeSlotsCount: 2,
      ),
      titledEvents: [
        domain.CalendarTitledEvent(
          start: DateTime(2026, 1, 1, 9),
          end: DateTime(2026, 1, 1, 10),
          title: 'Standup',
        ),
        domain.CalendarTitledEvent(
          start: DateTime(2026, 1, 1, 10),
          end: DateTime(2026, 1, 1, 11),
          title: '',
        ),
      ],
    );

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
          calendarConstraintsRepositoryProvider.overrideWithValue(repo),
          ..._baseTodayOverrides(
            appearance: const domain.AppearanceConfig(
              onboardingDone: true,
              calendarShowEventTitles: false,
            ),
          ),
          appearanceConfigRepositoryProvider.overrideWithValue(appearanceRepo),
          appearanceConfigProvider.overrideWith((ref) => appearanceRepo.watch()),
          featureFlagEnabledProvider.overrideWith((ref, key) {
            if (key == FeatureFlagKeys.todayV2) return Stream.value(true);
            return Stream.value(false);
          }),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 打开 sheet
    await tester.tap(find.text('仅忙闲（推荐）'));
    await tester.pumpAndSettle();

    // 开启：显示标题
    await tester.tap(
      find.byKey(const ValueKey('calendar_constraints_show_titles_switch')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Standup'), findsOneWidget);
    expect(find.text('（无标题）'), findsOneWidget);
    expect(repo.getTitledEventsCalls, 1);

    // 关闭：立即隐藏
    await tester.tap(
      find.byKey(const ValueKey('calendar_constraints_show_titles_switch')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Standup'), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('时间约束 Sheet：关闭开关后不应残留旧标题（避免竞态写回）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final appearanceRepo = FakeAppearanceConfigRepository(
      const domain.AppearanceConfig(onboardingDone: true),
    );
    addTearDown(appearanceRepo.dispose);

    final firstTitles = Completer<List<domain.CalendarTitledEvent>>();
    final secondTitles = Completer<List<domain.CalendarTitledEvent>>();
    final repo = _DelayedTitledEventsCalendarConstraintsRepository(
      summary: const domain.CalendarBusyFreeSummary(
        dayKey: '2026-01-01',
        busyIntervals: [domain.CalendarBusyInterval(startMinute: 60, endMinute: 120)],
        freeSlotsCount: 2,
      ),
      titledEventsCompleters: [firstTitles, secondTitles],
    );

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
          calendarConstraintsRepositoryProvider.overrideWithValue(repo),
          ..._baseTodayOverrides(
            appearance: const domain.AppearanceConfig(
              onboardingDone: true,
              calendarShowEventTitles: false,
            ),
          ),
          appearanceConfigRepositoryProvider.overrideWithValue(appearanceRepo),
          appearanceConfigProvider.overrideWith((ref) => appearanceRepo.watch()),
          featureFlagEnabledProvider.overrideWith((ref, key) {
            if (key == FeatureFlagKeys.todayV2) return Stream.value(true);
            return Stream.value(false);
          }),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 打开 sheet
    await tester.tap(find.text('仅忙闲（推荐）'));
    await tester.pumpAndSettle();

    final switchFinder =
        find.byKey(const ValueKey('calendar_constraints_show_titles_switch'));

    // 第一次开启：触发拉取（但不立刻返回）
    await tester.tap(switchFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(repo.getTitledEventsCalls, 1);

    // 立即关闭（在 titledEvents future 仍未完成时）
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    // 此时，即使后续旧请求返回，也不应把旧标题残留到 state。
    firstTitles.complete([
      domain.CalendarTitledEvent(
        start: DateTime(2026, 1, 1, 9),
        end: DateTime(2026, 1, 1, 10),
        title: 'Standup',
      ),
    ]);
    await tester.pumpAndSettle();

    // 再次开启：在第二次请求完成前，不应“立刻”显示旧标题。
    await tester.tap(switchFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(repo.getTitledEventsCalls, 2);
    expect(find.text('Standup'), findsNothing);

    // 第二次请求返回后，才展示。
    secondTitles.complete([
      domain.CalendarTitledEvent(
        start: DateTime(2026, 1, 1, 9),
        end: DateTime(2026, 1, 1, 10),
        title: 'Standup',
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Standup'), findsOneWidget);

    await disposeApp(tester);
  });
}
