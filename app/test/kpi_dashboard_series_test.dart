import 'package:daypick/features/stats/model/kpi_dashboard_series.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter_test/flutter_test.dart';

void main() {
  domain.KpiDailyRollup rollup({
    required String dayKey,
    String segment = 'all',
    String segmentStrategy = 'by_onboarding_done',
    int sampleThreshold = 5,
    int computedAtUtcMs = 0,
    int clarityOkCount = 0,
    int clarityTotalCount = 0,
    bool clarityInsufficient = false,
    String? clarityInsufficientReason,
    String? clarityFailureBucketCountsJson,
    int ttfaSampleCount = 0,
    int? ttfaP50Ms,
    int? ttfaP90Ms,
    bool ttfaInsufficient = false,
    String? ttfaInsufficientReason,
    int mainlineCompletedCount = 0,
    bool mainlineInsufficient = false,
    String? mainlineInsufficientReason,
    int journalOpenedCount = 0,
    int journalCompletedCount = 0,
    bool journalInsufficient = false,
    String? journalInsufficientReason,
    int activeDayCount = 0,
    bool? r7Retained,
    bool r7Insufficient = false,
    String? r7InsufficientReason,
    int inboxPendingCount = 0,
    int inboxCreatedCount = 0,
    int inboxProcessedCount = 0,
  }) {
    return domain.KpiDailyRollup(
      dayKey: dayKey,
      segment: segment,
      segmentStrategy: segmentStrategy,
      sampleThreshold: sampleThreshold,
      computedAtUtcMs: computedAtUtcMs,
      clarityOkCount: clarityOkCount,
      clarityTotalCount: clarityTotalCount,
      clarityInsufficient: clarityInsufficient,
      clarityInsufficientReason: clarityInsufficientReason,
      clarityFailureBucketCountsJson: clarityFailureBucketCountsJson,
      ttfaSampleCount: ttfaSampleCount,
      ttfaP50Ms: ttfaP50Ms,
      ttfaP90Ms: ttfaP90Ms,
      ttfaInsufficient: ttfaInsufficient,
      ttfaInsufficientReason: ttfaInsufficientReason,
      mainlineCompletedCount: mainlineCompletedCount,
      mainlineInsufficient: mainlineInsufficient,
      mainlineInsufficientReason: mainlineInsufficientReason,
      journalOpenedCount: journalOpenedCount,
      journalCompletedCount: journalCompletedCount,
      journalInsufficient: journalInsufficient,
      journalInsufficientReason: journalInsufficientReason,
      activeDayCount: activeDayCount,
      r7Retained: r7Retained,
      r7Insufficient: r7Insufficient,
      r7InsufficientReason: r7InsufficientReason,
      inboxPendingCount: inboxPendingCount,
      inboxCreatedCount: inboxCreatedCount,
      inboxProcessedCount: inboxProcessedCount,
    );
  }

  test('buildKpiDaySeries sorts by newest day_key and maps insufficiency', () {
    final rollups = [
      rollup(
        dayKey: '2026-01-01',
        ttfaP50Ms: 100,
        ttfaP90Ms: 200,
        ttfaInsufficient: false,
        mainlineCompletedCount: 1,
        mainlineInsufficient: false,
        r7Insufficient: false,
        r7Retained: false,
      ),
      rollup(
        dayKey: '2026-01-03',
        ttfaP50Ms: 999,
        ttfaP90Ms: 999,
        ttfaInsufficient: true,
        mainlineCompletedCount: 5,
        mainlineInsufficient: true,
        r7Insufficient: true,
        r7Retained: null,
      ),
      rollup(
        dayKey: '2026-01-02',
        ttfaP50Ms: 300,
        ttfaP90Ms: 400,
        ttfaInsufficient: false,
        mainlineCompletedCount: 2,
        mainlineInsufficient: false,
        r7Insufficient: false,
        r7Retained: true,
      ),
    ];

    final series = buildKpiDaySeries(rollups, limit: 14);
    expect(series.map((p) => p.label).toList(), [
      '2026-01-03',
      '2026-01-02',
      '2026-01-01',
    ]);

    final newest = series.first;
    expect(newest.ttfaP50Ms, isNull);
    expect(newest.ttfaP90Ms, isNull);
    expect(newest.mainlineEligibleCount, 0);
    expect(newest.mainlineCompletedCount, 0);

    final mid = series[1];
    expect(mid.r7EligibleCount, 1);
    expect(mid.r7RetainedCount, 1);

    final oldest = series[2];
    expect(oldest.r7EligibleCount, 1);
    expect(oldest.r7RetainedCount, 0);
  });

  test('buildKpiWeekSeries groups by Monday-start week and aggregates', () {
    final rollups = [
      rollup(
        dayKey: '2026-01-05', // Monday
        sampleThreshold: 5,
        clarityOkCount: 1,
        clarityTotalCount: 2,
        ttfaSampleCount: 1,
        ttfaP50Ms: 1000,
        ttfaP90Ms: 4000,
        mainlineCompletedCount: 2,
        mainlineInsufficient: false,
        journalOpenedCount: 1,
        journalCompletedCount: 0,
        r7Insufficient: false,
        r7Retained: true,
        inboxPendingCount: 1,
        inboxCreatedCount: 1,
        inboxProcessedCount: 0,
      ),
      rollup(
        dayKey: '2026-01-06',
        sampleThreshold: 7,
        clarityOkCount: 2,
        clarityTotalCount: 2,
        ttfaSampleCount: 2,
        ttfaP50Ms: 1500,
        ttfaP90Ms: 5000,
        mainlineCompletedCount: 3,
        mainlineInsufficient: false,
        journalOpenedCount: 1,
        journalCompletedCount: 1,
        r7Insufficient: false,
        r7Retained: false,
        inboxPendingCount: 9,
        inboxCreatedCount: 2,
        inboxProcessedCount: 1,
      ),
      rollup(
        dayKey: '2026-01-07',
        sampleThreshold: 6,
        clarityOkCount: 0,
        clarityTotalCount: 1,
        ttfaSampleCount: 3,
        ttfaP50Ms: 3000,
        ttfaP90Ms: 6000,
        mainlineCompletedCount: 4,
        mainlineInsufficient: true,
        journalOpenedCount: 0,
        journalCompletedCount: 0,
        r7Insufficient: true,
        r7Retained: null,
        inboxPendingCount: 5,
        inboxCreatedCount: 3,
        inboxProcessedCount: 2,
      ),
      rollup(
        dayKey: '2026-01-04', // Sunday of previous week (2025-12-29–2026-01-04)
        sampleThreshold: 5,
        clarityOkCount: 10,
        clarityTotalCount: 10,
      ),
    ];

    final series = buildKpiWeekSeries(rollups, limit: 12);
    expect(series, hasLength(2));

    final week = series.first;
    expect(week.label, '2026-01-05–01-11');
    expect(week.sampleThreshold, 7);

    expect(week.clarityOkCount, 3);
    expect(week.clarityTotalCount, 5);

    expect(week.ttfaSampleCount, 6);
    expect(week.ttfaP50Ms, 1500);
    expect(week.ttfaP90Ms, 5000);

    expect(week.mainlineCompletedCount, 5);
    expect(week.mainlineEligibleCount, 2);

    expect(week.journalOpenedCount, 2);
    expect(week.journalCompletedCount, 1);

    expect(week.r7EligibleCount, 2);
    expect(week.r7RetainedCount, 1);

    expect(week.inboxPendingCount, 5);
    expect(week.inboxCreatedCount, 6);
    expect(week.inboxProcessedCount, 3);
  });
}
