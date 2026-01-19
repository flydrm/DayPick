import '../../entities/active_pomodoro.dart';
import '../../entities/pomodoro_session.dart';
import '../../repositories/active_pomodoro_repository.dart';
import '../../repositories/pomodoro_session_repository.dart';

typedef PomodoroSessionIdGenerator = String Function();
typedef _Now = DateTime Function();

class CompletePomodoroUseCase {
  CompletePomodoroUseCase({
    required ActivePomodoroRepository activeRepository,
    required PomodoroSessionRepository sessionRepository,
    required PomodoroSessionIdGenerator generateSessionId,
    _Now now = DateTime.now,
  }) : _activeRepository = activeRepository,
       _sessionRepository = sessionRepository,
       _generateSessionId = generateSessionId,
       _now = now;

  final ActivePomodoroRepository _activeRepository;
  final PomodoroSessionRepository _sessionRepository;
  final PomodoroSessionIdGenerator _generateSessionId;
  final _Now _now;

  Future<PomodoroSession?> call({
    String? progressNote,
    required bool isDraft,
    DateTime? actualEndAt,
  }) async {
    final active = await _activeRepository.get();
    if (active == null) return null;
    if (active.phase != PomodoroPhase.focus) return null;

    final now = _now();
    final endAt = actualEndAt ?? active.endAt ?? now;

    final session = PomodoroSession(
      id: _generateSessionId(),
      taskId: active.taskId,
      startAt: active.startAt,
      endAt: endAt,
      isDraft: isDraft,
      progressNote: progressNote?.trim().isEmpty == true
          ? null
          : progressNote?.trim(),
      createdAt: now,
    );

    await _sessionRepository.upsertSession(session);
    await _activeRepository.clear();
    return session;
  }
}
