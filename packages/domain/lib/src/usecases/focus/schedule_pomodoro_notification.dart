import '../../repositories/pomodoro_notification_scheduler.dart';

class SchedulePomodoroNotificationUseCase {
  SchedulePomodoroNotificationUseCase({
    required PomodoroNotificationScheduler scheduler,
  }) : _scheduler = scheduler;

  final PomodoroNotificationScheduler _scheduler;

  Future<void> call({
    required String taskId,
    required String taskTitle,
    required DateTime endAt,
    required bool playSound,
    required bool enableVibration,
  }) {
    return _scheduler.schedulePomodoroEnd(
      taskId: taskId,
      taskTitle: taskTitle,
      endAt: endAt,
      playSound: playSound,
      enableVibration: enableVibration,
    );
  }
}
