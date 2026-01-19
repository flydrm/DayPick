import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart' as domain;

import 'app/daypick_app.dart';
import 'core/providers/app_providers.dart';
import 'routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  final notifications = container.read(localNotificationsServiceProvider);
  await notifications.initialize(
    onTap: (payload) {
      final taskId = _taskIdFromPayload(payload);
      final location = taskId == null ? '/focus' : '/focus?taskId=$taskId';
      container.read(goRouterProvider).go(location);
    },
  );

  final launchPayload = await notifications.getLaunchPayload();

  await _rescheduleActivePomodoroNotification(container);

  runApp(
    UncontrolledProviderScope(container: container, child: const DayPickApp()),
  );

  final launchTaskId = _taskIdFromPayload(launchPayload);
  if (launchTaskId != null) {
    Future.microtask(
      () => container.read(goRouterProvider).go('/focus?taskId=$launchTaskId'),
    );
  }
}

String? _taskIdFromPayload(String? payload) {
  if (payload == null) return null;
  const prefix = 'pomodoro_end:';
  if (!payload.startsWith(prefix)) return null;
  final taskId = payload.substring(prefix.length).trim();
  return taskId.isEmpty ? null : taskId;
}

Future<void> _rescheduleActivePomodoroNotification(
  ProviderContainer container,
) async {
  final config = await container.read(pomodoroConfigRepositoryProvider).get();
  final active = await container.read(activePomodoroRepositoryProvider).get();
  if (active == null) {
    await container.read(cancelPomodoroNotificationUseCaseProvider)();
    return;
  }

  if (active.status != domain.ActivePomodoroStatus.running ||
      active.endAt == null) {
    await container.read(cancelPomodoroNotificationUseCaseProvider)();
    return;
  }

  final endAt = active.endAt!;
  if (!endAt.isAfter(DateTime.now())) return;

  final title = await _notificationTitleForActive(container, active);

  await container.read(schedulePomodoroNotificationUseCaseProvider)(
    taskId: active.taskId,
    taskTitle: title,
    endAt: endAt,
    playSound: config.notificationSound,
    enableVibration: config.notificationVibration,
  );
}

Future<String> _notificationTitleForActive(
  ProviderContainer container,
  domain.ActivePomodoro active,
) async {
  return switch (active.phase) {
    domain.PomodoroPhase.focus => () async {
      final task = await container
          .read(taskRepositoryProvider)
          .getTaskById(active.taskId);
      final taskTitle = task?.title.value.trim() ?? '';
      if (taskTitle.isEmpty) return '专注结束';
      return '专注结束 · $taskTitle';
    }(),
    domain.PomodoroPhase.shortBreak => '短休结束',
    domain.PomodoroPhase.longBreak => '长休结束',
  };
}
