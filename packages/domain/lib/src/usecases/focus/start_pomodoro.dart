import '../../entities/active_pomodoro.dart';
import '../../entities/pomodoro_config.dart';
import '../../repositories/active_pomodoro_repository.dart';

typedef _Now = DateTime Function();

class StartPomodoroUseCase {
  StartPomodoroUseCase({
    required ActivePomodoroRepository repository,
    _Now now = DateTime.now,
  }) : _repository = repository,
       _now = now;

  final ActivePomodoroRepository _repository;
  final _Now _now;

  Future<ActivePomodoro> call({
    required String taskId,
    required PomodoroConfig config,
  }) async {
    final now = _now();
    final endAt = now.add(Duration(minutes: config.workDurationMinutes));
    final state = ActivePomodoro(
      taskId: taskId,
      phase: PomodoroPhase.focus,
      status: ActivePomodoroStatus.running,
      startAt: now,
      endAt: endAt,
      updatedAt: now,
    );
    await _repository.upsert(state);
    return state;
  }
}
