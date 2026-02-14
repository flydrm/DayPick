import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/feature_flags/feature_flag_keys.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/routing/app_router.dart';
import 'package:daypick/routing/home_shell.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/semantics.dart';

import 'test_utils.dart';

class _InMemoryNoteRepository implements domain.NoteRepository {
  final _notes = <domain.Note>[];

  @override
  Stream<List<domain.Note>> watchAllNotes() => Stream.value(_notes);

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
    _notes.removeWhere((n) => n.id == note.id);
    _notes.add(note);
  }

  @override
  Future<void> deleteNote(String noteId) async {
    _notes.removeWhere((n) => n.id == noteId);
  }
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/today',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell, state: state),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ai',
                builder: (context, state) => const Scaffold(body: Text('ai')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notes',
                builder: (context, state) =>
                    const Scaffold(body: Text('notes')),
                routes: [
                  GoRoute(
                    path: ':noteId',
                    builder: (context, state) =>
                        const Scaffold(body: Text('note_detail')),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                builder: (context, state) =>
                    const Scaffold(body: Text('today')),
                routes: [
                  GoRoute(
                    path: 'timeboxing',
                    builder: (context, state) =>
                        const Scaffold(body: Text('timeboxing')),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tasks',
                builder: (context, state) =>
                    const Scaffold(body: Text('tasks')),
                routes: [
                  GoRoute(
                    path: ':taskId',
                    builder: (context, state) =>
                        const Scaffold(body: Text('task_detail')),
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
                    const Scaffold(body: Text('focus')),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const Scaffold(body: Text('settings')),
      ),
    ],
  );
}

Override _flags({required bool captureBar}) {
  return featureFlagEnabledProvider.overrideWith((ref, key) {
    if (key == FeatureFlagKeys.captureBar) return Stream.value(captureBar);
    return Stream.value(false);
  });
}

void main() {
  testWidgets('Capture Bar：flag 关闭时不显示', (tester) async {
    final router = _router();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.AppearanceConfig()),
          ),
          _flags(captureBar: false),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('capture_bar_input')), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('Capture Bar：仅在 Today/Notes/Tasks 主页面可见', (tester) async {
    final router = _router();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.AppearanceConfig()),
          ),
          _flags(captureBar: true),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Today root
    expect(find.byKey(const ValueKey('capture_bar_input')), findsOneWidget);

    // Notes root
    await tester.tap(find.text('笔记'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('capture_bar_input')), findsOneWidget);

    // Notes detail (hide)
    router.push('/notes/n1');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('capture_bar_input')), findsNothing);

    // Tasks root
    router.go('/tasks');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('capture_bar_input')), findsOneWidget);

    // Task detail (hide)
    router.push('/tasks/t1');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('capture_bar_input')), findsNothing);

    // AI tab (hide)
    router.go('/ai');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('capture_bar_input')), findsNothing);

    // Focus tab (hide)
    router.go('/focus');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('capture_bar_input')), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('Capture Bar：草稿在 tab/路由/app lifecycle 下不丢', (tester) async {
    final router = _router();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.AppearanceConfig()),
          ),
          _flags(captureBar: true),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('capture_bar_input')),
      'hello',
    );
    await tester.pumpAndSettle();

    // Switch tab away where bar is hidden.
    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('capture_bar_input')), findsNothing);

    // Back to Today, draft should remain.
    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget);

    // Push a root route and pop back.
    router.push('/settings');
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget);

    // Simulate app background/resume.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('Capture Bar：入口具备语义 label 且可点击', (tester) async {
    final router = _router();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.AppearanceConfig()),
          ),
          _flags(captureBar: true),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    final semanticsHandle = tester.ensureSemantics();
    try {
      // Enable the action so semantics should expose tap action.
      await tester.enterText(
        find.byKey(const ValueKey('capture_bar_input')),
        'hello',
      );
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(
        find.byKey(const ValueKey('capture_bar_open')),
      );
      final data = semantics.getSemanticsData();
      expect(data.label, contains('创建'));
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
    } finally {
      semanticsHandle.dispose();
    }

    await disposeApp(tester);
  });

  testWidgets('Capture Bar：关闭 Quick Create 保留草稿；创建成功后清空', (tester) async {
    final router = _router();
    final noteRepo = _InMemoryNoteRepository();
    final createNote = domain.CreateNoteUseCase(
      repository: noteRepo,
      generateId: () => 'n1',
      now: () => DateTime(2026, 2, 3),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.AppearanceConfig()),
          ),
          _flags(captureBar: true),
          createNoteUseCaseProvider.overrideWithValue(createNote),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('capture_bar_input')),
      'hello',
    );
    await tester.pumpAndSettle();

    // Open quick create and close it.
    await tester.tap(find.byKey(const ValueKey('capture_bar_open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget);

    // Open quick create and create a memo successfully.
    await tester.tap(find.byKey(const ValueKey('capture_bar_open')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建闪念'));
    await tester.pumpAndSettle();

    // Draft cleared.
    expect(find.text('hello'), findsNothing);

    await disposeApp(tester);
  });
  testWidgets('Capture Bar：关键按钮触控目标 >= 48dp', (tester) async {
    final router = _router();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.AppearanceConfig()),
          ),
          _flags(captureBar: true),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('capture_bar_input')),
      'hello',
    );
    await tester.pumpAndSettle();

    final createSize = tester.getSize(
      find.byKey(const ValueKey('capture_bar_create_button')),
    );
    final clearSize = tester.getSize(
      find.byKey(const ValueKey('capture_bar_clear')),
    );

    expect(createSize.width, greaterThanOrEqualTo(48));
    expect(createSize.height, greaterThanOrEqualTo(48));
    expect(clearSize.width, greaterThanOrEqualTo(48));
    expect(clearSize.height, greaterThanOrEqualTo(48));

    await disposeApp(tester);
  });

  testWidgets('Capture Bar：关闭 Quick Create 后恢复输入焦点', (tester) async {
    final router = _router();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.AppearanceConfig()),
          ),
          _flags(captureBar: true),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('capture_bar_input')),
      'hello',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('capture_bar_create_button')));
    await tester.pumpAndSettle();
    expect(find.text('Quick Create'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quick_create_close')));
    await tester.pumpAndSettle();

    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('capture_bar_input')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.focusNode.hasFocus, isTrue);

    await disposeApp(tester);
  });
}
