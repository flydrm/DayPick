// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:domain/domain.dart' as domain;

import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/routing/app_router.dart';
import 'package:daypick/features/focus/providers/focus_providers.dart';
import 'package:daypick/features/tasks/providers/task_providers.dart';
import 'package:daypick/features/today/providers/today_plan_providers.dart';
import 'package:daypick/features/notes/providers/note_providers.dart';
import 'package:daypick/features/notes/view/note_detail_page.dart';
import 'package:go_router/go_router.dart';

import 'test_utils.dart';

class _FakePomodoroSessionRepository
    implements domain.PomodoroSessionRepository {
  const _FakePomodoroSessionRepository();

  @override
  Stream<List<domain.PomodoroSession>> watchByTaskId(String taskId) =>
      Stream.value(const <domain.PomodoroSession>[]);

  @override
  Stream<List<domain.PomodoroSession>> watchBetween(
    DateTime startInclusive,
    DateTime endExclusive,
  ) => Stream.value(const <domain.PomodoroSession>[]);

  @override
  Stream<int> watchCountByTaskId(String taskId) => Stream.value(0);

  @override
  Stream<int> watchCountBetween(
    DateTime startInclusive,
    DateTime endExclusive,
  ) => Stream.value(0);

  @override
  Future<void> upsertSession(domain.PomodoroSession session) async {}

  @override
  Future<void> deleteSession(String sessionId) async {}
}

class _FakeNoteRepository implements domain.NoteRepository {
  _FakeNoteRepository(this._notes);

  final List<domain.Note> _notes;

  @override
  Stream<List<domain.Note>> watchAllNotes() => Stream.value(_notes);

  @override
  Stream<List<domain.Note>> watchNotesByTaskId(String taskId) =>
      Stream.value(_notes.where((n) => n.taskId == taskId).toList());

  @override
  Stream<List<domain.Note>> watchMemos({bool includeArchived = false}) {
    return Stream.value(
      _notes
          .where(
            (n) =>
                n.kind == domain.NoteKind.memo &&
                (includeArchived ||
                    n.triageStatus != domain.TriageStatus.archived),
          )
          .toList(growable: false),
    );
  }

  @override
  Stream<List<domain.Note>> watchDrafts({bool includeArchived = false}) {
    return Stream.value(
      _notes
          .where(
            (n) =>
                n.kind == domain.NoteKind.draft &&
                (includeArchived ||
                    n.triageStatus != domain.TriageStatus.archived),
          )
          .toList(growable: false),
    );
  }

  @override
  Stream<List<domain.Note>> watchUnprocessedNotes() {
    return Stream.value(
      _notes
          .where(
            (n) =>
                n.triageStatus == domain.TriageStatus.inbox &&
                (n.kind == domain.NoteKind.memo ||
                    n.kind == domain.NoteKind.draft),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<domain.Note?> getNoteById(String noteId) async {
    for (final note in _notes) {
      if (note.id == noteId) return note;
    }
    return null;
  }

  @override
  Future<void> upsertNote(domain.Note note) async {}

  @override
  Future<void> deleteNote(String noteId) async {}
}

class _FakeWeaveLinkRepository implements domain.WeaveLinkRepository {
  _FakeWeaveLinkRepository(this._links);

  final List<domain.WeaveLink> _links;

  @override
  Stream<List<domain.WeaveLink>> watchLinksByTargetNoteId(String targetNoteId) {
    return Stream.value(
      _links
          .where((l) => l.targetNoteId == targetNoteId)
          .toList(growable: false),
    );
  }

  @override
  Stream<List<domain.WeaveLink>> watchLinksBySource({
    required domain.WeaveSourceType sourceType,
    required String sourceId,
  }) => Stream.value(const <domain.WeaveLink>[]);

  @override
  Future<void> upsertLink(domain.WeaveLink link) async {}

  @override
  Future<void> deleteLink(String linkId) async {}
}

void main() {
  testWidgets('默认进入今天 + 底部 5 Tab 顺序正确', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
          todayPlanTaskIdsForDayProvider.overrideWith(
            (ref, day) => Stream.value(const <String>[]),
          ),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.AppearanceConfig()),
          ),
          activePomodoroProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quick_create_fab')), findsNothing);

    final bottomNav = find.byKey(const ValueKey('bottom_navigation'));
    final bottomNavLabels = tester.widgetList<Text>(
      find.descendant(of: bottomNav, matching: find.byType(Text)),
    );
    expect(
      bottomNavLabels.map((t) => t.data).whereType<String>().toList(),
      const ['AI', '笔记', '今天', '任务', '专注'],
    );
    final todayScrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('下一步'),
      300,
      scrollable: todayScrollable,
    );
    expect(find.text('下一步'), findsOneWidget);
    expect(find.text('今天计划'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('待编织'),
      300,
      scrollable: todayScrollable,
    );
    expect(find.text('待编织'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('昨天回顾'),
      300,
      scrollable: todayScrollable,
    );
    expect(find.text('昨天回顾'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('设置入口可进入设置页', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
          todayPlanTaskIdsForDayProvider.overrideWith(
            (ref, day) => Stream.value(const <String>[]),
          ),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.AppearanceConfig()),
          ),
          activePomodoroProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('开启统计后 Today 可进入统计页', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksStreamProvider.overrideWith(
            (ref) => Stream.value(const <domain.Task>[]),
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
          todayPlanTaskIdsForDayProvider.overrideWith(
            (ref, day) => Stream.value(const <String>[]),
          ),
          pomodoroSessionRepositoryProvider.overrideWithValue(
            const _FakePomodoroSessionRepository(),
          ),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(
              domain.AppearanceConfig(
                statsEnabled: true,
                todayModules: const [
                  domain.TodayWorkbenchModule.shortcuts,
                  domain.TodayWorkbenchModule.budget,
                  domain.TodayWorkbenchModule.focus,
                  domain.TodayWorkbenchModule.nextStep,
                  domain.TodayWorkbenchModule.todayPlan,
                  domain.TodayWorkbenchModule.yesterdayReview,
                  domain.TodayWorkbenchModule.stats,
                ],
              ),
            ),
          ),
          activePomodoroProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    final todayScrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('统计/热力图'),
      400,
      scrollable: todayScrollable,
    );
    expect(find.text('统计/热力图'), findsOneWidget);

    final viewStats = find.text('查看统计');
    await tester.ensureVisible(viewStats);
    await tester.pumpAndSettle();
    await tester.tap(viewStats);
    await tester.pumpAndSettle();
    expect(find.text('近 12 周热力图（番茄）'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('Today 工作台可显示待编织闪念模块', (WidgetTester tester) async {
    final now = DateTime(2026, 1, 1, 12);
    final memo = domain.Note(
      id: 'memo-1',
      title: domain.NoteTitle('一条闪念'),
      body: '先收下，晚点编织',
      tags: const ['idea'],
      kind: domain.NoteKind.memo,
      triageStatus: domain.TriageStatus.inbox,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksStreamProvider.overrideWith(
            (ref) => Stream.value(const <domain.Task>[]),
          ),
          unprocessedNotesStreamProvider.overrideWith(
            (ref) => Stream.value([memo]),
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
          todayPlanTaskIdsForDayProvider.overrideWith(
            (ref, day) => Stream.value(const <String>[]),
          ),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(
              domain.AppearanceConfig(
                todayModules: const [domain.TodayWorkbenchModule.weave],
              ),
            ),
          ),
          activePomodoroProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    final todayScrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('待编织'),
      300,
      scrollable: todayScrollable,
    );

    expect(find.text('待编织'), findsOneWidget);
    expect(find.text('一条闪念'), findsOneWidget);
    expect(find.text('去待处理'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('搜索页可匹配任务与笔记', (WidgetTester tester) async {
    final now = DateTime(2026, 1, 1, 12);
    final task = domain.Task(
      id: 't-1',
      title: domain.TaskTitle('Buy milk'),
      description: 'Remember to buy milk',
      status: domain.TaskStatus.todo,
      priority: domain.TaskPriority.medium,
      tags: const ['errand'],
      estimatedPomodoros: null,
      createdAt: now,
      updatedAt: now,
    );
    final note = domain.Note(
      id: 'n-1',
      title: domain.NoteTitle('Milk note'),
      body: 'milk is important',
      tags: const ['food'],
      kind: domain.NoteKind.longform,
      triageStatus: domain.TriageStatus.scheduledLater,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksStreamProvider.overrideWith((ref) => Stream.value([task])),
          notesStreamProvider.overrideWith((ref) => Stream.value([note])),
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
          todayPlanTaskIdsForDayProvider.overrideWith(
            (ref, day) => Stream.value(const <String>[]),
          ),
          pomodoroSessionRepositoryProvider.overrideWithValue(
            const _FakePomodoroSessionRepository(),
          ),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.AppearanceConfig()),
          ),
          activePomodoroProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    expect(find.text('范围'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, 'milk');
    await tester.pumpAndSettle();

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Milk note'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('长文正文可用收集箱锚点渲染', (WidgetTester tester) async {
    final now = DateTime(2026, 1, 1, 12);
    final longform = domain.Note(
      id: 'long-1',
      title: domain.NoteTitle('长文'),
      body: 'Intro\n\n[[收集箱]]\n\nAfter',
      tags: const [],
      kind: domain.NoteKind.longform,
      triageStatus: domain.TriageStatus.scheduledLater,
      createdAt: now,
      updatedAt: now,
    );
    final memo = domain.Note(
      id: 'memo-1',
      title: domain.NoteTitle('一条闪念'),
      body: 'from memo',
      tags: const [],
      kind: domain.NoteKind.memo,
      triageStatus: domain.TriageStatus.inbox,
      createdAt: now,
      updatedAt: now,
    );
    final weave = domain.WeaveLink(
      id: 'w-1',
      sourceType: domain.WeaveSourceType.note,
      sourceId: memo.id,
      targetNoteId: longform.id,
      mode: domain.WeaveMode.reference,
      createdAt: now,
      updatedAt: now,
    );

    final router = GoRouter(
      initialLocation: '/notes/${longform.id}',
      routes: [
        GoRoute(
          path: '/notes/:noteId',
          builder: (context, state) =>
              NoteDetailPage(noteId: state.pathParameters['noteId']!),
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
          noteRepositoryProvider.overrideWithValue(
            _FakeNoteRepository([longform, memo]),
          ),
          weaveLinkRepositoryProvider.overrideWithValue(
            _FakeWeaveLinkRepository([weave]),
          ),
          tasksStreamProvider.overrideWith(
            (ref) => Stream.value(const <domain.Task>[]),
          ),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Intro'), findsOneWidget);
    expect(find.text('After'), findsOneWidget);
    expect(find.text('收集箱'), findsOneWidget);
    expect(find.text('[[收集箱]]'), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('长文列表项支持 [[route:...]] 跳转且不展示 token', (
    WidgetTester tester,
  ) async {
    final now = DateTime(2026, 1, 1, 12);

    final longform = domain.Note(
      id: 'long-1',
      title: domain.NoteTitle('AI 问答存档'),
      body: ['引用：', '- [1] 任务 · Buy milk [[route:/tasks/t-1]]'].join('\n'),
      tags: const [],
      kind: domain.NoteKind.longform,
      triageStatus: domain.TriageStatus.scheduledLater,
      createdAt: now,
      updatedAt: now,
    );

    final router = GoRouter(
      initialLocation: '/notes/${longform.id}',
      routes: [
        GoRoute(
          path: '/notes/:noteId',
          builder: (context, state) =>
              NoteDetailPage(noteId: state.pathParameters['noteId']!),
        ),
        GoRoute(
          path: '/tasks/:taskId',
          builder: (context, state) =>
              Scaffold(body: Text('Task ${state.pathParameters['taskId']}')),
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
          noteRepositoryProvider.overrideWithValue(
            _FakeNoteRepository([longform]),
          ),
          weaveLinkRepositoryProvider.overrideWithValue(
            _FakeWeaveLinkRepository(const []),
          ),
          tasksStreamProvider.overrideWith(
            (ref) => Stream.value(const <domain.Task>[]),
          ),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('[[route:'), findsNothing);
    final milkRow = find.textContaining('Buy milk');
    expect(milkRow, findsOneWidget);

    await tester.tap(milkRow);
    await tester.pumpAndSettle();
    expect(find.text('Task t-1'), findsOneWidget);
    await disposeApp(tester);
  });
}
