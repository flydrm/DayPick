import 'package:drift/drift.dart';

@DataClassName('FeatureFlagRow')
class FeatureFlags extends Table {
  TextColumn get key => text()();
  TextColumn get owner => text()();
  IntColumn get expiryAtUtcMillis => integer()();
  BoolColumn get defaultValue => boolean()();
  BoolColumn get killSwitch => boolean().withDefault(const Constant(false))();
  BoolColumn get overrideValue => boolean().nullable()();
  IntColumn get updatedAtUtcMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
