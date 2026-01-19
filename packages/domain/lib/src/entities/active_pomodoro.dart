enum ActivePomodoroStatus { running, paused, finished }

enum PomodoroPhase { focus, shortBreak, longBreak }

class ActivePomodoro {
  const ActivePomodoro({
    required this.taskId,
    this.phase = PomodoroPhase.focus,
    required this.status,
    required this.startAt,
    this.endAt,
    this.remainingMs,
    this.focusNote,
    required this.updatedAt,
  }) : assert(
         (status == ActivePomodoroStatus.running ||
                 status == ActivePomodoroStatus.finished)
             ? endAt != null
             : true,
       );

  final String taskId;
  final PomodoroPhase phase;
  final ActivePomodoroStatus status;
  final DateTime startAt;

  /// Present for running/finished states.
  final DateTime? endAt;

  /// Present for paused state.
  final int? remainingMs;

  /// Scratchpad captured during focus (optional).
  final String? focusNote;

  final DateTime updatedAt;

  bool get isBreak => phase != PomodoroPhase.focus;

  Duration remaining(DateTime now) {
    return switch (status) {
      ActivePomodoroStatus.running => Duration(
        milliseconds: (endAt!.difference(now)).inMilliseconds.clamp(0, 1 << 62),
      ),
      ActivePomodoroStatus.paused => Duration(milliseconds: remainingMs ?? 0),
      ActivePomodoroStatus.finished => Duration.zero,
    };
  }
}
