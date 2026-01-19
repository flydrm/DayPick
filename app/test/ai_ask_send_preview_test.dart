import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/features/ai/providers/ai_providers.dart';
import 'package:daypick/features/ai/view/ai_ask_page.dart';
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
}) {
  return domain.Task(
    id: id,
    title: domain.TaskTitle(title),
    description: 'desc',
    status: domain.TaskStatus.todo,
    priority: domain.TaskPriority.medium,
    dueAt: now,
    tags: const ['tag-a'],
    estimatedPomodoros: 1,
    triageStatus: domain.TriageStatus.scheduledLater,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('AI Ask supports send preview sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final tasks = [_task(id: 't-1', title: 'Task A', now: now)];

    final router = GoRouter(
      initialLocation: '/ai/ask',
      routes: [
        GoRoute(
          path: '/ai/ask',
          builder: (context, state) => const AiAskPage(),
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
          aiConfigProvider.overrideWith((ref) async => null),
          tasksStreamProvider.overrideWith((ref) => Stream.value(tasks)),
          notesStreamProvider.overrideWith(
            (ref) => Stream.value(const <domain.Note>[]),
          ),
          pomodoroSessionsBetweenProvider.overrideWith(
            (ref, range) => Stream.value(const <domain.PomodoroSession>[]),
          ),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已选 1'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byTooltip('预览本次发送'),
        matching: find.byType(ShadIconButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('发送预览'), findsOneWidget);
    expect(find.text('离线草稿：不会联网发送'), findsOneWidget);
    expect(find.text('问题'), findsWidgets);
    expect(find.text('证据'), findsWidgets);
  });
}
