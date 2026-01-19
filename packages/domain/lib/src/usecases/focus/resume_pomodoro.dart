import '../../entities/active_pomodoro.dart';
import '../../repositories/active_pomodoro_repository.dart';

typedef _Now = DateTime Function();

class ResumePomodoroUseCase {
  ResumePomodoroUseCase({
    required ActivePomodoroRepository repository,
    _Now now = DateTime.now,
  }) : _repository = repository,
       _now = now;

  final ActivePomodoroRepository _repository;
  final _Now _now;

  Future<ActivePomodoro?> call() async {
    final active = await _repository.get();
    if (active == null) return null;
    if (active.status != ActivePomodoroStatus.paused) return active;

    final now = _now();
    final remainingMs = (active.remainingMs ?? 0).clamp(0, 1 << 62);
    final endAt = now.add(Duration(milliseconds: remainingMs));
    final running = ActivePomodoro(
      taskId: active.taskId,
      phase: active.phase,
      status: ActivePomodoroStatus.running,
      startAt: active.startAt,
      endAt: endAt,
      focusNote: active.focusNote,
      updatedAt: now,
    );
    await _repository.upsert(running);
    return running;
  }
}
