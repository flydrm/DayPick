import 'package:data/data.dart' as data;
import 'package:daypick/features/safe_mode/model/safe_mode_reason.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('safeModeInfoFromError maps known db open failures', () {
    expect(
      safeModeInfoFromError(
        const data.DbEncryptedButKeyMissingException(),
      )?.reason,
      SafeModeReason.dbKeyMissing,
    );

    expect(
      safeModeInfoFromError(
        const data.DbEncryptedButKeyRejectedException(),
      )?.reason,
      SafeModeReason.decryptFailed,
    );

    expect(
      safeModeInfoFromError(const data.SqlCipherUnavailableException())?.reason,
      SafeModeReason.other,
    );

    expect(
      safeModeInfoFromError(
        const data.DbMigrationFailedException(stage: 'in_progress'),
      )?.reason,
      SafeModeReason.migrationFailed,
    );

    expect(safeModeInfoFromError(Exception('nope')), isNull);
  });
}
