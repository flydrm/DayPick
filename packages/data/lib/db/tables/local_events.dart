import 'package:drift/drift.dart';

@DataClassName('LocalEventRow')
class LocalEvents extends Table {
  TextColumn get id => text()();
  TextColumn get eventName => text()();
  IntColumn get occurredAtUtcMs => integer()();
  TextColumn get appVersion => text()();
  TextColumn get featureFlags => text()();
  TextColumn get metaJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
