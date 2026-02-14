class DbMigrationFailedException implements Exception {
  const DbMigrationFailedException({required this.stage, this.cause});

  /// content-free stage label (e.g. "in_progress", "backup_failed", "export_failed")
  final String stage;

  /// Optional underlying error. Must never include user content or keys.
  final Object? cause;

  @override
  String toString() => 'DbMigrationFailedException(stage=$stage)';
}

