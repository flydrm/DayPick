import '../entities/active_pomodoro.dart';

abstract interface class ActivePomodoroRepository {
  Stream<ActivePomodoro?> watch();
  Future<ActivePomodoro?> get();
  Future<void> upsert(ActivePomodoro state);
  Future<void> clear();
}
