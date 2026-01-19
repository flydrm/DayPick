class PomodoroSession {
  const PomodoroSession({
    required this.id,
    required this.taskId,
    required this.startAt,
    required this.endAt,
    required this.isDraft,
    this.progressNote,
    required this.createdAt,
  });

  final String id;
  final String taskId;
  final DateTime startAt;
  final DateTime endAt;
  final bool isDraft;
  final String? progressNote;
  final DateTime createdAt;

  Duration get duration => endAt.difference(startAt);
}
