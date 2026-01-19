import 'dart:convert';
import 'dart:ffi';

import 'package:data/data.dart' as data;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

void main() {
  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so.0'),
  );

  test('json export includes timeboxing fields when configured', () async {
    final db = data.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());

    await (db.update(db.appearanceConfigs)..where((t) => t.id.equals(1))).write(
      const data.AppearanceConfigsCompanion(
        timeboxingStartMinutes: Value(9 * 60),
        timeboxingLayout: Value(1),
        timeboxingWorkdayStartMinutes: Value(8 * 60),
        timeboxingWorkdayEndMinutes: Value(20 * 60),
      ),
    );

    final service = data.DataExportService(db);
    final jsonText = utf8.decode(await service.exportJsonBytes());
    final root = jsonDecode(jsonText);
    expect(root, isA<Map>());

    final schemaVersion = (root as Map)['schemaVersion'];
    expect(schemaVersion, data.DataExportService.exportSchemaVersion);

    final items = root['items'];
    expect(items, isA<Map>());
    final appearance = (items as Map)['appearance_config'];
    expect(appearance, isA<Map>());
    expect((appearance as Map)['timeboxing_start_minutes'], 9 * 60);
    expect(appearance['timeboxing_layout'], 1);
    expect(appearance['timeboxing_workday_start_minutes'], 8 * 60);
    expect(appearance['timeboxing_workday_end_minutes'], 20 * 60);
  });
}
