import 'dart:typed_data';

bool isNewInstallForSqlCipher({
  required bool targetExists,
  required int sqliteFileCount,
}) => !targetExists && sqliteFileCount == 0;

enum DbOpenPlan {
  /// Normal encrypted open (new install or already-migrated encrypted DB).
  encrypted,

  /// Encrypted DB detected but key missing/unreadable -> fail fast to safe mode.
  encryptedMissingKey,

  /// Plaintext (legacy) DB detected -> must migrate to SQLCipher.
  migratePlaintext,

  /// Migration artifacts detected (state file / temp db / backups) or ambiguous
  /// brownfield state -> must NOT create a new empty DB.
  migrationInProgress,
}

DbOpenPlan decideDbOpenPlan({
  required bool isNewInstall,
  required bool dbFileExists,
  required int sqliteFileCount,
  required bool hasPlaintextHeader,
  required bool keyExists,
  required bool hasMigrationArtifacts,
}) {
  if (hasMigrationArtifacts) return DbOpenPlan.migrationInProgress;
  if (isNewInstall) return DbOpenPlan.encrypted;

  // If we have some *.sqlite candidates but can't resolve a single DB file to open,
  // never create a new empty database (data-loss risk).
  if (!dbFileExists && sqliteFileCount > 0) return DbOpenPlan.migrationInProgress;

  if (!dbFileExists) return DbOpenPlan.migrationInProgress;
  if (hasPlaintextHeader) return DbOpenPlan.migratePlaintext;
  if (!keyExists) return DbOpenPlan.encryptedMissingKey;
  return DbOpenPlan.encrypted;
}

bool hasPlaintextSqliteHeader(Uint8List headerBytes) {
  if (headerBytes.length < _sqlitePlaintextHeaderBytes.length) return false;

  for (var i = 0; i < _sqlitePlaintextHeaderBytes.length; i++) {
    if (headerBytes[i] != _sqlitePlaintextHeaderBytes[i]) return false;
  }

  return true;
}

const _sqlitePlaintextHeaderBytes = <int>[
  0x53, // S
  0x51, // Q
  0x4c, // L
  0x69, // i
  0x74, // t
  0x65, // e
  0x20, // ' '
  0x66, // f
  0x6f, // o
  0x72, // r
  0x6d, // m
  0x61, // a
  0x74, // t
  0x20, // ' '
  0x33, // 3
  0x00, // \0
];
