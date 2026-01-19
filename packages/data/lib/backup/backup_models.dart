class BackupPreview {
  const BackupPreview({
    required this.schemaVersion,
    required this.exportedAtUtcMillis,
    required this.taskCount,
    required this.noteCount,
    required this.weaveLinkCount,
    required this.sessionCount,
    required this.checklistCount,
  });

  final int schemaVersion;
  final int exportedAtUtcMillis;
  final int taskCount;
  final int noteCount;
  final int weaveLinkCount;
  final int sessionCount;
  final int checklistCount;
}

class RestoreResult {
  const RestoreResult({
    required this.taskCount,
    required this.noteCount,
    required this.weaveLinkCount,
    required this.sessionCount,
    required this.checklistCount,
  });

  final int taskCount;
  final int noteCount;
  final int weaveLinkCount;
  final int sessionCount;
  final int checklistCount;
}
