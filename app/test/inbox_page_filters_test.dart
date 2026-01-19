import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/features/inbox/view/inbox_page.dart';
import 'package:daypick/features/notes/providers/note_providers.dart';
import 'package:daypick/features/tasks/providers/task_providers.dart';
import 'package:daypick/routing/app_router.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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

void main() {
  testWidgets('InboxPage supports type filters (task/memo/draft)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime(2026, 1, 10, 12);
    final tasks = [_task(id: 't-1', title: 'Task A', now: now)];
    final notes = [
      _note(id: 'm-1', title: 'Memo A', kind: domain.NoteKind.memo, now: now),
      _note(id: 'd-1', title: 'Draft A', kind: domain.NoteKind.draft, now: now),
    ];

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
          tasksStreamProvider.overrideWith((ref) => Stream.value(tasks)),
          unprocessedNotesStreamProvider.overrideWith(
            (ref) => Stream.value(notes),
          ),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    final allFilter = find.widgetWithText(ShadButton, '全部 (3)');
    final taskFilter = find.widgetWithText(ShadButton, '任务 (1)');
    final memoFilter = find.widgetWithText(ShadButton, '闪念 (1)');
    final draftFilter = find.widgetWithText(ShadButton, '草稿 (1)');

    expect(allFilter, findsOneWidget);
    expect(taskFilter, findsOneWidget);
    expect(memoFilter, findsOneWidget);
    expect(draftFilter, findsOneWidget);

    expect(find.text('Task A'), findsOneWidget);
    expect(find.text('Memo A'), findsOneWidget);
    expect(find.text('Draft A'), findsOneWidget);

    await tester.tap(taskFilter);
    await tester.pumpAndSettle();
    expect(find.text('Task A'), findsOneWidget);
    expect(find.text('Memo A'), findsNothing);
    expect(find.text('Draft A'), findsNothing);

    await tester.tap(memoFilter);
    await tester.pumpAndSettle();
    expect(find.text('Task A'), findsNothing);
    expect(find.text('Memo A'), findsOneWidget);
    expect(find.text('Draft A'), findsNothing);

    await tester.tap(draftFilter);
    await tester.pumpAndSettle();
    expect(find.text('Task A'), findsNothing);
    expect(find.text('Memo A'), findsNothing);
    expect(find.text('Draft A'), findsOneWidget);

    await tester.tap(allFilter);
    await tester.pumpAndSettle();
    expect(find.text('Task A'), findsOneWidget);
    expect(find.text('Memo A'), findsOneWidget);
    expect(find.text('Draft A'), findsOneWidget);
  });

  testWidgets('InboxPage reads inbox filter prefs from AppearanceConfig', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime(2026, 1, 10, 12);
    final tasks = [_task(id: 't-1', title: 'Task A', now: now)];
    final notes = [
      _note(id: 'm-1', title: 'Memo A', kind: domain.NoteKind.memo, now: now),
      _note(id: 'd-1', title: 'Draft A', kind: domain.NoteKind.draft, now: now),
    ];

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
            (ref) => Stream.value(
              const domain.AppearanceConfig(
                inboxTypeFilter: domain.InboxTypeFilter.tasks,
              ),
            ),
          ),
          tasksStreamProvider.overrideWith((ref) => Stream.value(tasks)),
          unprocessedNotesStreamProvider.overrideWith(
            (ref) => Stream.value(notes),
          ),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Task A'), findsOneWidget);
    expect(find.text('Memo A'), findsNothing);
    expect(find.text('Draft A'), findsNothing);
  });
}
