import '../../entities/active_pomodoro.dart';
import '../../repositories/active_pomodoro_repository.dart';

typedef _Now = DateTime Function();

class PausePomodoroUseCase {
  PausePomodoroUseCase({
    required ActivePomodoroRepository repository,
    _Now now = DateTime.now,
  }) : _repository = repository,
       _now = now;

  final ActivePomodoroRepository _repository;
  final _Now _now;

  Future<ActivePomodoro?> call() async {
    final active = await _repository.get();
    if (active == null) return null;
    if (active.status != ActivePomodoroStatus.running) return active;

    final now = _now();
    final remainingMs = active.endAt!.difference(now).inMilliseconds;
    final paused = ActivePomodoro(
      taskId: active.taskId,
      phase: active.phase,
      status: ActivePomodoroStatus.paused,
      startAt: active.startAt,
      remainingMs: remainingMs.clamp(0, 1 << 62),
      focusNote: active.focusNote,
      updatedAt: now,
    );
    await _repository.upsert(paused);
    return paused;
  }
}
