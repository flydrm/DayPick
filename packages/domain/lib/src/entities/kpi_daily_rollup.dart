class KpiDailyRollup {
  const KpiDailyRollup({
    required this.dayKey,
    required this.segment,
    required this.segmentStrategy,
    required this.sampleThreshold,
    required this.computedAtUtcMs,
    required this.clarityOkCount,
    required this.clarityTotalCount,
    required this.clarityInsufficient,
    required this.clarityInsufficientReason,
    required this.clarityFailureBucketCountsJson,
    required this.ttfaSampleCount,
    required this.ttfaP50Ms,
    required this.ttfaP90Ms,
    required this.ttfaInsufficient,
    required this.ttfaInsufficientReason,
    required this.mainlineCompletedCount,
    required this.mainlineInsufficient,
    required this.mainlineInsufficientReason,
    required this.journalOpenedCount,
    required this.journalCompletedCount,
    required this.journalInsufficient,
    required this.journalInsufficientReason,
    required this.activeDayCount,
    required this.r7Retained,
    required this.r7Insufficient,
    required this.r7InsufficientReason,
    required this.inboxPendingCount,
    required this.inboxCreatedCount,
    required this.inboxProcessedCount,
  });

  final String dayKey; // YYYY-MM-DD (local day)
  final String segment; // all | new | returning
  final String segmentStrategy; // e.g. by_onboarding_done
  final int sampleThreshold;
  final int computedAtUtcMs;

  // KPI-1: 3-second clarity
  final int clarityOkCount;
  final int clarityTotalCount;
  final bool clarityInsufficient;
  final String?
  clarityInsufficientReason; // missing_event | sample_lt_threshold
  final String? clarityFailureBucketCountsJson;

  // KPI-2: TTFA percentiles
  final int ttfaSampleCount;
  final int? ttfaP50Ms;
  final int? ttfaP90Ms;
  final bool ttfaInsufficient;
  final String? ttfaInsufficientReason;

  // KPI-3: mainline journey a→c→d→e completion count
  final int mainlineCompletedCount;
  final bool mainlineInsufficient;
  final String? mainlineInsufficientReason;

  // KPI-4: bedtime review
  final int journalOpenedCount;
  final int journalCompletedCount;
  final bool journalInsufficient;
  final String? journalInsufficientReason;

  // KPI-5: retention
  final int activeDayCount;
  final bool? r7Retained;
  final bool r7Insufficient;
  final String? r7InsufficientReason;

  // Inbox Health
  final int inboxPendingCount;
  final int inboxCreatedCount;
  final int inboxProcessedCount;

  Map<String, Object?> toJson() {
    return {
      'day_key': dayKey,
      'segment': segment,
      'segment_strategy': segmentStrategy,
      'sample_threshold': sampleThreshold,
      'computed_at_utc_ms': computedAtUtcMs,
      'clarity_ok_count': clarityOkCount,
      'clarity_total_count': clarityTotalCount,
      'clarity_insufficient': clarityInsufficient,
      'clarity_insufficient_reason': clarityInsufficientReason,
      'clarity_failure_bucket_counts_json': clarityFailureBucketCountsJson,
      'ttfa_sample_count': ttfaSampleCount,
      'ttfa_p50_ms': ttfaP50Ms,
      'ttfa_p90_ms': ttfaP90Ms,
      'ttfa_insufficient': ttfaInsufficient,
      'ttfa_insufficient_reason': ttfaInsufficientReason,
      'mainline_completed_count': mainlineCompletedCount,
      'mainline_insufficient': mainlineInsufficient,
      'mainline_insufficient_reason': mainlineInsufficientReason,
      'journal_opened_count': journalOpenedCount,
      'journal_completed_count': journalCompletedCount,
      'journal_insufficient': journalInsufficient,
      'journal_insufficient_reason': journalInsufficientReason,
      'active_day_count': activeDayCount,
      'r7_retained': r7Retained,
      'r7_insufficient': r7Insufficient,
      'r7_insufficient_reason': r7InsufficientReason,
      'inbox_pending_count': inboxPendingCount,
      'inbox_created_count': inboxCreatedCount,
      'inbox_processed_count': inboxProcessedCount,
    };
  }
}
