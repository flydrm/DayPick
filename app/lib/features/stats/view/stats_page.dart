import 'dart:math';

import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/kit/dp_inline_notice.dart';
import '../../../ui/kit/dp_spinner.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final range = _HeatmapRange.forNow(now);

    final appearanceAsync = ref.watch(appearanceConfigProvider);
    final sessionsAsync = ref.watch(_statsSessionsProvider(range));

    return AppPageScaffold(
      title: '统计',
      showCreateAction: false,
      showSearchAction: false,
      showSettingsAction: false,
      body: sessionsAsync.when(
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
        data: (sessions) {
          final byDay = _groupSessionsByLocalDay(sessions);
          final gridDays = range.days;
          final maxCount = gridDays
              .map((d) => byDay[_formatDateYmd(d)]?.total ?? 0)
              .fold<int>(0, max);

          final todayStart = DateTime(now.year, now.month, now.day);
          final last7Start = todayStart.subtract(const Duration(days: 6));
          var last7Total = 0;
          var last7Draft = 0;
          for (var i = 0; i < 7; i += 1) {
            final d = last7Start.add(Duration(days: i));
            final stat = byDay[_formatDateYmd(d)];
            last7Total += stat?.total ?? 0;
            last7Draft += stat?.draft ?? 0;
          }

          var streak = 0;
          for (var i = 0; i < 365; i += 1) {
            final d = todayStart.subtract(Duration(days: i));
            final stat = byDay[_formatDateYmd(d)];
            if ((stat?.total ?? 0) <= 0) break;
            streak += 1;
          }

          final shadTheme = ShadTheme.of(context);
          final colorScheme = shadTheme.colorScheme;

          return ListView(
            padding: DpInsets.page,
            children: [
              appearanceAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (config) {
                  if (config.statsEnabled) return const SizedBox.shrink();
                  return ShadAlert(
                    icon: const Icon(Icons.insights_outlined),
                    title: const Text('统计默认关闭'),
                    description: const Text('开启后可在 Today 工作台添加「统计/热力图」模块。'),
                    trailing: ShadButton(
                      size: ShadButtonSize.sm,
                      onPressed: () async {
                        final repo = ref.read(
                          appearanceConfigRepositoryProvider,
                        );
                        final nextModules =
                            config.todayModules.contains(
                              domain.TodayWorkbenchModule.stats,
                            )
                            ? config.todayModules
                            : [
                                ...config.todayModules,
                                domain.TodayWorkbenchModule.stats,
                              ];
                        await repo.save(
                          config.copyWith(
                            statsEnabled: true,
                            todayModules: List.unmodifiable(nextModules),
                          ),
                        );
                      },
                      child: const Text('立即启用'),
                    ),
                  );
                },
              ),
              const SizedBox(height: DpSpacing.md),
              ShadCard(
                padding: DpInsets.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '概览',
                      style: shadTheme.textTheme.small.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: DpSpacing.sm),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _StatChip(
                          label: '最近 7 天',
                          value: '$last7Total',
                          hint: last7Draft > 0 ? '草稿 $last7Draft' : null,
                        ),
                        _StatChip(label: '连续天数', value: '$streak'),
                        _StatChip(
                          label: '近 12 周总计',
                          value: '${sessions.length}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DpSpacing.md),
              ShadCard(
                padding: DpInsets.card,
                title: Text(
                  '近 12 周热力图（番茄）',
                  style: shadTheme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                  ),
                ),
                child: _Heatmap12Weeks(
                  range: range,
                  byDay: byDay,
                  maxCount: maxCount,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

final _statsSessionsProvider =
    StreamProvider.family<List<domain.PomodoroSession>, _HeatmapRange>((
      ref,
      range,
    ) {
      return ref
          .watch(pomodoroSessionRepositoryProvider)
          .watchBetween(range.startInclusive, range.endExclusive);
    });

class _HeatmapRange {
  const _HeatmapRange({
    required this.startInclusive,
    required this.endExclusive,
  });

  factory _HeatmapRange.forNow(DateTime now) {
    final todayStart = DateTime(now.year, now.month, now.day);
    final currentWeekStart = todayStart.subtract(
      Duration(days: todayStart.weekday - DateTime.monday),
    );
    final start = currentWeekStart.subtract(const Duration(days: 7 * 11));
    final end = start.add(const Duration(days: 7 * 12));
    return _HeatmapRange(startInclusive: start, endExclusive: end);
  }

  final DateTime startInclusive;
  final DateTime endExclusive;

  List<DateTime> get days {
    final out = <DateTime>[];
    var cursor = startInclusive;
    while (cursor.isBefore(endExclusive)) {
      out.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is _HeatmapRange &&
      other.startInclusive == startInclusive &&
      other.endExclusive == endExclusive;

  @override
  int get hashCode => Object.hash(startInclusive, endExclusive);
}

class _DayStat {
  const _DayStat({required this.total, required this.draft});

  final int total;
  final int draft;

  _DayStat add({required bool isDraft}) {
    return _DayStat(total: total + 1, draft: draft + (isDraft ? 1 : 0));
  }
}

Map<String, _DayStat> _groupSessionsByLocalDay(
  List<domain.PomodoroSession> sessions,
) {
  final map = <String, _DayStat>{};
  for (final s in sessions) {
    final local = s.endAt;
    final day = DateTime(local.year, local.month, local.day);
    final key = _formatDateYmd(day);
    map[key] = (map[key] ?? const _DayStat(total: 0, draft: 0)).add(
      isDraft: s.isDraft,
    );
  }
  return map;
}

String _formatDateYmd(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

class _Heatmap12Weeks extends StatelessWidget {
  const _Heatmap12Weeks({
    required this.range,
    required this.byDay,
    required this.maxCount,
  });

  final _HeatmapRange range;
  final Map<String, _DayStat> byDay;
  final int maxCount;

  int _levelFor(int count) {
    if (count <= 0) return 0;
    if (maxCount <= 1) return 1;
    final normalized = count / maxCount;
    if (normalized <= 0.25) return 1;
    if (normalized <= 0.50) return 2;
    if (normalized <= 0.75) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final days = range.days;
    final weeks = <List<DateTime>>[];
    for (var i = 0; i < days.length; i += 7) {
      weeks.add(days.sublist(i, i + 7));
    }

    Color tileColorFor(int level) {
      if (level <= 0) return colorScheme.muted;
      final alpha = switch (level) {
        1 => 46,
        2 => 84,
        3 => 132,
        _ => 190,
      };
      return colorScheme.primary.withAlpha(alpha);
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final week in weeks)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Column(
                    children: [
                      for (final d in week)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _HeatmapTile(
                            date: d,
                            count: byDay[_formatDateYmd(d)]?.total ?? 0,
                            draft: byDay[_formatDateYmd(d)]?.draft ?? 0,
                            border: colorScheme.border,
                            background: tileColorFor(
                              d.isAfter(todayStart)
                                  ? 0
                                  : _levelFor(
                                      byDay[_formatDateYmd(d)]?.total ?? 0,
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              '少',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(width: 8),
            for (var level = 0; level <= 4; level += 1)
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: tileColorFor(level),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: colorScheme.border, width: 1),
                ),
              ),
            const SizedBox(width: 2),
            Text(
              '多',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeatmapTile extends StatelessWidget {
  const _HeatmapTile({
    required this.date,
    required this.count,
    required this.draft,
    required this.border,
    required this.background,
  });

  final DateTime date;
  final int count;
  final int draft;
  final Color border;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final label = _formatDateYmd(date);
    final note = draft > 0 ? '（草稿 $draft）' : '';
    final message = count <= 0 ? '$label：0' : '$label：$count $note';

    return Tooltip(
      message: message,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: border, width: 1),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.muted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    value,
                    style: shadTheme.textTheme.h3.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.foreground,
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      hint!,
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
