import '../entities/pomodoro_config.dart';

abstract interface class PomodoroConfigRepository {
  Stream<PomodoroConfig> watch();
  Future<PomodoroConfig> get();
  Future<void> save(PomodoroConfig config);
  Future<void> clear();
}
