import 'package:drift/drift.dart';

@DataClassName('AppearanceConfigRow')
class AppearanceConfigs extends Table {
  IntColumn get id => integer()();
  IntColumn get themeMode => integer().withDefault(const Constant(0))();
  IntColumn get density => integer().withDefault(const Constant(0))();
  IntColumn get accent => integer().withDefault(const Constant(0))();
  IntColumn get defaultTab => integer().withDefault(const Constant(2))();
  BoolColumn get onboardingDone =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get statsEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get todayModulesJson => text().withDefault(
    const Constant(
      '["nextStep","todayPlan","weave","budget","focus","shortcuts","yesterdayReview"]',
    ),
  )();
  IntColumn get timeboxingStartMinutes => integer().nullable()();
  IntColumn get timeboxingLayout => integer().withDefault(const Constant(0))();
  IntColumn get timeboxingWorkdayStartMinutes =>
      integer().withDefault(const Constant(7 * 60))();
  IntColumn get timeboxingWorkdayEndMinutes =>
      integer().withDefault(const Constant(21 * 60))();
  IntColumn get inboxTypeFilter => integer().withDefault(const Constant(0))();
  BoolColumn get inboxTodayOnly =>
      boolean().withDefault(const Constant(false))();
  IntColumn get updatedAtUtcMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
