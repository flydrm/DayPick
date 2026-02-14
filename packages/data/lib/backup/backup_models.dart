import 'backup_exceptions.dart';

class BackupPreview {
  const BackupPreview({
    required this.backupFormatVersion,
    required this.schemaVersion,
    required this.exportedAtUtcMillis,
    required this.includesSecrets,
    required this.taskCount,
    required this.noteCount,
    required this.weaveLinkCount,
    required this.sessionCount,
    required this.checklistCount,
  });

  final int backupFormatVersion;
  final int schemaVersion;
  final int exportedAtUtcMillis;
  final bool includesSecrets;
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

class BackupCancellationToken {
  BackupCancellationToken();

  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }

  void throwIfCancelled() {
    if (_isCancelled) throw const BackupCancelledException();
  }
}
