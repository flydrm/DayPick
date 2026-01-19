import 'package:drift/drift.dart';

@DataClassName('ActivePomodoroRow')
class ActivePomodoros extends Table {
  IntColumn get id => integer()();
  TextColumn get taskId => text()();
  IntColumn get phase => integer().withDefault(const Constant(0))();
  IntColumn get status => integer()();
  IntColumn get startAtUtcMillis => integer()();
  IntColumn get endAtUtcMillis => integer().nullable()();
  IntColumn get remainingMs => integer().nullable()();
  TextColumn get focusNote => text().nullable()();
  IntColumn get updatedAtUtcMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
