import 'dart:async';

import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../../focus/view/select_task_sheet.dart';
import '../../tasks/providers/task_providers.dart';
import '../providers/today_plan_providers.dart';

class Top3EditSheet extends ConsumerStatefulWidget {
  const Top3EditSheet({super.key});

  @override
  ConsumerState<Top3EditSheet> createState() => _Top3EditSheetState();
}

class _Top3EditSheetState extends ConsumerState<Top3EditSheet> {
  List<String>? _overrideTodayPlanIds;
  List<String>? _undoTodayPlanIds;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final tasksAsync = ref.watch(tasksStreamProvider);
    final todayPlanIdsAsync = ref.watch(todayPlanTaskIdsProvider);

    final now = DateTime.now();
    final day = ref.watch(todayDayProvider).valueOrNull ??
        DateTime(now.year, now.month, now.day);

    final tasks = tasksAsync.valueOrNull ?? const <domain.Task>[];
    final byId = {for (final t in tasks) t.id: t};
    final providerTodayPlanIds =
        todayPlanIdsAsync.valueOrNull ?? const <String>[];
    final todayPlanIds = _overrideTodayPlanIds ?? providerTodayPlanIds;
    final visibleTop3Ids = todayPlanIds.take(3).toList();

    if (_overrideTodayPlanIds != null &&
        _listEquals(todayPlanIds, providerTodayPlanIds)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_overrideTodayPlanIds == null) return;
        setState(() => _overrideTodayPlanIds = null);
      });
    }

    Widget body() {
      if (tasksAsync.isLoading || todayPlanIdsAsync.isLoading) {
        return const Padding(
          padding: EdgeInsets.all(DpSpacing.lg),
          child: ShadProgress(minHeight: 8),
        );
      }
      if (tasksAsync.hasError || todayPlanIdsAsync.hasError) {
        final error = tasksAsync.error ?? todayPlanIdsAsync.error;
        return Padding(
          padding: const EdgeInsets.all(DpSpacing.lg),
          child: ShadAlert.destructive(
            icon: const Icon(Icons.error_outline),
            title: const Text('加载失败'),
            description: Text('$error'),
          ),
        );
      }

      if (visibleTop3Ids.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(DpSpacing.lg),
          child: Text(
            '还没有 Today Plan。先在 Today Plan 里加入 1–3 条任务。',
            style: shadTheme.textTheme.muted.copyWith(
              color: colorScheme.mutedForeground,
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(
          DpSpacing.lg,
          0,
          DpSpacing.lg,
          DpSpacing.lg,
        ),
        child: ShadCard(
          padding: EdgeInsets.zero,
          child: ReorderableListView.builder(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            itemCount: visibleTop3Ids.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex -= 1;
              final topIds = visibleTop3Ids.toList();
              if (oldIndex < 0 || oldIndex >= topIds.length) return;
              final moved = topIds.removeAt(oldIndex);
              final insertIndex = newIndex.clamp(0, topIds.length);
              topIds.insert(insertIndex, moved);

              final rest = todayPlanIds.skip(topIds.length).toList();
              final updated = [...topIds, ...rest];
              unawaited(_replaceTodayPlan(day: day, taskIds: updated));
            },
            itemBuilder: (context, index) {
              final taskId = visibleTop3Ids[index];
              final task = byId[taskId];
              final title = task?.title.value ?? '（任务不存在）';
              return _Top3EditRow(
                key: ValueKey('top3_edit_item:$taskId'),
                taskId: taskId,
                title: title,
                pinned: index == 0,
                onReplace: () => unawaited(
                  _replaceSlot(day: day, slotIndex: index, currentId: taskId),
                ),
                onRemove: () => unawaited(
                  _removeFromTop3(day: day, taskId: taskId),
                ),
                onTogglePin: () => unawaited(
                  _togglePin(day: day, taskId: taskId),
                ),
                dragHandle: ReorderableDragStartListener(
                  key: ValueKey('top3_edit_drag:$taskId'),
                  index: index,
                  child: const Icon(Icons.drag_handle),
                ),
              );
            },
          ),
        ),
      );
    }

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.7,
        child: Padding(
          padding: EdgeInsets.only(
            left: DpSpacing.lg,
            right: DpSpacing.lg,
            top: DpSpacing.md,
            bottom: DpSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '编辑 Top3',
                      style: shadTheme.textTheme.h3.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: '关闭',
                    child: ShadIconButton.ghost(
                      key: const ValueKey('top3_edit_close'),
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DpSpacing.sm),
              Text(
                '拖拽排序；替换/移除会立即持久化。固定：将该条置顶（优先于系统建议）。',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: DpSpacing.md),
      Expanded(child: body()),
              if (_undoTodayPlanIds != null) ...[
                const SizedBox(height: DpSpacing.sm),
                ShadCard(
                  padding: const EdgeInsets.all(DpSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '已从 Top3 移除（可撤销一次）',
                          style: shadTheme.textTheme.muted.copyWith(
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ),
                      ShadButton.outline(
                        size: ShadButtonSize.sm,
                        onPressed: () => unawaited(_undoRemove(day: day)),
                        child: const Text('撤销'),
                      ),
                      const SizedBox(width: 8),
                      ShadIconButton.ghost(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () =>
                            setState(() => _undoTodayPlanIds = null),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _replaceSlot({
    required DateTime day,
    required int slotIndex,
    required String currentId,
  }) async {
    final selectedId = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const SelectTaskSheet(),
    );
    if (selectedId == null || selectedId.trim().isEmpty) return;

    final base =
        (_overrideTodayPlanIds ??
                ref.read(todayPlanTaskIdsProvider).valueOrNull ??
                const <String>[])
            .toList();
    if (base.isEmpty) return;
    final safeSlot = slotIndex.clamp(0, base.length - 1);
    final replacedId = base[safeSlot];

    base.removeWhere((id) => id == selectedId);
    base[safeSlot] = selectedId;

    if (replacedId != selectedId) {
      final insertIndex = safeSlot < 3 ? 3 : base.length;
      final safeInsertIndex = insertIndex.clamp(0, base.length);
      base.insert(safeInsertIndex, replacedId);
    }

    await _replaceTodayPlan(day: day, taskIds: base);
  }

  Future<void> _togglePin({required DateTime day, required String taskId}) async {
    final base =
        (_overrideTodayPlanIds ??
                ref.read(todayPlanTaskIdsProvider).valueOrNull ??
                const <String>[])
            .toList();
    final index = base.indexOf(taskId);
    if (index < 0) return;
    if (index == 0) {
      if (base.length <= 1) return;
      base.removeAt(0);
      base.insert(1, taskId);
    } else {
      base.removeAt(index);
      base.insert(0, taskId);
    }
    await _replaceTodayPlan(day: day, taskIds: base);
  }

  Future<void> _removeFromTop3({required DateTime day, required String taskId}) async {
    final before =
        (_overrideTodayPlanIds ??
                ref.read(todayPlanTaskIdsProvider).valueOrNull ??
                const <String>[])
            .toList();
    final after = [for (final id in before) if (id != taskId) id];
    if (after.length == before.length) return;

    await _replaceTodayPlan(day: day, taskIds: after);
    if (!mounted) return;
    setState(() => _undoTodayPlanIds = before);
  }

  Future<void> _undoRemove({required DateTime day}) async {
    final snapshot = _undoTodayPlanIds;
    if (snapshot == null) return;
    setState(() => _undoTodayPlanIds = null);
    await _replaceTodayPlan(day: day, taskIds: snapshot);
  }

  Future<void> _replaceTodayPlan({
    required DateTime day,
    required List<String> taskIds,
  }) async {
    if (!mounted) return;
    setState(() => _overrideTodayPlanIds = taskIds);
    await ref
        .read(todayPlanRepositoryProvider)
        .replaceTasks(day: day, taskIds: taskIds, section: domain.TodayPlanSection.today);
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _Top3EditRow extends StatelessWidget {
  const _Top3EditRow({
    super.key,
    required this.taskId,
    required this.title,
    required this.pinned,
    required this.onReplace,
    required this.onRemove,
    required this.onTogglePin,
    required this.dragHandle,
  });

  final String taskId;
  final String title;
  final bool pinned;
  final VoidCallback onReplace;
  final VoidCallback onRemove;
  final VoidCallback onTogglePin;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: shadTheme.textTheme.small.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: pinned ? '取消固定（不再置顶）' : '固定（置顶）',
            child: ShadIconButton.ghost(
              key: ValueKey('top3_edit_pin:$taskId'),
              icon: Icon(
                pinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 18,
              ),
              onPressed: onTogglePin,
            ),
          ),
          Tooltip(
            message: '替换',
            child: ShadIconButton.ghost(
              key: ValueKey('top3_edit_replace:$taskId'),
              icon: const Icon(Icons.swap_horiz, size: 18),
              onPressed: onReplace,
            ),
          ),
          Tooltip(
            message: '移除',
            child: ShadIconButton.ghost(
              key: ValueKey('top3_edit_remove:$taskId'),
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              onPressed: onRemove,
            ),
          ),
          const SizedBox(width: 4),
          dragHandle,
        ],
      ),
    );
  }
}
