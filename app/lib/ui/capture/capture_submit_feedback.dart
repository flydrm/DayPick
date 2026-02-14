import 'dart:async';

import 'package:domain/domain.dart' as domain;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/capture/capture_highlight_target.dart';
import '../../core/capture/capture_submit_result.dart';
import '../../core/local_events/today_3s_session_controller.dart';
import '../../core/providers/app_providers.dart';
import '../../routing/app_router.dart';
import '../kit/dp_action_toast.dart';

void showCaptureSubmitSuccessToast({
  required ProviderContainer container,
  required CaptureSubmitResult result,
}) {
  final highlightTarget = CaptureHighlightTarget.fromSubmitResult(result);

  unawaited(
    container
        .read(today3sSessionControllerProvider.notifier)
        .recordPrimaryActionInvoked(action: 'capture_submit'),
  );

  container
      .read(actionToastServiceProvider)
      .showSuccess(
        _messageFor(result.entryKind),
        undo: DpActionToastUndoAction(
          label: '撤销',
          onPressed: () => _undo(container, result),
        ),
        bridge: DpActionToastBridgeAction(
          label: '回到今天',
          entryId: result.entryId,
          onPressed: (_) => _bridge(container, highlightTarget),
        ),
      );
}

Future<void> _undo(ProviderContainer container, CaptureSubmitResult result) {
  return switch (result.entryKind) {
    CaptureEntryKind.task => _undoTask(container, result),
    CaptureEntryKind.memo => _undoNote(container, result.entryId),
    CaptureEntryKind.draft => _undoNote(container, result.entryId),
  };
}

Future<void> _undoTask(
  ProviderContainer container,
  CaptureSubmitResult result,
) async {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  try {
    await container
        .read(todayPlanRepositoryProvider)
        .removeTask(day: day, taskId: result.entryId);
  } catch (_) {}
  await container.read(taskRepositoryProvider).deleteTask(result.entryId);
}

Future<void> _undoNote(ProviderContainer container, String noteId) async {
  await container.read(noteRepositoryProvider).deleteNote(noteId);
}

Future<void> _bridge(
  ProviderContainer container,
  CaptureHighlightTarget target,
) async {
  if (target.kind == CaptureHighlightKind.task) {
    await _addTaskToTodayPlan(container: container, taskId: target.entryId);
  }
  final encodedTarget = Uri.encodeQueryComponent(target.serialized);
  container.read(goRouterProvider).go('/today?highlight=$encodedTarget');
}

Future<void> _addTaskToTodayPlan({
  required ProviderContainer container,
  required String taskId,
}) async {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  try {
    await container
        .read(todayPlanRepositoryProvider)
        .moveTaskToSection(
          day: day,
          taskId: taskId,
          section: domain.TodayPlanSection.today,
          toIndex: 0,
        );
  } catch (_) {
    try {
      await container
          .read(todayPlanRepositoryProvider)
          .addTask(day: day, taskId: taskId);
    } catch (_) {}
  }
}

String _messageFor(CaptureEntryKind entryKind) {
  return switch (entryKind) {
    CaptureEntryKind.task => '任务已创建',
    CaptureEntryKind.memo => '闪念已收下',
    CaptureEntryKind.draft => '长文草稿已保存',
  };
}
