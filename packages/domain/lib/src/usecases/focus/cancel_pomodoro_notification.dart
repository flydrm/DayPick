import '../../repositories/pomodoro_notification_scheduler.dart';

class CancelPomodoroNotificationUseCase {
  CancelPomodoroNotificationUseCase({
    required PomodoroNotificationScheduler scheduler,
  }) : _scheduler = scheduler;

  final PomodoroNotificationScheduler _scheduler;

  Future<void> call() => _scheduler.cancelPomodoroEnd();
}
