import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/feedback/action_toast_service.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/routing/app_router.dart';
import 'package:daypick/ui/sheets/quick_create_route_page.dart';
import 'package:daypick/ui/sheets/quick_create_sheet.dart';
import 'package:daypick/ui/kit/dp_action_toast.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _CapturingTaskRepository implements domain.TaskRepository {
  @override
  Stream<List<domain.Task>> watchAllTasks() =>
      Stream.value(const <domain.Task>[]);

  @override
  Future<domain.Task?> getTaskById(String taskId) async => null;

  @override
  Future<void> upsertTask(domain.Task task) async {}

  @override
  Future<void> deleteTask(String taskId) async {}
}

class _CapturingActionToastService extends ActionToastService {
  _CapturingActionToastService()
    : super(scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>());

  String? lastMessage;
  DpActionToastUndoAction? lastUndo;
  DpActionToastBridgeAction? lastBridge;

  @override
  void showSuccess(
    String message, {
    Duration? duration,
    DpActionToastUndoAction? undo,
    DpActionToastBridgeAction? bridge,
  }) {
    lastMessage = message;
    lastUndo = undo;
    lastBridge = bridge;
  }

  @override
  void showError(String message, {Duration? duration}) {}
}

class _AutoOpenCreateHostPage extends StatefulWidget {
  const _AutoOpenCreateHostPage();

  @override
  State<_AutoOpenCreateHostPage> createState() =>
      _AutoOpenCreateHostPageState();
}

class _AutoOpenCreateHostPageState extends State<_AutoOpenCreateHostPage> {
  var _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.push('/create');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('host'));
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 50),
  int maxPumps = 200,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(step);
  }
  throw StateError('Timed out waiting for finder: $finder');
}

void main() {
  testWidgets(
    'QuickCreateRoutePage success triggers toast and bridge callback',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = _CapturingTaskRepository();
      final createTask = domain.CreateTaskUseCase(
        repository: repo,
        generateId: () => 't-1',
      );
      final toastService = _CapturingActionToastService();

      final router = GoRouter(
        initialLocation: '/host',
        routes: [
          GoRoute(
            path: '/host',
            builder: (context, state) => const _AutoOpenCreateHostPage(),
          ),
          GoRoute(
            path: '/today',
            builder: (context, state) {
              final highlight = state.uri.queryParameters['highlight'] ?? '';
              return Scaffold(
                body: Column(
                  children: [
                    const Text('today'),
                    Text(
                      'highlight:$highlight',
                      key: const ValueKey('today_highlight_param'),
                    ),
                  ],
                ),
              );
            },
          ),
          GoRoute(
            path: '/create',
            builder: (context, state) => const QuickCreateRoutePage(
              initialType: QuickCreateType.task,
              initialTaskAddToToday: false,
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
            actionToastServiceProvider.overrideWithValue(toastService),
          ],
          child: const DayPickApp(),
        ),
      );
      await tester.pump();
      await tester.pump();
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('quick_create_task_title')),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(
        find.byKey(const ValueKey('quick_create_task_title')),
        'Test task',
      );
      await tester.pump();

      final submitFinder = find.byKey(
        const ValueKey('quick_create_task_submit'),
      );
      await tester.ensureVisible(submitFinder);
      await tester.pump();
      await tester.tap(submitFinder);
      await tester.pump();
      await _pumpUntilFound(tester, find.text('host'));

      expect(toastService.lastMessage, '任务已创建');
      expect(toastService.lastUndo, isNotNull);
      expect(toastService.lastBridge, isNotNull);
      expect(toastService.lastBridge!.entryId, 't-1');

      await toastService.lastBridge!.onPressed(
        toastService.lastBridge!.entryId,
      );
      await tester.pumpAndSettle();
      expect(find.text('today'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('today_highlight_param')),
        findsOneWidget,
      );
      expect(find.text('highlight:task:t-1'), findsOneWidget);
    },
  );
}
