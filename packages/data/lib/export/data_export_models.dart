class ExportSnapshot {
  const ExportSnapshot({
    required this.exportedAtUtcMillis,
    required this.tasks,
    required this.todayPlanItems,
    required this.taskCheckItems,
    required this.notes,
    required this.weaveLinks,
    required this.pomodoroSessions,
    required this.kpiDailyRollups,
    required this.pomodoroConfig,
    required this.appearanceConfig,
  });

  final int exportedAtUtcMillis;
  final List<Map<String, Object?>> tasks;
  final List<Map<String, Object?>> todayPlanItems;
  final List<Map<String, Object?>> taskCheckItems;
  final List<Map<String, Object?>> notes;
  final List<Map<String, Object?>> weaveLinks;
  final List<Map<String, Object?>> pomodoroSessions;
  final List<Map<String, Object?>> kpiDailyRollups;
  final Map<String, Object?> pomodoroConfig;
  final Map<String, Object?> appearanceConfig;

  int get taskCount => tasks.length;
  int get noteCount => notes.length;
  int get weaveLinkCount => weaveLinks.length;
  int get sessionCount => pomodoroSessions.length;
  int get checklistCount => taskCheckItems.length;
  int get todayPlanItemCount => todayPlanItems.length;
  int get kpiDailyRollupCount => kpiDailyRollups.length;
}
