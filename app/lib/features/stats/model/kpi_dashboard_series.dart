import 'dart:math';

import 'package:domain/domain.dart' as domain;

class KpiDashboardPoint {
  const KpiDashboardPoint({
    required this.label,
    required this.sortKey,
    required this.sampleThreshold,
    required this.clarityOkCount,
    required this.clarityTotalCount,
    required this.ttfaSampleCount,
    required this.ttfaP50Ms,
    required this.ttfaP90Ms,
    required this.mainlineCompletedCount,
    required this.mainlineEligibleCount,
    required this.journalOpenedCount,
    required this.journalCompletedCount,
    required this.r7EligibleCount,
    required this.r7RetainedCount,
    required this.inboxPendingCount,
    required this.inboxCreatedCount,
    required this.inboxProcessedCount,
  });

  final String label;
  final int sortKey;

  final int sampleThreshold;

  final int clarityOkCount;
  final int clarityTotalCount;

  final int ttfaSampleCount;
  final int? ttfaP50Ms;
  final int? ttfaP90Ms;

  final int mainlineCompletedCount;
  final int mainlineEligibleCount;

  final int journalOpenedCount;
  final int journalCompletedCount;

  final int r7EligibleCount;
  final int r7RetainedCount;

  final int inboxPendingCount;
  final int inboxCreatedCount;
  final int inboxProcessedCount;
}

List<KpiDashboardPoint> buildKpiDaySeries(
  List<domain.KpiDailyRollup> rollups, {
  int limit = 14,
}) {
  final sorted = List<domain.KpiDailyRollup>.from(rollups)
    ..sort((a, b) => b.dayKey.compareTo(a.dayKey));
  return [
    for (final r in sorted.take(limit))
      KpiDashboardPoint(
        label: r.dayKey,
        sortKey: _sortKeyFromDayKey(r.dayKey),
        sampleThreshold: r.sampleThreshold,
        clarityOkCount: r.clarityOkCount,
        clarityTotalCount: r.clarityTotalCount,
        ttfaSampleCount: r.ttfaSampleCount,
        ttfaP50Ms: r.ttfaInsufficient ? null : r.ttfaP50Ms,
        ttfaP90Ms: r.ttfaInsufficient ? null : r.ttfaP90Ms,
        mainlineCompletedCount: r.mainlineInsufficient ? 0 : r.mainlineCompletedCount,
        mainlineEligibleCount: r.mainlineInsufficient ? 0 : 1,
        journalOpenedCount: r.journalOpenedCount,
        journalCompletedCount: r.journalCompletedCount,
        r7EligibleCount: (!r.r7Insufficient && r.r7Retained != null) ? 1 : 0,
        r7RetainedCount:
            (!r.r7Insufficient && r.r7Retained == true) ? 1 : 0,
        inboxPendingCount: r.inboxPendingCount,
        inboxCreatedCount: r.inboxCreatedCount,
        inboxProcessedCount: r.inboxProcessedCount,
      ),
  ];
}

List<KpiDashboardPoint> buildKpiWeekSeries(
  List<domain.KpiDailyRollup> rollups, {
  int limit = 12,
}) {
  final byWeekStart = <DateTime, List<domain.KpiDailyRollup>>{};
  for (final r in rollups) {
    final day = _parseDayKey(r.dayKey);
    final start = _weekStart(day);
    (byWeekStart[start] ??= []).add(r);
  }

  final points = <KpiDashboardPoint>[];
  for (final entry in byWeekStart.entries) {
    final start = entry.key;
    final items = entry.value;

    final threshold = items.map((r) => r.sampleThreshold).fold<int>(5, max);

    final clarityOk = items.fold<int>(0, (a, r) => a + r.clarityOkCount);
    final clarityTotal = items.fold<int>(0, (a, r) => a + r.clarityTotalCount);

    final ttfaSample = items.fold<int>(0, (a, r) => a + r.ttfaSampleCount);
    final ttfaP50 = _medianMs([
      for (final r in items)
        if (!r.ttfaInsufficient && r.ttfaP50Ms != null) r.ttfaP50Ms!,
    ]);
    final ttfaP90 = _medianMs([
      for (final r in items)
        if (!r.ttfaInsufficient && r.ttfaP90Ms != null) r.ttfaP90Ms!,
    ]);

    final mainlineCompleted =
        items.fold<int>(0, (a, r) => a + (r.mainlineInsufficient ? 0 : r.mainlineCompletedCount));
    final mainlineEligible = items.where((r) => !r.mainlineInsufficient).length;

    final journalOpened = items.fold<int>(0, (a, r) => a + r.journalOpenedCount);
    final journalCompleted =
        items.fold<int>(0, (a, r) => a + r.journalCompletedCount);

    final r7Eligible = items.where((r) => !r.r7Insufficient && r.r7Retained != null).length;
    final r7Retained = items.where((r) => !r.r7Insufficient && r.r7Retained == true).length;

    final pendingMedian = _medianInt([for (final r in items) r.inboxPendingCount]);
    final inboxCreated = items.fold<int>(0, (a, r) => a + r.inboxCreatedCount);
    final inboxProcessed =
        items.fold<int>(0, (a, r) => a + r.inboxProcessedCount);

    final end = start.add(const Duration(days: 6));
    points.add(
      KpiDashboardPoint(
        label:
            '${_formatDateYmd(start)}–${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}',
        sortKey: start.millisecondsSinceEpoch,
        sampleThreshold: threshold,
        clarityOkCount: clarityOk,
        clarityTotalCount: clarityTotal,
        ttfaSampleCount: ttfaSample,
        ttfaP50Ms: ttfaP50,
        ttfaP90Ms: ttfaP90,
        mainlineCompletedCount: mainlineCompleted,
        mainlineEligibleCount: mainlineEligible,
        journalOpenedCount: journalOpened,
        journalCompletedCount: journalCompleted,
        r7EligibleCount: r7Eligible,
        r7RetainedCount: r7Retained,
        inboxPendingCount: pendingMedian,
        inboxCreatedCount: inboxCreated,
        inboxProcessedCount: inboxProcessed,
      ),
    );
  }

  points.sort((a, b) => b.sortKey.compareTo(a.sortKey));
  return points.take(limit).toList(growable: false);
}

DateTime _parseDayKey(String dayKey) {
  final parts = dayKey.split('-');
  if (parts.length != 3) return DateTime(1970);
  final y = int.tryParse(parts[0]) ?? 1970;
  final m = int.tryParse(parts[1]) ?? 1;
  final d = int.tryParse(parts[2]) ?? 1;
  return DateTime(y, m, d);
}

DateTime _weekStart(DateTime localDay) {
  final dayStart = DateTime(localDay.year, localDay.month, localDay.day);
  return dayStart.subtract(Duration(days: dayStart.weekday - DateTime.monday));
}

String _formatDateYmd(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

int _sortKeyFromDayKey(String dayKey) => _parseDayKey(dayKey).millisecondsSinceEpoch;

int? _medianMs(List<int> values) {
  if (values.isEmpty) return null;
  final sorted = List<int>.from(values)..sort();
  return sorted[sorted.length ~/ 2];
}

int _medianInt(List<int> values) {
  if (values.isEmpty) return 0;
  final sorted = List<int>.from(values)..sort();
  return sorted[sorted.length ~/ 2];
}

