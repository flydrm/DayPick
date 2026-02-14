import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/local_events/local_events_guard.dart';
import 'package:daypick/core/local_events/local_events_provider.dart';
import 'package:daypick/core/local_events/local_events_service.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/features/focus/providers/focus_providers.dart';
import 'package:daypick/features/notes/providers/note_providers.dart';
import 'package:daypick/features/tasks/providers/task_providers.dart';
import 'package:daypick/features/today/view/today_page.dart';
import 'package:daypick/routing/app_router.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _CapturingNoteRepository implements domain.NoteRepository {
  domain.Note? lastUpserted;

  @override
  Stream<List<domain.Note>> watchAllNotes() =>
      Stream.value(const <domain.Note>[]);

  @override
  Stream<List<domain.Note>> watchNotesByTaskId(String taskId) =>
      Stream.value(const <domain.Note>[]);

  @override
  Stream<List<domain.Note>> watchMemos({bool includeArchived = false}) =>
      Stream.value(const <domain.Note>[]);

  @override
  Stream<List<domain.Note>> watchDrafts({bool includeArchived = false}) =>
      Stream.value(const <domain.Note>[]);

  @override
  Stream<List<domain.Note>> watchUnprocessedNotes() =>
      Stream.value(const <domain.Note>[]);

  @override
  Future<domain.Note?> getNoteById(String noteId) async => null;

  @override
  Future<void> upsertNote(domain.Note note) async {
    lastUpserted = note;
  }

  @override
  Future<void> deleteNote(String noteId) async {}
}

class _CapturingLocalEventsRepository implements domain.LocalEventsRepository {
  final List<domain.LocalEvent> inserted = <domain.LocalEvent>[];

  @override
  Future<void> insert(domain.LocalEvent event) async {
    inserted.add(event);
  }

  @override
  Future<List<domain.LocalEvent>> getAll({int? limit}) async =>
      List<domain.LocalEvent>.from(inserted);

  @override
  Future<List<domain.LocalEvent>> getBetween({
    required int minOccurredAtUtcMsInclusive,
    required int maxOccurredAtUtcMsExclusive,
    List<String>? eventNames,
    int? limit,
  }) async {
    return inserted
        .where(
          (event) =>
              event.occurredAtUtcMs >= minOccurredAtUtcMsInclusive &&
              event.occurredAtUtcMs < maxOccurredAtUtcMsExclusive,
        )
        .where(
          (event) => eventNames == null || eventNames.contains(event.eventName),
        )
        .toList(growable: false);
  }

  @override
  Future<void> prune({
    required int minOccurredAtUtcMs,
    required int maxEvents,
  }) async {
    inserted.removeWhere((event) => event.occurredAtUtcMs < minOccurredAtUtcMs);
    if (inserted.length > maxEvents) {
      inserted.removeRange(0, inserted.length - maxEvents);
    }
  }
}

class _FakeTodayPlanRepository implements domain.TodayPlanRepository {
  _FakeTodayPlanRepository({required this.today, required this.todayTaskIds});

  final DateTime today;
  final List<String> todayTaskIds;

  @override
  Stream<List<String>> watchTaskIdsForDay({
    required DateTime day,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) {
    final normalized = DateTime(day.year, day.month, day.day);
    if (section != domain.TodayPlanSection.today) {
      return Stream.value(const <String>[]);
    }
    return Stream.value(normalized == today ? todayTaskIds : const <String>[]);
  }

  @override
  Future<List<String>> getTaskIdsForDay({
    required DateTime day,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async {
    final normalized = DateTime(day.year, day.month, day.day);
    if (section != domain.TodayPlanSection.today) return const <String>[];
    return normalized == today ? todayTaskIds : const <String>[];
  }

  @override
  Future<void> addTask({
    required DateTime day,
    required String taskId,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async {}

  @override
  Future<void> removeTask({
    required DateTime day,
    required String taskId,
  }) async {}

  @override
  Future<void> replaceTasks({
    required DateTime day,
    required List<String> taskIds,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async {}

  @override
  Future<void> clearDay({
    required DateTime day,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async {}

  @override
  Future<void> clearAll({required DateTime day}) async {}

  @override
  Future<void> moveTaskToSection({
    required DateTime day,
    required String taskId,
    required domain.TodayPlanSection section,
    int? toIndex,
  }) async {}
}

void main() {
  testWidgets('Today Daily Log can save and navigate to note', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final tasks = <domain.Task>[
      domain.Task(
        id: 't-1',
        title: domain.TaskTitle('写 PRD'),
        status: domain.TaskStatus.todo,
        priority: domain.TaskPriority.medium,
        tags: const [],
        estimatedPomodoros: 2,
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
      domain.Task(
        id: 't-2',
        title: domain.TaskTitle('清理 Inbox'),
        status: domain.TaskStatus.done,
        priority: domain.TaskPriority.medium,
        tags: const [],
        estimatedPomodoros: 1,
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now.subtract(const Duration(minutes: 10)),
      ),
    ];

    final sessions = <domain.PomodoroSession>[
      domain.PomodoroSession(
        id: 's-1',
        taskId: 't-1',
        startAt: now.subtract(const Duration(minutes: 35)),
        endAt: now.subtract(const Duration(minutes: 10)),
        isDraft: false,
        progressNote: '完成大纲',
        createdAt: now.subtract(const Duration(minutes: 35)),
      ),
    ];

    final noteRepo = _CapturingNoteRepository();
    final createNote = domain.CreateNoteUseCase(
      repository: noteRepo,
      generateId: () => 'n-1',
      now: () => now,
    );

    final localEventsRepo = _CapturingLocalEventsRepository();
    final localEventsService = LocalEventsService(
      repository: localEventsRepo,
      guard: LocalEventsGuard(),
      generateId: () => 'evt-',
      nowUtcMs: () => now.toUtc().millisecondsSinceEpoch,
      appVersion: () => 'test+1',
      featureFlagsSnapshot: () => '{}',
    );

    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(path: '/today', builder: (context, state) => const TodayPage()),
        GoRoute(
          path: '/notes/:noteId',
          builder: (context, state) => Scaffold(
            body: Center(child: Text('note:${state.pathParameters['noteId']}')),
          ),
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
                todayModules: <domain.TodayWorkbenchModule>[],
              ),
            ),
          ),
          tasksStreamProvider.overrideWith((ref) => Stream.value(tasks)),
          notesStreamProvider.overrideWith(
            (ref) => Stream.value(const <domain.Note>[]),
          ),
          todayPlanRepositoryProvider.overrideWithValue(
            _FakeTodayPlanRepository(today: today, todayTaskIds: const ['t-1']),
          ),
          activePomodoroProvider.overrideWith((ref) => Stream.value(null)),
          pomodoroConfigProvider.overrideWith(
            (ref) => Stream.value(
              const domain.PomodoroConfig(workDurationMinutes: 25),
            ),
          ),
          todayPomodoroSessionsProvider.overrideWith(
            (ref) => Stream.value(sessions),
          ),
          yesterdayPomodoroSessionsProvider.overrideWith(
            (ref) => Stream.value(const <domain.PomodoroSession>[]),
          ),
          createNoteUseCaseProvider.overrideWithValue(createNote),
          localEventsServiceProvider.overrideWithValue(localEventsService),
        ],
        child: const DayPickApp(),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('today_daily_log_action')));
    await tester.pumpAndSettle();

    expect(find.text('今日记录'), findsWidgets);

    await tester.tap(find.text('保存为笔记'));
    await tester.pumpAndSettle();

    expect(find.text('note:n-1'), findsOneWidget);

    final created = noteRepo.lastUpserted;
    expect(created, isNotNull);
    expect(created!.id, 'n-1');
    expect(created.kind, domain.NoteKind.longform);
    expect(created.triageStatus, domain.TriageStatus.scheduledLater);
    expect(created.tags, contains('daily-log'));
    expect(created.title.value, contains('· 今日记录'));
    expect(created.body, contains('[[route:/tasks/t-1]]'));
    expect(created.body, contains('[[route:/tasks/t-2]]'));

    final dayKey = [
      today.year.toString().padLeft(4, '0'),
      today.month.toString().padLeft(2, '0'),
      today.day.toString().padLeft(2, '0'),
    ].join('-');
    final opened = localEventsRepo.inserted.firstWhere(
      (event) => event.eventName == domain.LocalEventNames.journalOpened,
    );
    expect(opened.metaJson, <String, Object?>{
      'day_key': dayKey,
      'source': 'today_daily_log_sheet',
    });

    final completed = localEventsRepo.inserted.firstWhere(
      (event) => event.eventName == domain.LocalEventNames.journalCompleted,
    );
    expect(completed.metaJson['day_key'], dayKey);
    expect(completed.metaJson['answered_prompts_count'], isA<int>());
    expect(completed.metaJson['refs_count'], greaterThanOrEqualTo(2));
    expect(completed.metaJson['has_text'], isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
