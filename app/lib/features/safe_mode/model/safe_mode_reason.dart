import 'package:data/data.dart' as data;

enum SafeModeReason {
  dbKeyMissing,
  decryptFailed,
  migrationFailed,
  other;

  String get code {
    return switch (this) {
      SafeModeReason.dbKeyMissing => 'db_key_missing',
      SafeModeReason.decryptFailed => 'decrypt_failed',
      SafeModeReason.migrationFailed => 'migration_failed',
      SafeModeReason.other => 'other',
    };
  }
}

class SafeModeInfo {
  const SafeModeInfo({required this.reason, this.debugLabel});

  final SafeModeReason reason;

  /// Optional, content-free detail for diagnosis (e.g. exception type).
  final String? debugLabel;
}

SafeModeInfo? safeModeInfoFromError(Object error) {
  if (error is data.DbEncryptedButKeyMissingException) {
    return SafeModeInfo(
      reason: SafeModeReason.dbKeyMissing,
      debugLabel: error.runtimeType.toString(),
    );
  }
  if (error is data.DbEncryptedButKeyRejectedException) {
    return SafeModeInfo(
      reason: SafeModeReason.decryptFailed,
      debugLabel: error.runtimeType.toString(),
    );
  }
  if (error is data.DbMigrationFailedException) {
    return SafeModeInfo(
      reason: SafeModeReason.migrationFailed,
      debugLabel: error.toString(),
    );
  }
  if (error is data.SqlCipherUnavailableException) {
    return SafeModeInfo(
      reason: SafeModeReason.other,
      debugLabel: error.runtimeType.toString(),
    );
  }
  return null;
}
