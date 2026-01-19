import '../entities/today_plan_section.dart';

abstract interface class TodayPlanRepository {
  Stream<List<String>> watchTaskIdsForDay({
    required DateTime day,
    TodayPlanSection section = TodayPlanSection.today,
  });
  Future<List<String>> getTaskIdsForDay({
    required DateTime day,
    TodayPlanSection section = TodayPlanSection.today,
  });

  Future<void> addTask({
    required DateTime day,
    required String taskId,
    TodayPlanSection section = TodayPlanSection.today,
  });

  Future<void> removeTask({required DateTime day, required String taskId});

  Future<void> replaceTasks({
    required DateTime day,
    required List<String> taskIds,
    TodayPlanSection section = TodayPlanSection.today,
  });

  Future<void> clearDay({
    required DateTime day,
    TodayPlanSection section = TodayPlanSection.today,
  });

  Future<void> clearAll({required DateTime day});

  Future<void> moveTaskToSection({
    required DateTime day,
    required String taskId,
    required TodayPlanSection section,
    int? toIndex,
  });
}
