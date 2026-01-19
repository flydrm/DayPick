import 'dart:async';

import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/features/inbox/view/inbox_page.dart';
import 'package:daypick/routing/app_router.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class _InMemoryTaskRepository implements domain.TaskRepository {
  final Map<String, domain.Task> _tasks = <String, domain.Task>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  List<domain.Task> _snapshot() {
    final list = _tasks.values.toList(growable: false);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Stream<List<domain.Task>> watchAllTasks() async* {
    yield _snapshot();
    await for (final _ in _changes.stream) {
      yield _snapshot();
    }
  }

  @override
  Future<domain.Task?> getTaskById(String taskId) async => _tasks[taskId];

  @override
  Future<void> upsertTask(domain.Task task) async {
    _tasks[task.id] = task;
    _changes.add(null);
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _tasks.remove(taskId);
    _changes.add(null);
  }

  Future<void> dispose() async {
    await _changes.close();
  }
}

class _InMemoryNoteRepository implements domain.NoteRepository {
  final Map<String, domain.Note> _notes = <String, domain.Note>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  List<domain.Note> _snapshot() {
    final list = _notes.values.toList(growable: false);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Stream<List<domain.Note>> watchAllNotes() async* {
    yield _snapshot();
    await for (final _ in _changes.stream) {
      yield _snapshot();
    }
  }

  @override
  Stream<List<domain.Note>> watchNotesByTaskId(String taskId) async* {
    List<domain.Note> forTask() =>
        _snapshot().where((n) => n.taskId == taskId).toList(growable: false);

    yield forTask();
    await for (final _ in _changes.stream) {
      yield forTask();
    }
  }

  @override
  Stream<List<domain.Note>> watchMemos({bool includeArchived = false}) async* {
    List<domain.Note> memos() => _snapshot()
        .where(
          (n) =>
              n.kind == domain.NoteKind.memo &&
              (includeArchived ||
                  n.triageStatus != domain.TriageStatus.archived),
        )
        .toList(growable: false);

    yield memos();
    await for (final _ in _changes.stream) {
      yield memos();
    }
  }

  @override
  Stream<List<domain.Note>> watchDrafts({bool includeArchived = false}) async* {
    List<domain.Note> drafts() => _snapshot()
        .where(
          (n) =>
              n.kind == domain.NoteKind.draft &&
              (includeArchived ||
                  n.triageStatus != domain.TriageStatus.archived),
        )
        .toList(growable: false);

    yield drafts();
    await for (final _ in _changes.stream) {
      yield drafts();
    }
  }

  @override
  Stream<List<domain.Note>> watchUnprocessedNotes() async* {
    List<domain.Note> unprocessed() => _snapshot()
        .where(
          (n) =>
              n.triageStatus == domain.TriageStatus.inbox &&
              (n.kind == domain.NoteKind.memo ||
                  n.kind == domain.NoteKind.draft),
        )
        .toList(growable: false);

    yield unprocessed();
    await for (final _ in _changes.stream) {
      yield unprocessed();
    }
  }

  @override
  Future<domain.Note?> getNoteById(String noteId) async => _notes[noteId];

  @override
  Future<void> upsertNote(domain.Note note) async {
    _notes[note.id] = note;
    _changes.add(null);
  }

  @override
  Future<void> deleteNote(String noteId) async {
    _notes.remove(noteId);
    _changes.add(null);
  }

  Future<void> dispose() async {
    await _changes.close();
  }
}

class _InMemoryTodayPlanRepository implements domain.TodayPlanRepository {
  final Map<String, Map<domain.TodayPlanSection, List<String>>> _store =
      <String, Map<domain.TodayPlanSection, List<String>>>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  String _dayKey(DateTime day) {
    final local = DateTime(day.year, day.month, day.day);
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Stream<List<String>> watchTaskIdsForDay({
    required DateTime day,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async* {
    yield await getTaskIdsForDay(day: day, section: section);
    await for (final _ in _changes.stream) {
      yield await getTaskIdsForDay(day: day, section: section);
    }
  }

  @override
  Future<List<String>> getTaskIdsForDay({
    required DateTime day,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async {
    final key = _dayKey(day);
    final entry = _store[key];
    if (entry == null) return const <String>[];
    return List<String>.from(entry[section] ?? const <String>[]);
  }

  void _ensureDay(String key) {
    _store.putIfAbsent(key, () {
      return {
        domain.TodayPlanSection.today: <String>[],
        domain.TodayPlanSection.evening: <String>[],
      };
    });
  }

  void _removeFromAllSections(String key, String taskId) {
    final entry = _store[key];
    if (entry == null) return;
    for (final list in entry.values) {
      list.remove(taskId);
    }
  }

  @override
  Future<void> addTask({
    required DateTime day,
    required String taskId,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async {
    final key = _dayKey(day);
    _ensureDay(key);
    _removeFromAllSections(key, taskId);
    final list = _store[key]![section]!;
    if (!list.contains(taskId)) list.add(taskId);
    _changes.add(null);
  }

  @override
  Future<void> removeTask({
    required DateTime day,
    required String taskId,
  }) async {
    final key = _dayKey(day);
    final entry = _store[key];
    if (entry == null) return;
    _removeFromAllSections(key, taskId);
    final today = entry[domain.TodayPlanSection.today];
    final evening = entry[domain.TodayPlanSection.evening];
    if ((today == null || today.isEmpty) &&
        (evening == null || evening.isEmpty)) {
      _store.remove(key);
    }
    _changes.add(null);
  }

  @override
  Future<void> replaceTasks({
    required DateTime day,
    required List<String> taskIds,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async {
    final key = _dayKey(day);
    _ensureDay(key);
    final unique = <String>[];
    for (final id in taskIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty) continue;
      if (!unique.contains(trimmed)) unique.add(trimmed);
    }
    for (final id in unique) {
      _removeFromAllSections(key, id);
    }
    _store[key]![section] = unique;
    _changes.add(null);
  }

  @override
  Future<void> clearDay({
    required DateTime day,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async {
    final key = _dayKey(day);
    final entry = _store[key];
    if (entry == null) return;
    entry[section]?.clear();
    final today = entry[domain.TodayPlanSection.today];
    final evening = entry[domain.TodayPlanSection.evening];
    if ((today == null || today.isEmpty) &&
        (evening == null || evening.isEmpty)) {
      _store.remove(key);
    }
    _changes.add(null);
  }

  @override
  Future<void> clearAll({required DateTime day}) async {
    _store.remove(_dayKey(day));
    _changes.add(null);
  }

  @override
  Future<void> moveTaskToSection({
    required DateTime day,
    required String taskId,
    required domain.TodayPlanSection section,
    int? toIndex,
  }) async {
    final key = _dayKey(day);
    _ensureDay(key);
    _removeFromAllSections(key, taskId);
    final list = _store[key]![section]!;
    final safeIndex = toIndex == null
        ? list.length
        : toIndex.clamp(0, list.length);
    list.insert(safeIndex, taskId);
    _changes.add(null);
  }

  Future<void> dispose() async {
    await _changes.close();
  }
}

domain.Note _note({
  required String id,
  required String title,
  required domain.NoteKind kind,
  required DateTime now,
  domain.TriageStatus triageStatus = domain.TriageStatus.inbox,
}) {
  return domain.Note(
    id: id,
    title: domain.NoteTitle(title),
    body: 'body',
    tags: const [],
    kind: kind,
    triageStatus: triageStatus,
    createdAt: now,
    updatedAt: now,
  );
}

domain.Task _task({
  required String id,
  required String title,
  required DateTime now,
  domain.TriageStatus triageStatus = domain.TriageStatus.inbox,
}) {
  return domain.Task(
    id: id,
    title: domain.TaskTitle(title),
    description: null,
    status: domain.TaskStatus.todo,
    priority: domain.TaskPriority.medium,
    dueAt: null,
    tags: const [],
    estimatedPomodoros: 1,
    triageStatus: triageStatus,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('Inbox bulk action can add memos/drafts to Today', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final seedNow = DateTime(2026, 1, 10, 12);
    final realNow = DateTime.now();
    final today = DateTime(realNow.year, realNow.month, realNow.day);

    final taskRepo = _InMemoryTaskRepository();
    final noteRepo = _InMemoryNoteRepository();
    final planRepo = _InMemoryTodayPlanRepository();
    addTearDown(() async {
      await planRepo.dispose();
      await noteRepo.dispose();
      await taskRepo.dispose();
    });

    await noteRepo.upsertNote(
      _note(
        id: 'n-1',
        title: 'Memo A',
        kind: domain.NoteKind.memo,
        now: seedNow,
      ),
    );

    var taskIdCounter = 0;
    String nextTaskId() => 't-${++taskIdCounter}';

    final router = GoRouter(
      initialLocation: '/inbox',
      routes: [
        GoRoute(path: '/inbox', builder: (context, state) => const InboxPage()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.AppearanceConfig()),
          ),
          taskIdGeneratorProvider.overrideWithValue(nextTaskId),
          taskRepositoryProvider.overrideWithValue(taskRepo),
          noteRepositoryProvider.overrideWithValue(noteRepo),
          todayPlanRepositoryProvider.overrideWithValue(planRepo),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Memo A'), findsOneWidget);

    await tester.longPress(find.text('Memo A'));
    await tester.pumpAndSettle();

    expect(find.textContaining('闪念/草稿 1'), findsOneWidget);

    final addToTodayButton = find.widgetWithText(ShadButton, '今天');
    expect(addToTodayButton, findsOneWidget);

    await tester.tap(addToTodayButton);
    await tester.pumpAndSettle();

    final updatedNote = await noteRepo.getNoteById('n-1');
    expect(updatedNote, isNotNull);
    expect(updatedNote!.triageStatus, domain.TriageStatus.scheduledLater);
    expect(updatedNote.taskId, isNotNull);
    expect(updatedNote.taskId, isNotEmpty);

    final createdTaskId = updatedNote.taskId!;
    final createdTask = await taskRepo.getTaskById(createdTaskId);
    expect(createdTask, isNotNull);
    expect(createdTask!.title.value, 'Memo A');
    expect(createdTask.triageStatus, domain.TriageStatus.plannedToday);

    final planIds = await planRepo.getTaskIdsForDay(day: today);
    expect(planIds, contains(createdTaskId));

    expect(find.text('Memo A'), findsNothing);
    expect(find.text('收件箱为空'), findsOneWidget);
  });

  testWidgets('Inbox bulk add-to-today moves inbox tasks out of Inbox', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final seedNow = DateTime(2026, 1, 10, 12);
    final realNow = DateTime.now();
    final today = DateTime(realNow.year, realNow.month, realNow.day);

    final taskRepo = _InMemoryTaskRepository();
    final noteRepo = _InMemoryNoteRepository();
    final planRepo = _InMemoryTodayPlanRepository();
    addTearDown(() async {
      await planRepo.dispose();
      await noteRepo.dispose();
      await taskRepo.dispose();
    });

    await taskRepo.upsertTask(_task(id: 't-1', title: 'Task A', now: seedNow));

    final router = GoRouter(
      initialLocation: '/inbox',
      routes: [
        GoRoute(path: '/inbox', builder: (context, state) => const InboxPage()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.AppearanceConfig()),
          ),
          taskRepositoryProvider.overrideWithValue(taskRepo),
          noteRepositoryProvider.overrideWithValue(noteRepo),
          todayPlanRepositoryProvider.overrideWithValue(planRepo),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Task A'), findsOneWidget);

    await tester.longPress(find.text('Task A'));
    await tester.pumpAndSettle();

    final addToTodayButton = find.widgetWithText(ShadButton, '今天');
    await tester.tap(addToTodayButton);
    await tester.pumpAndSettle();

    final updatedTask = await taskRepo.getTaskById('t-1');
    expect(updatedTask, isNotNull);
    expect(updatedTask!.triageStatus, domain.TriageStatus.plannedToday);

    final planIds = await planRepo.getTaskIdsForDay(day: today);
    expect(planIds, contains('t-1'));

    expect(find.text('Task A'), findsNothing);
    expect(find.text('收件箱为空'), findsOneWidget);
  });
}
