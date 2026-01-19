import 'package:drift/drift.dart';

@DataClassName('NoteRow')
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  TextColumn get taskId => text().nullable()();
  IntColumn get kind => integer().withDefault(const Constant(0))();
  IntColumn get triageStatus => integer().withDefault(const Constant(2))();
  IntColumn get createdAtUtcMillis => integer()();
  IntColumn get updatedAtUtcMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
