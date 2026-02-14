import 'dart:typed_data';

import 'package:data/db/db_connection_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new install: no target and no *.sqlite files', () {
    expect(
      isNewInstallForSqlCipher(targetExists: false, sqliteFileCount: 0),
      isTrue,
    );
  });

  test('existing target: not a new install', () {
    expect(
      isNewInstallForSqlCipher(targetExists: true, sqliteFileCount: 0),
      isFalse,
    );
  });

  test(
    'single legacy sqlite file triggers brownfield path (rename branch)',
    () {
      expect(
        isNewInstallForSqlCipher(targetExists: false, sqliteFileCount: 1),
        isFalse,
      );
    },
  );

  test('multiple sqlite files triggers brownfield path', () {
    expect(
      isNewInstallForSqlCipher(targetExists: false, sqliteFileCount: 2),
      isFalse,
    );
  });

  test('hasPlaintextSqliteHeader detects SQLite header', () {
    final bytes = Uint8List.fromList('SQLite format 3\u0000'.codeUnits);
    expect(hasPlaintextSqliteHeader(bytes), isTrue);
  });

  test('hasPlaintextSqliteHeader returns false for random bytes', () {
    expect(
      hasPlaintextSqliteHeader(Uint8List.fromList([1, 2, 3, 4, 5])),
      isFalse,
    );
  });

  test('decideDbOpenPlan: new install uses encryption', () {
    expect(
      decideDbOpenPlan(
        isNewInstall: true,
        dbFileExists: false,
        sqliteFileCount: 0,
        hasPlaintextHeader: false,
        keyExists: false,
        hasMigrationArtifacts: false,
      ),
      DbOpenPlan.encrypted,
    );
  });

  test(
    'decideDbOpenPlan: plaintext header triggers migration, even if key exists',
    () {
      expect(
        decideDbOpenPlan(
          isNewInstall: false,
          dbFileExists: true,
          sqliteFileCount: 0,
          hasPlaintextHeader: true,
          keyExists: true,
          hasMigrationArtifacts: false,
        ),
        DbOpenPlan.migratePlaintext,
      );
    },
  );

  test('decideDbOpenPlan: encrypted db without key should fail fast', () {
    expect(
      decideDbOpenPlan(
        isNewInstall: false,
        dbFileExists: true,
        sqliteFileCount: 0,
        hasPlaintextHeader: false,
        keyExists: false,
        hasMigrationArtifacts: false,
      ),
      DbOpenPlan.encryptedMissingKey,
    );
  });

  test('decideDbOpenPlan: migration artifacts blocks new empty db', () {
    expect(
      decideDbOpenPlan(
        isNewInstall: false,
        dbFileExists: false,
        sqliteFileCount: 0,
        hasPlaintextHeader: false,
        keyExists: false,
        hasMigrationArtifacts: true,
      ),
      DbOpenPlan.migrationInProgress,
    );
  });

  test('decideDbOpenPlan: sqlite candidates but no resolvable db is in-progress', () {
    expect(
      decideDbOpenPlan(
        isNewInstall: false,
        dbFileExists: false,
        sqliteFileCount: 2,
        hasPlaintextHeader: false,
        keyExists: false,
        hasMigrationArtifacts: false,
      ),
      DbOpenPlan.migrationInProgress,
    );
  });
}
