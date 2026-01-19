import 'package:drift/drift.dart';

@DataClassName('PomodoroSessionRow')
class PomodoroSessions extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  IntColumn get startAtUtcMillis => integer()();
  IntColumn get endAtUtcMillis => integer()();
  BoolColumn get isDraft => boolean().withDefault(const Constant(false))();
  TextColumn get progressNote => text().nullable()();
  IntColumn get createdAtUtcMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
