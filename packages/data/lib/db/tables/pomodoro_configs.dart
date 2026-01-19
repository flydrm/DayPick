import 'package:drift/drift.dart';

@DataClassName('PomodoroConfigRow')
class PomodoroConfigs extends Table {
  IntColumn get id => integer()();
  IntColumn get workDurationMinutes =>
      integer().withDefault(const Constant(25))();
  IntColumn get shortBreakMinutes => integer().withDefault(const Constant(5))();
  IntColumn get longBreakMinutes => integer().withDefault(const Constant(15))();
  IntColumn get longBreakEvery => integer().withDefault(const Constant(4))();
  IntColumn get dailyBudgetPomodoros =>
      integer().withDefault(const Constant(8))();
  BoolColumn get autoStartBreak =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get autoStartFocus =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get notificationSound =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get notificationVibration =>
      boolean().withDefault(const Constant(false))();
  IntColumn get updatedAtUtcMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
