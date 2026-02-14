import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/feedback/action_toast_service.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/routing/app_router.dart';
import 'package:daypick/ui/kit/dp_action_toast.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _ToastHostPage extends ConsumerWidget {
  const _ToastHostPage({required this.onUndo, required this.onBridge});

  final Future<void> Function() onUndo;
  final Future<void> Function(String entryId) onBridge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: TextButton(
          key: const ValueKey('show_toast'),
          onPressed: () {
            ref
                .read(actionToastServiceProvider)
                .showSuccess(
                  '任务已创建',
                  undo: DpActionToastUndoAction(label: '撤销', onPressed: onUndo),
                  bridge: DpActionToastBridgeAction(
                    label: '回到今天',
                    entryId: 'e-1',
                    onPressed: onBridge,
                  ),
                );
          },
          child: const Text('Show Toast'),
        ),
      ),
    );
  }
}

void main() {
  test('ActionToastService reports unavailable messenger state', () {
    var unavailableCount = 0;
    final service = ActionToastService(
      scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
    );
    service.setOnUnavailable(() => unavailableCount++);

    service.showSuccess('任务已创建');

    expect(unavailableCount, 1);
  });

  testWidgets('ActionToastService shows dual actions with 6s duration', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var undoCount = 0;
    final router = GoRouter(
      initialLocation: '/host',
      routes: [
        GoRoute(
          path: '/host',
          builder: (context, state) => _ToastHostPage(
            onUndo: () async => undoCount++,
            onBridge: (_) async {},
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
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('show_toast')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(seconds: 6),
    );

    final undoFinder = find.byKey(const ValueKey('dp_action_toast_undo'));
    final bridgeFinder = find.byKey(const ValueKey('dp_action_toast_bridge'));
    expect(undoFinder, findsOneWidget);
    expect(bridgeFinder, findsOneWidget);
    expect(
      tester.getTopLeft(undoFinder).dx,
      lessThan(tester.getTopLeft(bridgeFinder).dx),
    );

    await tester.tap(undoFinder);
    await tester.pumpAndSettle();

    expect(undoCount, 1);
    expect(find.byKey(const ValueKey('dp_action_toast_undo')), findsNothing);
    expect(find.byKey(const ValueKey('dp_action_toast_bridge')), findsNothing);
    expect(find.text('已撤销'), findsOneWidget);
  });

  testWidgets('Bridge action receives entryId and dismisses toast', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? bridgedEntryId;
    final router = GoRouter(
      initialLocation: '/host',
      routes: [
        GoRoute(
          path: '/host',
          builder: (context, state) => _ToastHostPage(
            onUndo: () async {},
            onBridge: (entryId) async => bridgedEntryId = entryId,
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
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('show_toast')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dp_action_toast_bridge')));
    await tester.pumpAndSettle();

    expect(bridgedEntryId, 'e-1');
    expect(find.byType(SnackBar), findsNothing);
  });
}
