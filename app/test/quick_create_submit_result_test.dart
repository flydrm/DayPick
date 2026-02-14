import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/capture/capture_submit_result.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/routing/app_router.dart';
import 'package:daypick/ui/sheets/quick_create_sheet.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'fakes/fake_today_plan_repository.dart';

class _CapturingTaskRepository implements domain.TaskRepository {
  domain.Task? lastUpserted;

  @override
  Stream<List<domain.Task>> watchAllTasks() =>
      Stream.value(const <domain.Task>[]);

  @override
  Future<domain.Task?> getTaskById(String taskId) async => null;

  @override
  Future<void> upsertTask(domain.Task task) async {
    lastUpserted = task;
  }

  @override
  Future<void> deleteTask(String taskId) async {}
}

class _FlakyNoteRepository implements domain.NoteRepository {
  _FlakyNoteRepository({required this.failuresBeforeSuccess});

  final int failuresBeforeSuccess;
  int _attempts = 0;
  domain.Note? lastUpserted;

  @override
  Stream<List<domain.Note>> watchAllNotes() => Stream.value(const []);

  @override
  Stream<List<domain.Note>> watchNotesByTaskId(String taskId) =>
      Stream.value(const []);

  @override
  Stream<List<domain.Note>> watchMemos({bool includeArchived = false}) =>
      Stream.value(const []);

  @override
  Stream<List<domain.Note>> watchDrafts({bool includeArchived = false}) =>
      Stream.value(const []);

  @override
  Stream<List<domain.Note>> watchUnprocessedNotes() => Stream.value(const []);

  @override
  Future<domain.Note?> getNoteById(String noteId) async => null;

  @override
  Future<void> upsertNote(domain.Note note) async {
    _attempts++;
    if (_attempts <= failuresBeforeSuccess) {
      throw Exception('db write failed');
    }
    lastUpserted = note;
  }

  @override
  Future<void> deleteNote(String noteId) async {}
}

class _FlakyTodayPlanRepository extends FakeTodayPlanRepository {
  _FlakyTodayPlanRepository({required this.failuresBeforeSuccess});

  final int failuresBeforeSuccess;
  int addAttempts = 0;

  @override
  Future<void> addTask({
    required DateTime day,
    required String taskId,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async {
    addAttempts++;
    if (addAttempts <= failuresBeforeSuccess) {
      throw Exception('today plan add failed');
    }
    return super.addTask(day: day, taskId: taskId, section: section);
  }
}

class _ResultHostPage extends StatefulWidget {
  const _ResultHostPage({
    required this.initialType,
    this.initialTaskAddToToday = false,
  });

  final QuickCreateType initialType;
  final bool initialTaskAddToToday;

  @override
  State<_ResultHostPage> createState() => _ResultHostPageState();
}

class _ResultHostPageState extends State<_ResultHostPage> {
  CaptureSubmitResult? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShadButton(
              onPressed: () async {
                final result = await showModalBottomSheet<CaptureSubmitResult>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (context) => QuickCreateSheet(
                    initialType: widget.initialType,
                    initialTaskAddToToday: widget.initialTaskAddToToday,
                  ),
                );
                if (!mounted) return;
                setState(() => _result = result);
              },
              child: const Text('Open Quick Create'),
            ),
            const SizedBox(height: 12),
            Text(_result?.entryId ?? '', key: const ValueKey('last_entry_id')),
            Text(
              _result?.entryKind.name ?? '',
              key: const ValueKey('last_entry_kind'),
            ),
            Text(
              _result?.triageStatus.name ?? '',
              key: const ValueKey('last_triage_status'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('QuickCreate submits task and returns entry id + kind', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = _CapturingTaskRepository();
    final createTask = domain.CreateTaskUseCase(
      repository: repo,
      generateId: () => 't-1',
    );
    final router = GoRouter(
      initialLocation: '/host',
      routes: [
        GoRoute(
          path: '/host',
          builder: (context, state) =>
              const _ResultHostPage(initialType: QuickCreateType.task),
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
          createTaskUseCaseProvider.overrideWithValue(createTask),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Quick Create'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('quick_create_task_title')),
      'Test task',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('quick_create_task_submit')));
    await tester.pumpAndSettle();

    expect(repo.lastUpserted, isNotNull);
    expect(find.byKey(const ValueKey('last_entry_id')), findsOneWidget);
    expect(
      (tester.widget(find.byKey(const ValueKey('last_entry_id'))) as Text).data,
      't-1',
    );
    expect(
      (tester.widget(find.byKey(const ValueKey('last_entry_kind'))) as Text)
          .data,
      'task',
    );
    expect(
      (tester.widget(find.byKey(const ValueKey('last_triage_status'))) as Text)
          .data,
      'inbox',
    );
  });

  testWidgets('Task add-to-today failure shows retry and succeeds after retry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final taskRepo = _CapturingTaskRepository();
    final createTask = domain.CreateTaskUseCase(
      repository: taskRepo,
      generateId: () => 't-1',
    );
    final todayRepo = _FlakyTodayPlanRepository(failuresBeforeSuccess: 1);
    addTearDown(todayRepo.dispose);

    final router = GoRouter(
      initialLocation: '/host',
      routes: [
        GoRoute(
          path: '/host',
          builder: (context, state) => const _ResultHostPage(
            initialType: QuickCreateType.task,
            initialTaskAddToToday: true,
          ),
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
          createTaskUseCaseProvider.overrideWithValue(createTask),
          todayPlanRepositoryProvider.overrideWithValue(todayRepo),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Quick Create'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('quick_create_task_title')),
      'Test task',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('quick_create_task_submit')));
    await tester.pumpAndSettle();

    expect(todayRepo.addAttempts, 1);
    expect(taskRepo.lastUpserted, isNotNull);
    expect(taskRepo.lastUpserted!.triageStatus, domain.TriageStatus.inbox);
    expect(find.byKey(const ValueKey('quick_create_error')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick_create_retry')), findsOneWidget);

    final taskTitleInput = tester.widget<ShadInput>(
      find.byKey(const ValueKey('quick_create_task_title')),
    );
    expect(taskTitleInput.controller!.text, 'Test task');

    await tester.tap(find.byKey(const ValueKey('quick_create_retry')));
    await tester.pumpAndSettle();

    expect(todayRepo.addAttempts, 2);
    expect(
      (tester.widget(find.byKey(const ValueKey('last_entry_id'))) as Text).data,
      't-1',
    );
    expect(
      (tester.widget(find.byKey(const ValueKey('last_entry_kind'))) as Text)
          .data,
      'task',
    );
    expect(
      (tester.widget(find.byKey(const ValueKey('last_triage_status'))) as Text)
          .data,
      domain.TriageStatus.plannedToday.name,
    );
  });

  testWidgets('QuickCreate preserves input on failure and retry succeeds', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = _FlakyNoteRepository(failuresBeforeSuccess: 1);
    final createNote = domain.CreateNoteUseCase(
      repository: repo,
      generateId: () => 'n-1',
    );
    final router = GoRouter(
      initialLocation: '/host',
      routes: [
        GoRoute(
          path: '/host',
          builder: (context, state) =>
              const _ResultHostPage(initialType: QuickCreateType.memo),
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
          createNoteUseCaseProvider.overrideWithValue(createNote),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Quick Create'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('quick_create_memo_body')),
      'Hello memo',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ShadButton, '创建闪念'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quick_create_error')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick_create_retry')), findsOneWidget);

    final memoInput = tester.widget<ShadInput>(
      find.byKey(const ValueKey('quick_create_memo_body')),
    );
    expect(memoInput.controller!.text, 'Hello memo');

    await tester.tap(find.byKey(const ValueKey('quick_create_retry')));
    await tester.pumpAndSettle();

    expect(repo.lastUpserted, isNotNull);
    expect(
      (tester.widget(find.byKey(const ValueKey('last_entry_id'))) as Text).data,
      'n-1',
    );
    expect(
      (tester.widget(find.byKey(const ValueKey('last_entry_kind'))) as Text)
          .data,
      'memo',
    );
  });
}
