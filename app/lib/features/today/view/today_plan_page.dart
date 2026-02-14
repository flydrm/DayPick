import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/kit/dp_empty_state.dart';
import '../../../ui/kit/dp_inline_notice.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../../tasks/providers/task_providers.dart';
import '../../tasks/view/task_list_item.dart';
import '../providers/today_plan_providers.dart';
import 'today_plan_edit_sheet.dart';

class TodayPlanPage extends ConsumerWidget {
  const TodayPlanPage({super.key, this.rawDayKey});

  final String? rawDayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = _resolveDay(rawDayKey, DateTime.now());
    final dayKey = _formatDayKey(day);

    final tasksAsync = ref.watch(tasksStreamProvider);
    final todayIdsAsync = ref.watch(todayPlanTaskIdsForDayProvider(day));
    final eveningIdsAsync = ref.watch(
      todayEveningPlanTaskIdsForDayProvider(day),
    );

    final isLoading =
        tasksAsync.isLoading ||
        todayIdsAsync.isLoading ||
        eveningIdsAsync.isLoading;
    final error =
        tasksAsync.error ?? todayIdsAsync.error ?? eveningIdsAsync.error;

    final tasks = tasksAsync.valueOrNull ?? const <domain.Task>[];
    final byId = {for (final task in tasks) task.id: task};
    final todayIds = todayIdsAsync.valueOrNull ?? const <String>[];
    final eveningIds = eveningIdsAsync.valueOrNull ?? const <String>[];

    final todayTasks = [
      for (final id in todayIds)
        if (byId[id] != null) byId[id]!,
    ];
    final eveningTasks = [
      for (final id in eveningIds)
        if (byId[id] != null) byId[id]!,
    ];

    final totalCount = todayTasks.length + eveningTasks.length;

    return AppPageScaffold(
      title: 'Today Plan',
      createRoute: '/create?type=task&addToToday=true',
      actions: [
        Tooltip(
          message: '编辑今天计划',
          child: ShadIconButton.ghost(
            key: const ValueKey('today_plan_open_editor'),
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _openPlanEditor(context),
          ),
        ),
      ],
      body: ListView(
        padding: DpInsets.page,
        children: [
          ShadCard(
            key: const ValueKey('today_plan_header_card'),
            title: Text('day_key: $dayKey'),
            child: Text(
              '今日全量事项：$totalCount 条（Today ${todayTasks.length} / This Evening ${eveningTasks.length}）',
            ),
          ),
          const SizedBox(height: DpSpacing.md),
          if (isLoading)
            const _TodayPlanLoadingCard()
          else if (error != null)
            _TodayPlanErrorCard(
              error: error,
              onRetry: () {
                ref.invalidate(tasksStreamProvider);
                ref.invalidate(todayPlanTaskIdsForDayProvider(day));
                ref.invalidate(todayEveningPlanTaskIdsForDayProvider(day));
              },
            )
          else if (todayTasks.isEmpty && eveningTasks.isEmpty)
            DpEmptyState(
              key: const ValueKey('today_plan_empty_state'),
              icon: Icons.event_note_outlined,
              title: '今天还没有计划项',
              description: '从任务库添加或快速创建后，你可以在这里查看基于 day_key 的全量计划。',
              actionLabel: '编辑今天计划',
              onAction: () => _openPlanEditor(context),
            )
          else ...[
            if (todayTasks.isNotEmpty)
              _PlanSectionCard(
                key: const ValueKey('today_plan_today_section'),
                title: 'Today',
                tasks: todayTasks,
              ),
            if (todayTasks.isNotEmpty && eveningTasks.isNotEmpty)
              const SizedBox(height: DpSpacing.md),
            if (eveningTasks.isNotEmpty)
              _PlanSectionCard(
                key: const ValueKey('today_plan_evening_section'),
                title: 'This Evening',
                tasks: eveningTasks,
              ),
          ],
        ],
      ),
    );
  }

  DateTime _resolveDay(String? raw, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final text = raw?.trim();
    if (text == null || text.isEmpty) return today;

    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (match == null) return today;

    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) return today;

    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return today;
    }

    return parsed;
  }

  String _formatDayKey(DateTime day) {
    final year = day.year.toString().padLeft(4, '0');
    final month = day.month.toString().padLeft(2, '0');
    final dayOfMonth = day.day.toString().padLeft(2, '0');
    return '$year-$month-$dayOfMonth';
  }

  Future<void> _openPlanEditor(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const TodayPlanEditSheet(),
    );
  }
}

class _TodayPlanLoadingCard extends StatelessWidget {
  const _TodayPlanLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const ShadCard(
      key: ValueKey('today_plan_loading_card'),
      title: Text('正在加载 Today Plan…'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('正在读取本地计划数据。'),
          SizedBox(height: DpSpacing.sm),
          ShadProgress(minHeight: 8),
        ],
      ),
    );
  }
}

class _TodayPlanErrorCard extends StatelessWidget {
  const _TodayPlanErrorCard({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DpInlineNotice(
          key: const ValueKey('today_plan_error_notice'),
          variant: DpInlineNoticeVariant.destructive,
          title: 'Today Plan 加载失败',
          description: '原因：$error',
        ),
        const SizedBox(height: DpSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: ShadButton.outline(
            key: const ValueKey('today_plan_retry'),
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ),
      ],
    );
  }
}

class _PlanSectionCard extends StatelessWidget {
  const _PlanSectionCard({super.key, required this.title, required this.tasks});

  final String title;
  final List<domain.Task> tasks;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      title: Text(title),
      child: Column(
        children: [
          for (var i = 0; i < tasks.length; i++) ...[
            TaskListItem(
              key: ValueKey('today_plan_item:${tasks[i].id}'),
              task: tasks[i],
              onTap: () => context.push('/tasks/${tasks[i].id}'),
            ),
            if (i != tasks.length - 1)
              Divider(
                height: 0,
                color: ShadTheme.of(context).colorScheme.border,
              ),
          ],
        ],
      ),
    );
  }
}
