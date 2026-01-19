import 'dart:ffi';
import 'dart:convert';

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

  test(
    'markdown export strips internal [[route:...]] tokens from note bodies',
    () async {
      final db = data.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async => db.close());

      final nowUtc = DateTime(2026, 1, 1, 0, 0).toUtc().millisecondsSinceEpoch;
      await db
          .into(db.notes)
          .insert(
            data.NotesCompanion.insert(
              id: 'n-1',
              title: 'AI 问答存档',
              body: const Value(
                '引用：\n- [1] 任务 · Buy milk [[route:/tasks/t-1]]\n',
              ),
              tagsJson: const Value('["ai","qa"]'),
              kind: const Value(0),
              triageStatus: const Value(2),
              createdAtUtcMillis: nowUtc,
              updatedAtUtcMillis: nowUtc,
            ),
          );

      final service = data.DataExportService(db);
      final bytes = await service.exportNotesMarkdownBytes();
      final text = utf8.decode(bytes);

      expect(text, isNot(contains('[[route:')));
      expect(text, contains('Buy milk'));
    },
  );
}
