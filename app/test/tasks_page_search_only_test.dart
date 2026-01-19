import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/features/focus/providers/focus_providers.dart';
import 'package:daypick/features/notes/providers/note_providers.dart';
import 'package:daypick/features/tasks/providers/task_providers.dart';
import 'package:daypick/features/today/providers/today_plan_providers.dart';

import 'test_utils.dart';

void main() {
  testWidgets('Tasks 页提供全局创建入口（AppBar 右上角 +）', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksStreamProvider.overrideWith(
            (ref) => Stream.value(const <domain.Task>[]),
          ),
          notesStreamProvider.overrideWith(
            (ref) => Stream.value(const <domain.Note>[]),
          ),
          unprocessedNotesStreamProvider.overrideWith(
            (ref) => Stream.value(const <domain.Note>[]),
          ),
          todayPomodoroSessionsProvider.overrideWith(
            (ref) => Stream.value(const <domain.PomodoroSession>[]),
          ),
          yesterdayPomodoroSessionsProvider.overrideWith(
            (ref) => Stream.value(const <domain.PomodoroSession>[]),
          ),
          pomodoroConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.PomodoroConfig()),
          ),
          todayPlanTaskIdsProvider.overrideWith(
            (ref) => Stream.value(const <String>[]),
          ),
          todayPlanTaskIdsForDayProvider.overrideWith(
            (ref, day) => Stream.value(const <String>[]),
          ),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.AppearanceConfig()),
          ),
          activePomodoroProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    final bottomNav = find.byKey(const ValueKey('bottom_navigation'));
    await tester.tap(find.descendant(of: bottomNav, matching: find.text('任务')));
    await tester.pumpAndSettle();

    expect(find.text('搜索任务'), findsOneWidget);
    expect(find.byTooltip('创建'), findsOneWidget);
    expect(find.text('快速新增'), findsNothing);
    await disposeApp(tester);
  });
}
