import 'package:drift/drift.dart';

@DataClassName('TaskRow')
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  IntColumn get status => integer()();
  IntColumn get priority => integer()();
  IntColumn get dueAtUtcMillis => integer().nullable()();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  IntColumn get triageStatus => integer().withDefault(const Constant(2))();
  IntColumn get estimatedPomodoros => integer().nullable()();
  IntColumn get createdAtUtcMillis => integer()();
  IntColumn get updatedAtUtcMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
