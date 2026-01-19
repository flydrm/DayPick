import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/features/ai/providers/ai_providers.dart';
import 'package:daypick/features/notes/providers/note_providers.dart';
import 'package:daypick/features/notes/view/note_ai_summary_sheet.dart';
import 'package:daypick/routing/app_router.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

domain.Note _note({required DateTime now}) {
  return domain.Note(
    id: 'n-1',
    title: domain.NoteTitle('Note A'),
    body: '- 对齐接口字段\n- 补充错误码定义\n\n其他记录…',
    tags: const [],
    createdAt: now,
    updatedAt: now,
    kind: domain.NoteKind.longform,
    triageStatus: domain.TriageStatus.scheduledLater,
  );
}

void main() {
  testWidgets('Note AI summary supports offline + send preview', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final note = _note(now: now);

    final router = GoRouter(
      initialLocation: '/note-ai-summary',
      routes: [
        GoRoute(
          path: '/note-ai-summary',
          builder: (context, state) => const NoteAiSummarySheet(noteId: 'n-1'),
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
          noteByIdProvider.overrideWith(
            (ref, id) => Stream.value(id == 'n-1' ? note : null),
          ),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byTooltip('预览本次发送'),
        matching: find.byType(ShadIconButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('发送预览'), findsOneWidget);
    expect(find.text('离线草稿：不会联网发送'), findsOneWidget);

    await tester.tap(find.widgetWithText(ShadButton, '关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ShadButton, '生成离线草稿'));
    await tester.pumpAndSettle();

    final editable = tester.widget<EditableText>(
      find.byType(EditableText).first,
    );
    expect(editable.controller.text, contains('总结要点（离线草稿）'));
  });
}
