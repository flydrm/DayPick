import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/routing/app_router.dart';
import 'package:daypick/ui/sheets/quick_create_sheet.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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

class _HostPage extends StatelessWidget {
  const _HostPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ShadButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => const QuickCreateSheet(),
          ),
          child: const Text('Open Quick Create'),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('QuickCreate task due date quick-set works', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = _CapturingTaskRepository();
    final create = domain.CreateTaskUseCase(
      repository: repo,
      generateId: () => 't-1',
    );
    final router = GoRouter(
      initialLocation: '/host',
      routes: [
        GoRoute(path: '/host', builder: (context, state) => const _HostPage()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.AppearanceConfig()),
          ),
          createTaskUseCaseProvider.overrideWithValue(create),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Quick Create'));
    await tester.pumpAndSettle();
    expect(find.text('Quick Create'), findsOneWidget);

    await tester.tap(find.text('展开可选字段'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final ymd =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    expect(find.text('截止：$ymd'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, 'Test task');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ShadButton, '创建任务'));
    await tester.pumpAndSettle();

    expect(repo.lastUpserted, isNotNull);
    final task = repo.lastUpserted!;
    expect(task.triageStatus, domain.TriageStatus.inbox);
    expect(task.dueAt, DateTime(now.year, now.month, now.day));
  });
}
