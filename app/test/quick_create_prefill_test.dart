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

class _HostPage extends StatelessWidget {
  const _HostPage({required this.initialText});

  final String initialText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ShadButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => QuickCreateSheet(
              initialType: QuickCreateType.memo,
              initialText: initialText,
            ),
          ),
          child: const Text('Open Quick Create'),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('QuickCreate supports prefilled text across tabs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const prefill = 'Hello world\nSecond line';

    final router = GoRouter(
      initialLocation: '/host',
      routes: [
        GoRoute(
          path: '/host',
          builder: (context, state) => const _HostPage(initialText: prefill),
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

    await tester.tap(find.text('Open Quick Create'));
    await tester.pumpAndSettle();

    final memo = tester.widget<ShadInput>(
      find.byKey(const ValueKey('quick_create_memo_body')),
    );
    expect(memo.controller!.text, prefill);

    await tester.tap(find.text('任务'));
    await tester.pumpAndSettle();

    final task = tester.widget<ShadInput>(
      find.byKey(const ValueKey('quick_create_task_title')),
    );
    expect(task.controller!.text, 'Hello world');

    await tester.tap(find.text('长文'));
    await tester.pumpAndSettle();

    final draft = tester.widget<ShadInput>(
      find.byKey(const ValueKey('quick_create_draft_body')),
    );
    expect(draft.controller!.text, prefill);
  });
}
