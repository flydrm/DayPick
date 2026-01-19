import 'package:drift/drift.dart';

@DataClassName('TodayPlanItemRow')
class TodayPlanItems extends Table {
  /// Local day key, formatted as YYYY-MM-DD.
  TextColumn get dayKey => text()();

  TextColumn get taskId => text()();

  /// 0 = today, 1 = evening.
  IntColumn get segment => integer().withDefault(const Constant(0))();

  IntColumn get orderIndex => integer()();

  IntColumn get createdAtUtcMillis => integer()();
  IntColumn get updatedAtUtcMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {dayKey, taskId};
}
