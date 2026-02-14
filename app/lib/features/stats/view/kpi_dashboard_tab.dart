import 'package:data/data.dart' as data;
import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/local_events/local_events_provider.dart';
import '../../../core/providers/app_providers.dart';
import '../../../ui/kit/dp_empty_state.dart';
import '../../../ui/kit/dp_inline_notice.dart';
import '../../../ui/kit/dp_section_card.dart';
import '../../../ui/kit/dp_spinner.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../model/kpi_dashboard_series.dart';

enum _KpiViewMode { day, week }

class KpiDashboardTab extends ConsumerStatefulWidget {
  const KpiDashboardTab({super.key});

  @override
  ConsumerState<KpiDashboardTab> createState() => _KpiDashboardTabState();
}

class _KpiDashboardTabState extends ConsumerState<KpiDashboardTab> {
  _KpiViewMode _mode = _KpiViewMode.day;
  bool _recomputing = false;
  bool _exporting = false;
  String? _actionError;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final rollupsAsync = ref.watch(_kpiRollupsProvider);

    return Column(
      children: [
        Padding(
          padding: DpInsets.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ShadAlert(
                icon: Icon(Icons.insights_outlined),
                title: Text('本地指标（content-free）'),
                description: Text('仅展示聚合/计数；样本不足时显示“—”，避免误读。'),
              ),
              const SizedBox(height: DpSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _ToggleChip(
                      label: '按天',
                      selected: _mode == _KpiViewMode.day,
                      onTap: () => setState(() => _mode = _KpiViewMode.day),
                    ),
                  ),
                  const SizedBox(width: DpSpacing.sm),
                  Expanded(
                    child: _ToggleChip(
                      label: '按周',
                      selected: _mode == _KpiViewMode.week,
                      onTap: () => setState(() => _mode = _KpiViewMode.week),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DpSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: ShadButton.outline(
                      onPressed: _recomputing ? null : _recomputeLast30Days,
                      leading: _recomputing
                          ? const DpSpinner(size: 16, strokeWidth: 2)
                          : const Icon(Icons.refresh, size: 16),
                      child: const Text('补齐最近 30 天'),
                    ),
                  ),
                  const SizedBox(width: DpSpacing.sm),
                  Expanded(
                    child: ShadButton(
                      onPressed: _exporting ? null : _exportMetricsJson,
                      leading: _exporting
                          ? const DpSpinner(size: 16, strokeWidth: 2)
                          : const Icon(Icons.output_outlined, size: 16),
                      child: const Text('导出指标（JSON）'),
                    ),
                  ),
                ],
              ),
              if (_actionError != null) ...[
                const SizedBox(height: DpSpacing.sm),
                DpInlineNotice(
                  variant: DpInlineNoticeVariant.destructive,
                  title: '操作失败',
                  description: _actionError!,
                  icon: const Icon(Icons.error_outline),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: rollupsAsync.when(
            loading: () => const Center(child: DpSpinner()),
            error: (error, stack) => Padding(
              padding: DpInsets.page,
              child: DpInlineNotice(
                variant: DpInlineNoticeVariant.destructive,
                title: '加载失败',
                description: '$error',
                icon: const Icon(Icons.error_outline),
              ),
            ),
            data: (rollups) {
              if (rollups.isEmpty) {
                return const Padding(
                  padding: DpInsets.page,
                  child: DpEmptyState(
                    icon: Icons.insights_outlined,
                    title: '暂无指标数据',
                    description: '先使用应用一段时间，或点击“补齐最近 30 天”。',
                  ),
                );
              }

              final daySeries = buildKpiDaySeries(rollups);
              final weekSeries = buildKpiWeekSeries(rollups);
              final daySummarySeries = buildKpiDaySeries(rollups, limit: 30);
              final weekSummarySeries = buildKpiWeekSeries(rollups, limit: 12);

              final shortLabel = switch (_mode) {
                _KpiViewMode.day => '近 7 天',
                _KpiViewMode.week => '近 4 周',
              };
              final longLabel = switch (_mode) {
                _KpiViewMode.day => '近 30 天',
                _KpiViewMode.week => '近 12 周',
              };
              final summarySeries = switch (_mode) {
                _KpiViewMode.day => daySummarySeries,
                _KpiViewMode.week => weekSummarySeries,
              };
              final shortWindow = summarySeries
                  .take(_mode == _KpiViewMode.day ? 7 : 4)
                  .toList(growable: false);
              final longWindow = summarySeries
                  .take(_mode == _KpiViewMode.day ? 30 : 12)
                  .toList(growable: false);

              final series = switch (_mode) {
                _KpiViewMode.day => daySeries,
                _KpiViewMode.week => weekSeries,
              };
              final subtitle = switch (_mode) {
                _KpiViewMode.day => '最近 ${series.length} 天（按 day_key）',
                _KpiViewMode.week => '最近 ${series.length} 周（周一→周日）',
              };

              return ListView(
                padding: DpInsets.page,
                children: [
                  Text(
                    '趋势',
                    style: shadTheme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: DpSpacing.sm),
                  DpSectionCard(
                    title: 'KPI-1 · 3 秒清晰',
                    subtitle: subtitle,
                    trailing: _MetricValue(
                      value: _formatClarity(series.first),
                      muted: _isClarityInsufficient(series.first),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryRow(
                          shortLabel: shortLabel,
                          shortValue: _formatClarityWindow(shortWindow),
                          longLabel: longLabel,
                          longValue: _formatClarityWindow(longWindow),
                        ),
                        const SizedBox(height: DpSpacing.sm),
                        _MetricSeriesList(
                          series: series,
                          valueOf: _formatClarity,
                          isMuted: _isClarityInsufficient,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DpSpacing.md),
                  DpSectionCard(
                    title: 'KPI-2 · TTFA（P50 / P90）',
                    subtitle: subtitle,
                    trailing: _MetricValue(
                      value: _formatTtfa(series.first),
                      muted: _isTtfaInsufficient(series.first),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryRow(
                          shortLabel: shortLabel,
                          shortValue: _formatTtfaWindow(shortWindow),
                          longLabel: longLabel,
                          longValue: _formatTtfaWindow(longWindow),
                        ),
                        const SizedBox(height: DpSpacing.sm),
                        _MetricSeriesList(
                          series: series,
                          valueOf: _formatTtfa,
                          isMuted: _isTtfaInsufficient,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DpSpacing.md),
                  DpSectionCard(
                    title: 'KPI-3 · 主线旅程 a→c→d→e',
                    subtitle: subtitle,
                    trailing: _MetricValue(
                      value: _formatMainline(series.first),
                      muted: _isMainlineInsufficient(series.first),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryRow(
                          shortLabel: shortLabel,
                          shortValue: _formatMainlineWindow(shortWindow),
                          longLabel: longLabel,
                          longValue: _formatMainlineWindow(longWindow),
                        ),
                        const SizedBox(height: DpSpacing.sm),
                        _MetricSeriesList(
                          series: series,
                          valueOf: _formatMainline,
                          isMuted: _isMainlineInsufficient,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DpSpacing.md),
                  DpSectionCard(
                    title: 'KPI-4 · 睡前回顾',
                    subtitle: subtitle,
                    trailing: _MetricValue(
                      value: _formatJournal(series.first),
                      muted: _isJournalInsufficient(series.first),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryRow(
                          shortLabel: shortLabel,
                          shortValue: _formatJournalWindow(shortWindow),
                          longLabel: longLabel,
                          longValue: _formatJournalWindow(longWindow),
                        ),
                        const SizedBox(height: DpSpacing.sm),
                        _MetricSeriesList(
                          series: series,
                          valueOf: _formatJournal,
                          isMuted: _isJournalInsufficient,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DpSpacing.md),
                  DpSectionCard(
                    title: 'KPI-5 · R7 留存（可判定日）',
                    subtitle: subtitle,
                    trailing: _MetricValue(
                      value: _formatR7(series.first),
                      muted: _isR7Insufficient(series.first),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryRow(
                          shortLabel: shortLabel,
                          shortValue: _formatR7Window(shortWindow),
                          longLabel: longLabel,
                          longValue: _formatR7Window(longWindow),
                        ),
                        const SizedBox(height: DpSpacing.sm),
                        _MetricSeriesList(
                          series: series,
                          valueOf: _formatR7,
                          isMuted: _isR7Insufficient,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DpSpacing.md),
                  DpSectionCard(
                    title: 'Inbox Health',
                    subtitle: subtitle,
                    trailing: _MetricValue(
                      value: _formatInbox(series.first),
                      muted: false,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryRow(
                          shortLabel: shortLabel,
                          shortValue: _formatInboxWindow(shortWindow),
                          longLabel: longLabel,
                          longValue: _formatInboxWindow(longWindow),
                        ),
                        const SizedBox(height: DpSpacing.sm),
                        _MetricSeriesList(
                          series: series,
                          valueOf: _formatInbox,
                          isMuted: (_) => false,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _recomputeLast30Days() async {
    setState(() {
      _recomputing = true;
      _actionError = null;
    });

    try {
      await ref
          .read(kpiAggregationServiceProvider)
          .aggregateRecentDays(days: 30);
      ref.invalidate(_kpiRollupsProvider);
    } catch (e) {
      setState(() => _actionError = '$e');
    } finally {
      if (mounted) setState(() => _recomputing = false);
    }
  }

  Future<void> _exportMetricsJson() async {
    setState(() {
      _exporting = true;
      _actionError = null;
    });

    final localEvents = ref.read(localEventsServiceProvider);
    try {
      await localEvents.record(
        eventName: domain.LocalEventNames.exportStarted,
        metaJson: const {'format': 'json', 'result': 'ok'},
      );

      final bytes = await ref
          .read(kpiMetricsExportServiceProvider)
          .exportJsonBytes();
      if (!mounted) return;

      final fileName = 'daypick_metrics_${_ts(DateTime.now())}.json';
      await SharePlus.instance.share(
        ShareParams(
          subject: 'DayPick 指标导出（JSON）',
          files: [
            XFile.fromData(bytes, name: fileName, mimeType: 'application/json'),
          ],
        ),
      );

      await localEvents.record(
        eventName: domain.LocalEventNames.exportCompleted,
        metaJson: const {'format': 'json', 'result': 'ok'},
      );
    } catch (e) {
      await localEvents.record(
        eventName: domain.LocalEventNames.exportCompleted,
        metaJson: const {'format': 'json', 'result': 'error'},
      );
      if (mounted) setState(() => _actionError = '$e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

final kpiMetricsExportServiceProvider = Provider<data.KpiMetricsExportService>((
  ref,
) {
  return data.KpiMetricsExportService(ref.watch(appDatabaseProvider));
});

final _kpiRollupsProvider =
    FutureProvider.autoDispose<List<domain.KpiDailyRollup>>((ref) async {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final start = todayStart.subtract(const Duration(days: 84));
      final end = todayStart;
      return ref
          .watch(kpiRepositoryProvider)
          .getByDayKeyRange(
            startDayKeyInclusive: _formatDateYmd(start),
            endDayKeyInclusive: _formatDateYmd(end),
            segment: 'all',
          );
    });

String _formatDateYmd(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

String _ts(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  final ss = dt.second.toString().padLeft(2, '0');
  return '$y$m${d}_$hh$mm$ss';
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final button = selected ? ShadButton.secondary : ShadButton.outline;
    return button(
      size: ShadButtonSize.sm,
      onPressed: onTap,
      leading: selected ? const Icon(Icons.check, size: 16) : null,
      child: Text(label),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.shortLabel,
    required this.shortValue,
    required this.longLabel,
    required this.longValue,
  });

  final String shortLabel;
  final String shortValue;
  final String longLabel;
  final String longValue;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final shortMuted = shortValue.startsWith('—');
    final longMuted = longValue.startsWith('—');

    TextStyle styleFor({required bool muted}) {
      return shadTheme.textTheme.small.copyWith(
        color: muted ? colorScheme.mutedForeground : colorScheme.foreground,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            '$shortLabel：$shortValue',
            style: styleFor(muted: shortMuted),
          ),
        ),
        const SizedBox(width: DpSpacing.sm),
        Expanded(
          child: Text(
            '$longLabel：$longValue',
            textAlign: TextAlign.right,
            style: styleFor(muted: longMuted),
          ),
        ),
      ],
    );
  }
}

class _MetricSeriesList extends StatelessWidget {
  const _MetricSeriesList({
    required this.series,
    required this.valueOf,
    required this.isMuted,
  });

  final List<KpiDashboardPoint> series;
  final String Function(KpiDashboardPoint bucket) valueOf;
  final bool Function(KpiDashboardPoint bucket) isMuted;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in series)
          Padding(
            padding: const EdgeInsets.only(bottom: DpSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    b.label,
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Text(
                  valueOf(b),
                  style: shadTheme.textTheme.small.copyWith(
                    color: isMuted(b)
                        ? colorScheme.mutedForeground
                        : colorScheme.foreground,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MetricValue extends StatelessWidget {
  const _MetricValue({required this.value, required this.muted});

  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    return Text(
      value,
      style: shadTheme.textTheme.small.copyWith(
        fontWeight: FontWeight.w700,
        color: muted ? colorScheme.mutedForeground : colorScheme.foreground,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

String _formatClarity(KpiDashboardPoint p) {
  final total = p.clarityTotalCount;
  if (total <= 0) return '— 缺少事件';
  if (total < p.sampleThreshold) return '— 样本不足';
  final pct = (p.clarityOkCount / total * 100).clamp(0, 100).toStringAsFixed(0);
  return '$pct% (${p.clarityOkCount}/$total)';
}

bool _isClarityInsufficient(KpiDashboardPoint p) =>
    _formatClarity(p).startsWith('—');

String _formatClarityWindow(List<KpiDashboardPoint> points) {
  if (points.isEmpty) return '—';
  final total = points.fold<int>(0, (a, p) => a + p.clarityTotalCount);
  final ok = points.fold<int>(0, (a, p) => a + p.clarityOkCount);
  if (total <= 0) return '— 缺少事件';
  final threshold = points.fold<int>(
    0,
    (a, p) => a > p.sampleThreshold ? a : p.sampleThreshold,
  );
  if (total < threshold) return '— 样本不足';
  final pct = (ok / total * 100).clamp(0, 100).toStringAsFixed(0);
  return '$pct% ($ok/$total)';
}

String _formatTtfa(KpiDashboardPoint p) {
  final sample = p.ttfaSampleCount;
  if (sample <= 0) return '— 缺少事件';
  if (sample < p.sampleThreshold) return '— 样本不足';
  final p50 = p.ttfaP50Ms;
  final p90 = p.ttfaP90Ms;
  if (p50 == null || p90 == null) return '—';
  return '${_formatSeconds(p50)} / ${_formatSeconds(p90)}';
}

bool _isTtfaInsufficient(KpiDashboardPoint p) => _formatTtfa(p).startsWith('—');

String _formatTtfaWindow(List<KpiDashboardPoint> points) {
  if (points.isEmpty) return '—';

  final sampleSum = points.fold<int>(0, (a, p) => a + p.ttfaSampleCount);
  if (sampleSum <= 0) return '— 缺少事件';

  final p50Values = <int>[];
  final p90Values = <int>[];
  for (final p in points) {
    if (p.ttfaSampleCount < p.sampleThreshold) continue;
    final p50 = p.ttfaP50Ms;
    final p90 = p.ttfaP90Ms;
    if (p50 == null || p90 == null) continue;
    p50Values.add(p50);
    p90Values.add(p90);
  }
  if (p50Values.isEmpty || p90Values.isEmpty) return '— 样本不足';

  final p50 = _medianIntValue(p50Values);
  final p90 = _medianIntValue(p90Values);
  if (p50 == null || p90 == null) return '—';
  return '${_formatSeconds(p50)} / ${_formatSeconds(p90)}';
}

String _formatMainline(KpiDashboardPoint p) {
  if (p.mainlineEligibleCount <= 0) return '— 缺少事件';
  return p.mainlineCompletedCount.toString();
}

bool _isMainlineInsufficient(KpiDashboardPoint p) =>
    _formatMainline(p).startsWith('—');

String _formatMainlineWindow(List<KpiDashboardPoint> points) {
  if (points.isEmpty) return '—';
  final eligible =
      points.fold<int>(0, (a, p) => a + p.mainlineEligibleCount);
  if (eligible <= 0) return '— 缺少事件';
  final completed =
      points.fold<int>(0, (a, p) => a + p.mainlineCompletedCount);
  return completed.toString();
}

String _formatJournal(KpiDashboardPoint p) {
  final opened = p.journalOpenedCount;
  final completed = p.journalCompletedCount;
  if (opened <= 0 && completed <= 0) return '— 缺少事件';
  if (opened <= 0) return '— 缺少事件';
  final pct = (completed / opened * 100).clamp(0, 100).toStringAsFixed(0);
  return '$pct% ($completed/$opened)';
}

bool _isJournalInsufficient(KpiDashboardPoint p) =>
    _formatJournal(p).startsWith('—');

String _formatJournalWindow(List<KpiDashboardPoint> points) {
  if (points.isEmpty) return '—';
  final opened = points.fold<int>(0, (a, p) => a + p.journalOpenedCount);
  final completed =
      points.fold<int>(0, (a, p) => a + p.journalCompletedCount);
  if (opened <= 0 && completed <= 0) return '— 缺少事件';
  if (opened <= 0) return '— 缺少事件';
  final pct = (completed / opened * 100).clamp(0, 100).toStringAsFixed(0);
  return '$pct% ($completed/$opened)';
}

String _formatR7(KpiDashboardPoint p) {
  if (p.r7EligibleCount <= 0) return '— 未到可判定日';
  final pct = (p.r7RetainedCount / p.r7EligibleCount * 100)
      .clamp(0, 100)
      .toStringAsFixed(0);
  return '$pct% (${p.r7RetainedCount}/${p.r7EligibleCount})';
}

bool _isR7Insufficient(KpiDashboardPoint p) => _formatR7(p).startsWith('—');

String _formatR7Window(List<KpiDashboardPoint> points) {
  if (points.isEmpty) return '—';
  final eligible = points.fold<int>(0, (a, p) => a + p.r7EligibleCount);
  if (eligible <= 0) return '— 未到可判定日';
  final retained = points.fold<int>(0, (a, p) => a + p.r7RetainedCount);
  final pct = (retained / eligible * 100).clamp(0, 100).toStringAsFixed(0);
  return '$pct% ($retained/$eligible)';
}

String _formatInbox(KpiDashboardPoint p) {
  final created = p.inboxCreatedCount;
  final processed = p.inboxProcessedCount;
  final rate = created <= 0 ? null : processed / created;
  final rateText = rate == null
      ? '—'
      : '${(rate * 100).clamp(0, 999).toStringAsFixed(0)}%';
  return 'pending ${p.inboxPendingCount} · $rateText ($processed/$created)';
}

String _formatInboxWindow(List<KpiDashboardPoint> points) {
  if (points.isEmpty) return '—';

  final pendingMedian = _medianIntValue([for (final p in points) p.inboxPendingCount]) ?? 0;
  final created = points.fold<int>(0, (a, p) => a + p.inboxCreatedCount);
  final processed = points.fold<int>(0, (a, p) => a + p.inboxProcessedCount);
  final rate = created <= 0 ? null : processed / created;
  final rateText = rate == null
      ? '—'
      : '${(rate * 100).clamp(0, 999).toStringAsFixed(0)}%';
  return 'pending $pendingMedian · $rateText ($processed/$created)';
}

int? _medianIntValue(List<int> values) {
  if (values.isEmpty) return null;
  final sorted = List<int>.from(values)..sort();
  return sorted[sorted.length ~/ 2];
}

String _formatSeconds(int ms) {
  final seconds = ms / 1000.0;
  if (seconds.isNaN || seconds.isInfinite) return '—';
  if (seconds < 0) return '—';
  return '${seconds.toStringAsFixed(1)}s';
}
