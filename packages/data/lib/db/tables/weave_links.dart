import 'package:drift/drift.dart';

@DataClassName('WeaveLinkRow')
class WeaveLinks extends Table {
  TextColumn get id => text()();
  IntColumn get sourceType => integer()();
  TextColumn get sourceId => text()();
  TextColumn get targetNoteId => text()();
  IntColumn get mode => integer().withDefault(const Constant(0))();
  IntColumn get createdAtUtcMillis => integer()();
  IntColumn get updatedAtUtcMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
