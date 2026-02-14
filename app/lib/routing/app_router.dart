import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:domain/domain.dart' as domain;

import '../features/ai/view/ai_page.dart';
import '../features/ai/view/ai_breakdown_page.dart';
import '../features/ai/view/ai_ask_page.dart';
import '../features/ai/view/ai_daily_review_page.dart';
import '../features/ai/view/ai_quick_note_page.dart';
import '../features/ai/view/ai_today_plan_page.dart';
import '../features/ai/view/ai_weekly_review_page.dart';
import '../features/focus/view/focus_page.dart';
import '../features/inbox/view/inbox_page.dart';
import '../features/inbox/view/inbox_process_page.dart';
import '../features/notes/view/notes_page.dart';
import '../features/notes/view/memos_page.dart';
import '../features/notes/view/note_detail_page.dart';
import '../features/search/view/search_page.dart';
import '../features/stats/view/stats_page.dart';
import '../features/settings/view/ai_settings_page.dart';
import '../features/settings/view/appearance_settings_page.dart';
import '../features/settings/view/data_settings_page.dart';
import '../features/settings/view/feature_flags_settings_page.dart';
import '../features/settings/view/pomodoro_settings_page.dart';
import '../features/settings/view/privacy_page.dart';
import '../features/settings/view/settings_page.dart';
import '../features/tasks/view/tasks_page.dart';
import '../features/tasks/view/task_detail_page.dart';
import '../features/today/view/today_timeboxing_canvas_page.dart';
import '../features/today/view/today_entry_point.dart';
import '../features/today/view/today_plan_page.dart';
import 'home_shell.dart';
import '../core/providers/app_providers.dart';
import '../ui/sheets/quick_create_sheet.dart';
import '../ui/sheets/quick_create_route_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  var didApplyDefaultTab = false;
  String pathFor(domain.AppDefaultTab tab) {
    return switch (tab) {
      domain.AppDefaultTab.ai => '/ai',
      domain.AppDefaultTab.notes => '/notes',
      domain.AppDefaultTab.today => '/today',
      domain.AppDefaultTab.tasks => '/tasks',
      domain.AppDefaultTab.focus => '/focus',
    };
  }

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/today',
    redirect: (context, state) async {
      if (didApplyDefaultTab) return null;
      didApplyDefaultTab = true;

      final current = state.uri.path;
      if (current != '/today') return null;
      if (state.uri.queryParameters.isNotEmpty) return null;

      domain.AppearanceConfig config;
      try {
        config = await ref.read(appearanceConfigProvider.future);
      } catch (_) {
        config = const domain.AppearanceConfig();
      }
      final target = pathFor(config.defaultTab);

      if (current == target) return null;

      return target;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell, state: state),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ai',
                builder: (context, state) => const AiPage(),
                routes: [
                  GoRoute(
                    path: 'quick-note',
                    builder: (context, state) => const AiQuickNotePage(),
                  ),
                  GoRoute(
                    path: 'breakdown',
                    builder: (context, state) => AiBreakdownPage(
                      initialInput: state.uri.queryParameters['input'],
                    ),
                  ),
                  GoRoute(
                    path: 'ask',
                    builder: (context, state) => const AiAskPage(),
                  ),
                  GoRoute(
                    path: 'today-plan',
                    builder: (context, state) => const AiTodayPlanPage(),
                  ),
                  GoRoute(
                    path: 'daily',
                    builder: (context, state) => const AiDailyReviewPage(),
                  ),
                  GoRoute(
                    path: 'weekly',
                    builder: (context, state) => const AiWeeklyReviewPage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notes',
                builder: (context, state) => const NotesPage(),
                routes: [
                  GoRoute(
                    path: ':noteId',
                    builder: (context, state) =>
                        NoteDetailPage(noteId: state.pathParameters['noteId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                builder: (context, state) => TodayEntryPoint(
                  rawHighlight: state.uri.queryParameters['highlight'],
                ),
                routes: [
                  GoRoute(
                    path: 'plan',
                    builder: (context, state) => TodayPlanPage(
                      rawDayKey: state.uri.queryParameters['day'],
                    ),
                  ),
                  GoRoute(
                    path: 'timeboxing',
                    builder: (context, state) =>
                        const TodayTimeboxingCanvasPage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tasks',
                builder: (context, state) => const TasksPage(),
                routes: [
                  GoRoute(
                    path: ':taskId',
                    builder: (context, state) =>
                        TaskDetailPage(taskId: state.pathParameters['taskId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/focus',
                builder: (context, state) =>
                    FocusPage(taskId: state.uri.queryParameters['taskId']),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/inbox',
        builder: (context, state) => const InboxPage(),
        routes: [
          GoRoute(
            path: 'process',
            builder: (context, state) => const InboxProcessPage(),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/create',
        builder: (context, state) {
          final rawType = state.uri.queryParameters['type']
              ?.trim()
              .toLowerCase();
          final initialType = switch (rawType) {
            'memo' => QuickCreateType.memo,
            'draft' => QuickCreateType.draft,
            _ => QuickCreateType.task,
          };
          final addToToday =
              state.uri.queryParameters['addToToday'] == '1' ||
              state.uri.queryParameters['addToToday'] == 'true';
          final initialText = state.uri.queryParameters['text'];
          return QuickCreateRoutePage(
            initialType: initialType,
            initialTaskAddToToday: addToToday,
            initialText: initialText,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/memos',
        builder: (context, state) => const MemosPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/search',
        builder: (context, state) => const SearchPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/stats',
        builder: (context, state) {
          final rawTab = state.uri.queryParameters['tab']?.trim().toLowerCase();
          final initialTab = switch (rawTab) {
            'kpi' || 'metrics' => StatsInitialTab.kpi,
            _ => StatsInitialTab.pomodoro,
          };
          return StatsPage(initialTab: initialTab);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/data',
        builder: (context, state) => const DataSettingsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/privacy',
        builder: (context, state) => const PrivacyPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/ai',
        builder: (context, state) => const AiSettingsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/pomodoro',
        builder: (context, state) => const PomodoroSettingsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/appearance',
        builder: (context, state) => const AppearanceSettingsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/flags',
        builder: (context, state) => const FeatureFlagsSettingsPage(),
      ),
    ],
  );
});
