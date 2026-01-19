class PomodoroConfig {
  const PomodoroConfig({
    this.workDurationMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.longBreakEvery = 4,
    this.dailyBudgetPomodoros = 8,
    this.autoStartBreak = false,
    this.autoStartFocus = false,
    this.notificationSound = false,
    this.notificationVibration = false,
  });

  final int workDurationMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int longBreakEvery;
  final int dailyBudgetPomodoros;
  final bool autoStartBreak;
  final bool autoStartFocus;
  final bool notificationSound;
  final bool notificationVibration;
}
