import 'dart:async';

import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/local_events/today_3s_session_controller.dart';
import '../../../ui/kit/dp_inline_notice.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../providers/calendar_constraints_providers.dart';
import 'calendar_constraints_sheet.dart';
import 'calendar_constraints_widgets.dart';

class CalendarConstraintsCardBody extends ConsumerWidget {
  const CalendarConstraintsCardBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final state = ref.watch(calendarConstraintsControllerProvider);
    final controller = ref.read(calendarConstraintsControllerProvider.notifier);

    Future<void> openSheet() async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => const CalendarConstraintsSheet(),
      );
    }

    Widget wrapTap(Widget child) {
      return InkWell(
        onTap: () => unawaited(openSheet()),
        child: child,
      );
    }

    Widget twoButtons({
      required Key leftKey,
      required String leftLabel,
      required VoidCallback leftOnPressed,
      required Key rightKey,
      required String rightLabel,
      required VoidCallback rightOnPressed,
    }) {
      return Row(
        children: [
          Expanded(
            child: ShadButton.outline(
              key: leftKey,
              size: ShadButtonSize.sm,
              onPressed: leftOnPressed,
              child: Text(leftLabel),
            ),
          ),
          const SizedBox(width: DpSpacing.sm),
          Expanded(
            child: ShadButton.outline(
              key: rightKey,
              size: ShadButtonSize.sm,
              onPressed: rightOnPressed,
              child: Text(rightLabel),
            ),
          ),
        ],
      );
    }

    if (state.permissionState == domain.CalendarPermissionState.granted) {
      if (state.error != null) {
        return wrapTap(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DpInlineNotice(
                variant: DpInlineNoticeVariant.destructive,
                title: '日历读取失败',
                description: '不影响使用。你可以重试，或去设置检查权限。',
                icon: Icon(Icons.error_outline),
              ),
              const SizedBox(height: DpSpacing.sm),
              twoButtons(
                leftKey: const ValueKey('calendar_constraints_retry'),
                leftLabel: '重试',
                leftOnPressed: () => unawaited(controller.refresh()),
                rightKey: const ValueKey('calendar_constraints_open_settings'),
                rightLabel: '去设置',
                rightOnPressed: () => unawaited(controller.openAppSettings()),
              ),
            ],
          ),
        );
      }

      final summary = state.summary;
      if (summary == null) {
        return const ShadProgress(minHeight: 8);
      }

      return wrapTap(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CalendarBusyFreeBar(summary: summary),
            const SizedBox(height: DpSpacing.sm),
            Text(
              '点按可查看权限/开关与下一步。',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
            if (state.showEventTitles) ...[
              const SizedBox(height: 6),
              Text(
                '标题已开启',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
            if (state.loading) ...[
              const SizedBox(height: DpSpacing.sm),
              const ShadProgress(minHeight: 8),
            ],
          ],
        ),
      );
    }

    if (state.dismissed) {
      return wrapTap(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DpInlineNotice(
              title: '已跳过日历约束',
              description: '不会影响使用。你仍可用时间盒给今天一个边界。',
              icon: Icon(Icons.info_outline),
            ),
            const SizedBox(height: DpSpacing.sm),
            twoButtons(
              leftKey: const ValueKey('calendar_constraints_connect'),
              leftLabel: '连接日历',
              leftOnPressed: () => unawaited(controller.connect()),
              rightKey: const ValueKey('calendar_constraints_timeboxing'),
              rightLabel: '设置时间盒',
              rightOnPressed: () async {
                await ref
                    .read(today3sSessionControllerProvider.notifier)
                    .recordFullscreenOpened(
                      screen: 'today_timeboxing',
                      reason: 'calendar_constraints',
                    );
                if (!context.mounted) return;
                context.push('/today/timeboxing');
              },
            ),
          ],
        ),
      );
    }

    switch (state.permissionState) {
      case domain.CalendarPermissionState.unknown:
        final hintStyle = shadTheme.textTheme.small.copyWith(
          color: colorScheme.mutedForeground,
        );
        return wrapTap(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                CalendarConstraintsCopy.prePermissionValue,
                style: hintStyle,
              ),
              const SizedBox(height: 2),
              Text(
                CalendarConstraintsCopy.prePermissionScope,
                style: hintStyle,
              ),
              const SizedBox(height: 2),
              Text(
                CalendarConstraintsCopy.prePermissionControl,
                style: hintStyle,
              ),
              const Spacer(),
              twoButtons(
                leftKey: const ValueKey('calendar_constraints_connect'),
                leftLabel: '连接日历',
                leftOnPressed: () => unawaited(controller.connect()),
                rightKey: const ValueKey('calendar_constraints_skip'),
                rightLabel: '跳过',
                rightOnPressed: () => unawaited(controller.skip()),
              ),
            ],
          ),
        );

      case domain.CalendarPermissionState.denied:
      case domain.CalendarPermissionState.restricted:
        return wrapTap(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DpInlineNotice(
                title: '未获得日历权限',
                description: '不影响使用。你可以去设置开启，或继续无约束。',
                icon: Icon(Icons.lock_outline),
              ),
              const SizedBox(height: DpSpacing.sm),
              twoButtons(
                leftKey: const ValueKey('calendar_constraints_open_settings'),
                leftLabel: '去设置',
                leftOnPressed: () => unawaited(controller.openAppSettings()),
                rightKey: const ValueKey('calendar_constraints_continue_without'),
                rightLabel: '继续无约束',
                rightOnPressed: () => unawaited(controller.skip()),
              ),
            ],
          ),
        );

      case domain.CalendarPermissionState.notSupported:
        return wrapTap(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DpInlineNotice(
                title: '不支持读取系统日历',
                description: '不影响使用。你仍可继续无约束。',
                icon: Icon(Icons.info_outline),
              ),
              const SizedBox(height: DpSpacing.sm),
              ShadButton.outline(
                key: const ValueKey('calendar_constraints_continue_without'),
                onPressed: () => unawaited(controller.skip()),
                child: const Text('继续无约束'),
              ),
            ],
          ),
        );

      case domain.CalendarPermissionState.granted:
        // handled above
        return const SizedBox.shrink();
    }
  }
}
