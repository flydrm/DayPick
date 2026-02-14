import 'package:data/data.dart' as data;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backup supports current export schema version', () {
    expect(
      data.DataBackupService.supportedExportSchemaVersions,
      contains(data.DataExportService.exportSchemaVersion),
    );
  });
}
