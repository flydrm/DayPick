import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/features/notes/providers/note_providers.dart';
import 'package:daypick/features/today/providers/today_plan_providers.dart';
import 'package:daypick/routing/app_router.dart';
import 'package:daypick/features/tasks/view/task_detail_page.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class _FakeTaskRepository implements domain.TaskRepository {
  _FakeTaskRepository(this._tasks);

  List<domain.Task> _tasks;

  @override
  Stream<List<domain.Task>> watchAllTasks() => Stream.value(_tasks);

  @override
  Future<domain.Task?> getTaskById(String taskId) async {
    for (final task in _tasks) {
      if (task.id == taskId) return task;
    }
    return null;
  }

  @override
  Future<void> upsertTask(domain.Task task) async {
    _tasks = [
      for (final t in _tasks)
        if (t.id == task.id) task else t,
      if (_tasks.every((t) => t.id != task.id)) task,
    ];
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _tasks = _tasks.where((t) => t.id != taskId).toList(growable: false);
  }
}

class _FakeTaskChecklistRepository implements domain.TaskChecklistRepository {
  _FakeTaskChecklistRepository(this._items);

  List<domain.TaskChecklistItem> _items;

  @override
  Stream<List<domain.TaskChecklistItem>> watchByTaskId(String taskId) {
    return Stream.value(
      _items.where((i) => i.taskId == taskId).toList(growable: false),
    );
  }

  @override
  Future<void> upsertItem(domain.TaskChecklistItem item) async {
    _items = [
      for (final i in _items)
        if (i.id == item.id) item else i,
      if (_items.every((i) => i.id != item.id)) item,
    ];
  }

  @override
  Future<void> deleteItem(String itemId) async {
    _items = _items.where((i) => i.id != itemId).toList(growable: false);
  }
}

class _FakePomodoroSessionRepository
    implements domain.PomodoroSessionRepository {
  const _FakePomodoroSessionRepository(this._sessions);

  final List<domain.PomodoroSession> _sessions;

  @override
  Stream<List<domain.PomodoroSession>> watchByTaskId(String taskId) =>
      Stream.value(
        _sessions.where((s) => s.taskId == taskId).toList(growable: false),
      );

  @override
  Stream<List<domain.PomodoroSession>> watchBetween(
    DateTime startInclusive,
    DateTime endExclusive,
  ) => Stream.value(const <domain.PomodoroSession>[]);

  @override
  Stream<int> watchCountByTaskId(String taskId) =>
      Stream.value(_sessions.where((s) => s.taskId == taskId).length);

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
  Stream<List<domain.Note>> watchNotesByTaskId(String taskId) => Stream.value(
    _notes.where((n) => n.taskId == taskId).toList(growable: false),
  );

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
  Stream<List<domain.WeaveLink>> watchLinksByTargetNoteId(
    String targetNoteId,
  ) => Stream.value(
    _links.where((l) => l.targetNoteId == targetNoteId).toList(growable: false),
  );

  @override
  Stream<List<domain.WeaveLink>> watchLinksBySource({
    required domain.WeaveSourceType sourceType,
    required String sourceId,
  }) => Stream.value(
    _links
        .where((l) => l.sourceType == sourceType && l.sourceId == sourceId)
        .toList(growable: false),
  );

  @override
  Future<void> upsertLink(domain.WeaveLink link) async {}

  @override
  Future<void> deleteLink(String linkId) async {}
}

void main() {
  testWidgets('任务详情页使用 Shadcn 风格组件', (WidgetTester tester) async {
    final now = DateTime(2026, 1, 1, 12);
    final task = domain.Task(
      id: 't-1',
      title: domain.TaskTitle('打磨任务详情页'),
      description: '把 UI/UE/UX 做到能用且耐看',
      status: domain.TaskStatus.todo,
      priority: domain.TaskPriority.high,
      dueAt: DateTime(2026, 1, 2),
      tags: const ['ui', 'beta'],
      estimatedPomodoros: 2,
      triageStatus: domain.TriageStatus.plannedToday,
      createdAt: now,
      updatedAt: now,
    );

    final checklist = [
      domain.TaskChecklistItem(
        id: 'c-1',
        taskId: task.id,
        title: domain.ChecklistItemTitle('统一按钮/卡片风格'),
        isDone: false,
        orderIndex: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final note = domain.Note(
      id: 'n-1',
      title: domain.NoteTitle('细节记录'),
      body: '先把 TaskDetail 改成 Shadcn。',
      tags: const [],
      taskId: task.id,
      kind: domain.NoteKind.draft,
      triageStatus: domain.TriageStatus.inbox,
      createdAt: now,
      updatedAt: now,
    );

    final targetLongform = domain.Note(
      id: 'lf-1',
      title: domain.NoteTitle('长文：Beta 打磨'),
      body: '[[收集箱]]',
      tags: const [],
      kind: domain.NoteKind.longform,
      triageStatus: domain.TriageStatus.scheduledLater,
      createdAt: now,
      updatedAt: now,
    );

    final weave = domain.WeaveLink(
      id: 'w-1',
      sourceType: domain.WeaveSourceType.task,
      sourceId: task.id,
      targetNoteId: targetLongform.id,
      mode: domain.WeaveMode.reference,
      createdAt: now,
      updatedAt: now,
    );

    final session = domain.PomodoroSession(
      id: 'p-1',
      taskId: task.id,
      startAt: now.subtract(const Duration(minutes: 25)),
      endAt: now,
      isDraft: false,
      progressNote: '完成第一版 UI',
      createdAt: now,
    );

    final router = GoRouter(
      initialLocation: '/tasks/${task.id}',
      routes: [
        GoRoute(
          path: '/tasks/:taskId',
          builder: (context, state) =>
              TaskDetailPage(taskId: state.pathParameters['taskId']!),
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
          todayPlanTaskIdsProvider.overrideWith(
            (ref) => Stream.value(const <String>[]),
          ),
          taskRepositoryProvider.overrideWithValue(_FakeTaskRepository([task])),
          taskChecklistRepositoryProvider.overrideWithValue(
            _FakeTaskChecklistRepository(checklist),
          ),
          pomodoroSessionRepositoryProvider.overrideWithValue(
            _FakePomodoroSessionRepository([session]),
          ),
          noteRepositoryProvider.overrideWithValue(
            _FakeNoteRepository([note, targetLongform]),
          ),
          weaveLinkRepositoryProvider.overrideWithValue(
            _FakeWeaveLinkRepository([weave]),
          ),
          weaveLinksBySourceProvider.overrideWith((ref, args) {
            if (args.sourceType == domain.WeaveSourceType.task &&
                args.sourceId == task.id) {
              return Stream.value([weave]);
            }
            return Stream.value(const <domain.WeaveLink>[]);
          }),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DayPickApp)),
    );
    final links = await container.read(
      weaveLinksBySourceProvider((
        sourceType: domain.WeaveSourceType.task,
        sourceId: task.id,
      )).future,
    );
    expect(links, isNotEmpty);
    await tester.pump();

    expect(find.text('概览'), findsOneWidget);
    expect(find.text('Checklist'), findsOneWidget);
    expect(find.byType(ShadCheckbox), findsAtLeastNWidgets(1));
    expect(find.text('关联笔记'), findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('已编织到'),
      240,
      scrollable: scrollable,
    );
    expect(find.text('已编织到'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('开始专注'),
      240,
      scrollable: scrollable,
    );
    expect(find.text('加入今天计划'), findsOneWidget);
    expect(find.text('开始专注'), findsOneWidget);
  });
}
