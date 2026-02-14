import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';

class KpiMetricsExportService {
  KpiMetricsExportService(this._db);

  static const int schemaVersion = 1;

  final AppDatabase _db;

  Future<Uint8List> exportJsonBytes() async {
    final exportedAtUtcMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    final rollups =
        await (_db.select(_db.kpiDailyRollups)..orderBy([
              (t) => OrderingTerm(expression: t.dayKey, mode: OrderingMode.asc),
              (t) =>
                  OrderingTerm(expression: t.segment, mode: OrderingMode.asc),
            ]))
            .get();

    final obj = <String, Object?>{
      'schema_version': schemaVersion,
      'exported_at_utc_ms': exportedAtUtcMs,
      'items': {
        'kpi_daily_rollups': [
          for (final r in rollups)
            {
              'day_key': r.dayKey,
              'segment': r.segment,
              'segment_strategy': r.segmentStrategy,
              'sample_threshold': r.sampleThreshold,
              'computed_at_utc_ms': r.computedAtUtcMs,
              'clarity_ok_count': r.clarityOkCount,
              'clarity_total_count': r.clarityTotalCount,
              'clarity_insufficient': r.clarityInsufficient,
              'clarity_insufficient_reason': r.clarityInsufficientReason,
              'clarity_failure_bucket_counts_json':
                  r.clarityFailureBucketCountsJson,
              'ttfa_sample_count': r.ttfaSampleCount,
              'ttfa_p50_ms': r.ttfaP50Ms,
              'ttfa_p90_ms': r.ttfaP90Ms,
              'ttfa_insufficient': r.ttfaInsufficient,
              'ttfa_insufficient_reason': r.ttfaInsufficientReason,
              'mainline_completed_count': r.mainlineCompletedCount,
              'mainline_insufficient': r.mainlineInsufficient,
              'mainline_insufficient_reason': r.mainlineInsufficientReason,
              'journal_opened_count': r.journalOpenedCount,
              'journal_completed_count': r.journalCompletedCount,
              'journal_insufficient': r.journalInsufficient,
              'journal_insufficient_reason': r.journalInsufficientReason,
              'active_day_count': r.activeDayCount,
              'r7_retained': r.r7Retained,
              'r7_insufficient': r.r7Insufficient,
              'r7_insufficient_reason': r.r7InsufficientReason,
              'inbox_pending_count': r.inboxPendingCount,
              'inbox_created_count': r.inboxCreatedCount,
              'inbox_processed_count': r.inboxProcessedCount,
            },
        ],
      },
    };

    final jsonText = const JsonEncoder.withIndent('  ').convert(obj);
    return Uint8List.fromList(utf8.encode(jsonText));
  }
}
