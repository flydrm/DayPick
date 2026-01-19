import '../entities/pomodoro_session.dart';

abstract interface class PomodoroSessionRepository {
  Stream<List<PomodoroSession>> watchByTaskId(String taskId);
  Stream<List<PomodoroSession>> watchBetween(
    DateTime startInclusive,
    DateTime endExclusive,
  );
  Stream<int> watchCountByTaskId(String taskId);
  Stream<int> watchCountBetween(DateTime startInclusive, DateTime endExclusive);
  Future<void> upsertSession(PomodoroSession session);
  Future<void> deleteSession(String sessionId);
}
