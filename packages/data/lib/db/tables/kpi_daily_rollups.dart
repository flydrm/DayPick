import 'package:drift/drift.dart';

@DataClassName('KpiDailyRollupRow')
class KpiDailyRollups extends Table {
  TextColumn get dayKey => text()(); // YYYY-MM-DD (local day)
  TextColumn get segment => text()(); // all | new | returning
  TextColumn get segmentStrategy => text()(); // e.g. by_onboarding_done
  IntColumn get sampleThreshold => integer()();
  IntColumn get computedAtUtcMs => integer()();

  // KPI-1: 3-second clarity
  IntColumn get clarityOkCount => integer()();
  IntColumn get clarityTotalCount => integer()();
  BoolColumn get clarityInsufficient => boolean()();
  TextColumn get clarityInsufficientReason => text().nullable()();
  TextColumn get clarityFailureBucketCountsJson => text().nullable()();

  // KPI-2: TTFA percentiles
  IntColumn get ttfaSampleCount => integer()();
  IntColumn get ttfaP50Ms => integer().nullable()();
  IntColumn get ttfaP90Ms => integer().nullable()();
  BoolColumn get ttfaInsufficient => boolean()();
  TextColumn get ttfaInsufficientReason => text().nullable()();

  // KPI-3: mainline journey completion count
  IntColumn get mainlineCompletedCount => integer()();
  BoolColumn get mainlineInsufficient => boolean()();
  TextColumn get mainlineInsufficientReason => text().nullable()();

  // KPI-4: bedtime review
  IntColumn get journalOpenedCount => integer()();
  IntColumn get journalCompletedCount => integer()();
  BoolColumn get journalInsufficient => boolean()();
  TextColumn get journalInsufficientReason => text().nullable()();

  // KPI-5: retention
  IntColumn get activeDayCount => integer()();
  BoolColumn get r7Retained => boolean().nullable()();
  BoolColumn get r7Insufficient => boolean()();
  TextColumn get r7InsufficientReason => text().nullable()();

  // Inbox Health
  IntColumn get inboxPendingCount => integer()();
  IntColumn get inboxCreatedCount => integer()();
  IntColumn get inboxProcessedCount => integer()();

  @override
  Set<Column<Object>> get primaryKey => {dayKey, segment};
}
