import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:domain/domain.dart' as domain;

import '../db/app_database.dart';
import '../repositories/drift_kpi_repository.dart';
import '../repositories/drift_local_events_repository.dart';

class KpiAggregationService {
  KpiAggregationService(
    this._db, {
    this.sampleThreshold = defaultSampleThreshold,
    this.segmentStrategy = defaultSegmentStrategy,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    if (!supportedSegmentStrategies.contains(segmentStrategy)) {
      throw ArgumentError.value(
        segmentStrategy,
        'segmentStrategy',
        'Unsupported. Supported: ${supportedSegmentStrategies.join(', ')}',
      );
    }
  }

  static const int defaultSampleThreshold = 5;
  static const String defaultSegmentStrategy = 'by_onboarding_done';
  static const String segmentStrategyNone = 'none';
  static const Set<String> supportedSegmentStrategies = {
    defaultSegmentStrategy,
    segmentStrategyNone,
  };

  final AppDatabase _db;
  final DateTime Function() _now;

  final int sampleThreshold;
  final String segmentStrategy;

  Future<void> aggregateRecentDays({int days = 2}) async {
    if (days <= 0) return;
    final now = _now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final daysToAggregate = <DateTime>{};
    for (var i = 0; i < days; i += 1) {
      daysToAggregate.add(todayStart.subtract(Duration(days: i)));
    }

    // Backfill cohort day that just became eligible for R7 (day+7 reached).
    final r7CohortDay = todayStart.subtract(const Duration(days: 8));
    if (!daysToAggregate.contains(r7CohortDay)) {
      final r7CohortEnd = r7CohortDay.add(const Duration(days: 1));
      final localEvents = DriftLocalEventsRepository(_db);
      final hadLaunchOnCohortDay = await localEvents.getBetween(
        minOccurredAtUtcMsInclusive: r7CohortDay.toUtc().millisecondsSinceEpoch,
        maxOccurredAtUtcMsExclusive: r7CohortEnd.toUtc().millisecondsSinceEpoch,
        eventNames: const [domain.LocalEventNames.appLaunchStarted],
        limit: 1,
      );
      if (hadLaunchOnCohortDay.isNotEmpty) {
        daysToAggregate.add(r7CohortDay);
      }
    }

    final ordered = daysToAggregate.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final day in ordered) {
      await aggregateDay(dayLocal: day);
    }
  }

  Future<void> aggregateDay({required DateTime dayLocal}) async {
    final dayStart = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final dayKey = _dayKey(dayStart);

    final localEvents = DriftLocalEventsRepository(_db);
    final kpis = DriftKpiRepository(_db);

    final baseEvents = await localEvents.getBetween(
      minOccurredAtUtcMsInclusive: dayStart.toUtc().millisecondsSinceEpoch,
      maxOccurredAtUtcMsExclusive: dayEnd.toUtc().millisecondsSinceEpoch,
      eventNames: const [
        domain.LocalEventNames.appLaunchStarted,
        domain.LocalEventNames.todayOpened,
        domain.LocalEventNames.todayClarityResult,
        domain.LocalEventNames.primaryActionInvoked,
        domain.LocalEventNames.captureSubmitted,
        domain.LocalEventNames.openInbox,
        domain.LocalEventNames.inboxItemCreated,
        domain.LocalEventNames.inboxItemProcessed,
        domain.LocalEventNames.todayPlanOpened,
        domain.LocalEventNames.journalOpened,
        domain.LocalEventNames.journalCompleted,
      ],
    );

    final segment = await _resolveSegment();
    final segments = <String>{
      'all',
      if (segment.isNotEmpty) segment,
    }.toList(growable: false);

    final r7 = await _computeR7Retention(cohortDayStartLocal: dayStart);
    final snapshotCount = await _readInboxDailySnapshotCount(dayKey: dayKey);
    final nowLocal = _now();
    final inboxPendingCount = snapshotCount ?? await _countInboxPendingItems();
    if (snapshotCount == null && !nowLocal.isBefore(dayEnd)) {
      await _writeInboxDailySnapshotIfAbsent(
        dayStartLocal: dayStart,
        dayEndLocal: dayEnd,
        dayKey: dayKey,
        inboxPendingCount: inboxPendingCount,
        baseEvents: baseEvents,
      );
    }

    for (final s in segments) {
      final rollup = await _computeRollupForDay(
        dayKey: dayKey,
        segment: s,
        segmentStrategy: segmentStrategy,
        sampleThreshold: sampleThreshold,
        computedAtUtcMs: nowLocal.toUtc().millisecondsSinceEpoch,
        events: baseEvents,
        inboxPendingCount: inboxPendingCount,
        r7: r7,
      );
      await kpis.upsert(rollup);
    }
  }

  Future<int?> _readInboxDailySnapshotCount({required String dayKey}) async {
    final id = 'inbox_daily_snapshot:$dayKey';
    final row =
        await (_db.select(_db.localEvents)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
    if (row == null) return null;
    try {
      final decoded = jsonDecode(row.metaJson);
      if (decoded is Map) {
        final v = decoded['inbox_pending_count'];
        if (v is int) return v;
        if (v is num) return v.toInt();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeInboxDailySnapshotIfAbsent({
    required DateTime dayStartLocal,
    required DateTime dayEndLocal,
    required String dayKey,
    required int inboxPendingCount,
    required List<domain.LocalEvent> baseEvents,
  }) async {
    final appVersion = baseEvents.isEmpty ? 'unknown' : baseEvents.first.appVersion;
    final featureFlags = baseEvents.isEmpty ? '[]' : baseEvents.first.featureFlags;

    await _db
        .into(_db.localEvents)
        .insert(
          LocalEventsCompanion.insert(
            id: 'inbox_daily_snapshot:$dayKey',
            eventName: domain.LocalEventNames.inboxDailySnapshot,
            occurredAtUtcMs: dayEndLocal.toUtc().millisecondsSinceEpoch - 1,
            appVersion: appVersion,
            featureFlags: featureFlags,
            metaJson: jsonEncode({
              'day_key': dayKey,
              'inbox_pending_count': inboxPendingCount,
            }),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<domain.KpiDailyRollup> _computeRollupForDay({
    required String dayKey,
    required String segment,
    required String segmentStrategy,
    required int sampleThreshold,
    required int computedAtUtcMs,
    required List<domain.LocalEvent> events,
    required int inboxPendingCount,
    required _R7Result r7,
  }) async {
    final clarityEvents = [
      for (final e in events)
        if (e.eventName == domain.LocalEventNames.todayClarityResult) e,
    ];
    final clarityTotalCount = clarityEvents.length;
    final clarityOkCount = clarityEvents
        .where((e) => _metaString(e, 'result') == 'ok')
        .length;
    final clarityFailureBuckets = <String, int>{};
    for (final e in clarityEvents) {
      final bucket = _metaString(e, 'failure_bucket');
      if (bucket == null || bucket.isEmpty) continue;
      clarityFailureBuckets[bucket] = (clarityFailureBuckets[bucket] ?? 0) + 1;
    }
    final clarityInsufficientReason = _insufficientReason(
      sampleCount: clarityTotalCount,
      threshold: sampleThreshold,
    );
    final clarityInsufficient = clarityInsufficientReason != null;

    final ttfaValues = <int>[];
    for (final e in events) {
      if (e.eventName != domain.LocalEventNames.primaryActionInvoked) continue;
      final elapsed = _metaInt(e, 'elapsed_ms');
      if (elapsed == null) continue;
      if (elapsed < 0) continue;
      ttfaValues.add(elapsed);
    }
    final ttfaSampleCount = ttfaValues.length;
    final ttfaInsufficientReason = _insufficientReason(
      sampleCount: ttfaSampleCount,
      threshold: sampleThreshold,
    );
    final ttfaInsufficient = ttfaInsufficientReason != null;
    final ttfaP50Ms = ttfaInsufficient
        ? null
        : _nearestRankPercentile(ttfaValues, 0.50);
    final ttfaP90Ms = ttfaInsufficient
        ? null
        : _nearestRankPercentile(ttfaValues, 0.90);

    final todayOpenedCount = events
        .where((e) => e.eventName == domain.LocalEventNames.todayOpened)
        .length;
    final hasA = todayOpenedCount > 0;
    final hasC =
        events.any((e) => e.eventName == domain.LocalEventNames.openInbox) ||
        events.any((e) => e.eventName == domain.LocalEventNames.inboxItemProcessed) ||
        events.any(
          (e) =>
              e.eventName == domain.LocalEventNames.primaryActionInvoked &&
              _metaString(e, 'action') == 'open_inbox',
        );
    final hasD =
        events.any((e) => e.eventName == domain.LocalEventNames.captureSubmitted) ||
        events.any(
          (e) =>
              e.eventName == domain.LocalEventNames.primaryActionInvoked &&
              _metaString(e, 'action') == 'capture_submit',
        );
    final hasE =
        events.any((e) => e.eventName == domain.LocalEventNames.todayPlanOpened) ||
        events.any(
          (e) =>
              e.eventName == domain.LocalEventNames.primaryActionInvoked &&
              _metaString(e, 'action') == 'open_today_plan',
        );
    final mainlineCompletedCount = hasA && hasC && hasD && hasE ? 1 : 0;
    final mainlineInsufficient = !hasA;
    final mainlineInsufficientReason = mainlineInsufficient
        ? 'missing_event'
        : null;

    final journalOpenedCount = events
        .where((e) => e.eventName == domain.LocalEventNames.journalOpened)
        .length;
    final journalCompletedCount = events
        .where((e) => e.eventName == domain.LocalEventNames.journalCompleted)
        .length;
    final journalInsufficient =
        journalOpenedCount == 0 && journalCompletedCount == 0;
    final journalInsufficientReason = journalInsufficient
        ? 'missing_event'
        : null;

    final launchCount = events
        .where((e) => e.eventName == domain.LocalEventNames.appLaunchStarted)
        .length;
    final activeDayCount = launchCount > 0 ? 1 : 0;
    final inboxCreatedCount = events
        .where((e) => e.eventName == domain.LocalEventNames.inboxItemCreated)
        .length;
    final inboxProcessedCount = events
        .where((e) => e.eventName == domain.LocalEventNames.inboxItemProcessed)
        .length;

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
      clarityFailureBucketCountsJson: clarityFailureBuckets.isEmpty
          ? null
          : jsonEncode(clarityFailureBuckets),
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
      r7Retained: r7.retained,
      r7Insufficient: r7.insufficient,
      r7InsufficientReason: r7.insufficientReason,
      inboxPendingCount: inboxPendingCount,
      inboxCreatedCount: inboxCreatedCount,
      inboxProcessedCount: inboxProcessedCount,
    );
  }

  Future<_R7Result> _computeR7Retention({
    required DateTime cohortDayStartLocal,
  }) async {
    final today = _now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final eligibleAtStart = cohortDayStartLocal.add(const Duration(days: 8));
    if (todayStart.isBefore(eligibleAtStart)) {
      return const _R7Result(
        retained: null,
        insufficient: true,
        insufficientReason: 'not_yet_eligible',
      );
    }

    final targetStart = cohortDayStartLocal.add(const Duration(days: 7));
    final targetEnd = targetStart.add(const Duration(days: 1));
    final localEvents = DriftLocalEventsRepository(_db);
    final events = await localEvents.getBetween(
      minOccurredAtUtcMsInclusive: targetStart.toUtc().millisecondsSinceEpoch,
      maxOccurredAtUtcMsExclusive: targetEnd.toUtc().millisecondsSinceEpoch,
      eventNames: const [domain.LocalEventNames.appLaunchStarted],
      limit: 1,
    );
    return _R7Result(
      retained: events.isNotEmpty,
      insufficient: false,
      insufficientReason: null,
    );
  }

  Future<String> _resolveSegment() async {
    if (segmentStrategy == segmentStrategyNone) return '';
    if (segmentStrategy != defaultSegmentStrategy) return '';
    final row = await (_db.select(
      _db.appearanceConfigs,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    final onboardingDone = row?.onboardingDone ?? false;
    return onboardingDone ? 'returning' : 'new';
  }

  Future<int> _countInboxPendingItems() async {
    const inboxCode = 0;

    final taskCountExp = _db.tasks.id.count();
    final taskRow =
        await (_db.selectOnly(_db.tasks)
              ..addColumns([taskCountExp])
              ..where(_db.tasks.triageStatus.equals(inboxCode)))
            .getSingle();
    final taskCount = taskRow.read(taskCountExp) ?? 0;

    final noteCountExp = _db.notes.id.count();
    final noteRow =
        await (_db.selectOnly(_db.notes)
              ..addColumns([noteCountExp])
              ..where(_db.notes.triageStatus.equals(inboxCode)))
            .getSingle();
    final noteCount = noteRow.read(noteCountExp) ?? 0;

    return taskCount + noteCount;
  }

  static String _dayKey(DateTime day) {
    final local = DateTime(day.year, day.month, day.day);
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  static String? _metaString(domain.LocalEvent event, String key) {
    final v = event.metaJson[key];
    return v is String ? v : null;
  }

  static int? _metaInt(domain.LocalEvent event, String key) {
    final v = event.metaJson[key];
    return v is int ? v : null;
  }

  static String? _insufficientReason({
    required int sampleCount,
    required int threshold,
  }) {
    if (sampleCount <= 0) return 'missing_event';
    if (sampleCount < threshold) return 'sample_lt_threshold';
    return null;
  }

  static int _nearestRankPercentile(List<int> values, double p) {
    final sorted = List<int>.from(values)..sort();
    final n = sorted.length;
    if (n == 0) return 0;
    final index = max(0, min(n - 1, (p * n).ceil() - 1));
    return sorted[index];
  }
}

class _R7Result {
  const _R7Result({
    required this.retained,
    required this.insufficient,
    required this.insufficientReason,
  });

  final bool? retained;
  final bool insufficient;
  final String? insufficientReason;
}
