import 'package:domain/domain.dart' as domain;
import 'package:drift/drift.dart';

import '../db/app_database.dart';

class DriftKpiRepository implements domain.KpiRepository {
  DriftKpiRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> upsert(domain.KpiDailyRollup rollup) async {
    await _db
        .into(_db.kpiDailyRollups)
        .insert(_toCompanion(rollup), mode: InsertMode.insertOrReplace);
  }

  @override
  Future<List<domain.KpiDailyRollup>> getByDayKeyRange({
    required String startDayKeyInclusive,
    required String endDayKeyInclusive,
    String? segment,
  }) async {
    final query =
        (_db.select(_db.kpiDailyRollups)
            ..where((t) => t.dayKey.isBiggerOrEqualValue(startDayKeyInclusive))
            ..where((t) => t.dayKey.isSmallerOrEqualValue(endDayKeyInclusive)))
          ..orderBy([
            (t) => OrderingTerm(expression: t.dayKey, mode: OrderingMode.asc),
            (t) => OrderingTerm(expression: t.segment, mode: OrderingMode.asc),
          ]);
    if (segment != null) {
      query.where((t) => t.segment.equals(segment));
    }
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  KpiDailyRollupsCompanion _toCompanion(domain.KpiDailyRollup rollup) {
    return KpiDailyRollupsCompanion.insert(
      dayKey: rollup.dayKey,
      segment: rollup.segment,
      segmentStrategy: rollup.segmentStrategy,
      sampleThreshold: rollup.sampleThreshold,
      computedAtUtcMs: rollup.computedAtUtcMs,
      clarityOkCount: rollup.clarityOkCount,
      clarityTotalCount: rollup.clarityTotalCount,
      clarityInsufficient: rollup.clarityInsufficient,
      clarityInsufficientReason: Value(rollup.clarityInsufficientReason),
      clarityFailureBucketCountsJson: Value(
        rollup.clarityFailureBucketCountsJson,
      ),
      ttfaSampleCount: rollup.ttfaSampleCount,
      ttfaP50Ms: Value(rollup.ttfaP50Ms),
      ttfaP90Ms: Value(rollup.ttfaP90Ms),
      ttfaInsufficient: rollup.ttfaInsufficient,
      ttfaInsufficientReason: Value(rollup.ttfaInsufficientReason),
      mainlineCompletedCount: rollup.mainlineCompletedCount,
      mainlineInsufficient: rollup.mainlineInsufficient,
      mainlineInsufficientReason: Value(rollup.mainlineInsufficientReason),
      journalOpenedCount: rollup.journalOpenedCount,
      journalCompletedCount: rollup.journalCompletedCount,
      journalInsufficient: rollup.journalInsufficient,
      journalInsufficientReason: Value(rollup.journalInsufficientReason),
      activeDayCount: rollup.activeDayCount,
      r7Retained: Value(rollup.r7Retained),
      r7Insufficient: rollup.r7Insufficient,
      r7InsufficientReason: Value(rollup.r7InsufficientReason),
      inboxPendingCount: rollup.inboxPendingCount,
      inboxCreatedCount: rollup.inboxCreatedCount,
      inboxProcessedCount: rollup.inboxProcessedCount,
    );
  }

  domain.KpiDailyRollup _toDomain(KpiDailyRollupRow row) {
    return domain.KpiDailyRollup(
      dayKey: row.dayKey,
      segment: row.segment,
      segmentStrategy: row.segmentStrategy,
      sampleThreshold: row.sampleThreshold,
      computedAtUtcMs: row.computedAtUtcMs,
      clarityOkCount: row.clarityOkCount,
      clarityTotalCount: row.clarityTotalCount,
      clarityInsufficient: row.clarityInsufficient,
      clarityInsufficientReason: row.clarityInsufficientReason,
      clarityFailureBucketCountsJson: row.clarityFailureBucketCountsJson,
      ttfaSampleCount: row.ttfaSampleCount,
      ttfaP50Ms: row.ttfaP50Ms,
      ttfaP90Ms: row.ttfaP90Ms,
      ttfaInsufficient: row.ttfaInsufficient,
      ttfaInsufficientReason: row.ttfaInsufficientReason,
      mainlineCompletedCount: row.mainlineCompletedCount,
      mainlineInsufficient: row.mainlineInsufficient,
      mainlineInsufficientReason: row.mainlineInsufficientReason,
      journalOpenedCount: row.journalOpenedCount,
      journalCompletedCount: row.journalCompletedCount,
      journalInsufficient: row.journalInsufficient,
      journalInsufficientReason: row.journalInsufficientReason,
      activeDayCount: row.activeDayCount,
      r7Retained: row.r7Retained,
      r7Insufficient: row.r7Insufficient,
      r7InsufficientReason: row.r7InsufficientReason,
      inboxPendingCount: row.inboxPendingCount,
      inboxCreatedCount: row.inboxCreatedCount,
      inboxProcessedCount: row.inboxProcessedCount,
    );
  }
}
